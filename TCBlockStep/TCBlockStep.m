//
//  TCBlockStep.m
//  TCBlockStep
//
//  Created by Tito Ciuro on 3/8/20.
//  Copyright (c) 2020 Webbo, Inc. All rights reserved.
//

#import "TCBlockStep.h"

#define __TC_BlockStep_ResultsQueue_Key    "com.webbo.blockstep.resultsQueue"

#pragma mark - TCBlockTask -

@interface TCBlockTask : NSObject

@property(nonatomic, readonly) TCBlockParallelBlock block;
@property(nonatomic, readonly) BOOL stopOnFailure;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithBlock:(TCBlockParallelBlock)block stopOnFailure:(BOOL)stopOnFailure;

@end

@implementation TCBlockTask

- (instancetype)initWithBlock:(TCBlockParallelBlock)block stopOnFailure:(BOOL)stopOnFailure
{
    self = [super init];
    
    if (self) {
        _block = block;
        _stopOnFailure = stopOnFailure;
    }
    
    return self;
}

@end

#pragma mark - TCBlockParallelResults -

@interface TCBlockParallelResults ()

@property (nonatomic, readwrite) NSDictionary *results;
@property (nonatomic, readwrite) NSDictionary *errors;
@property (nonatomic, readwrite) BOOL hasTimedOut;

@end

@implementation TCBlockParallelResults

+ (TCBlockParallelResults *)resultsWithDictionary:(NSDictionary<NSString *, id> *)results
{
    return [[TCBlockParallelResults alloc]initWithResults:results];
}

- (instancetype)initWithResults:(NSDictionary<NSString *, id> *)results
{
    self = [super init];
    
    if (self) {
        
        self.hasTimedOut = (0 == results.count);
        
        if (self.hasTimedOut) {
            
            self.results = nil;
            self.errors = nil;
            
        } else {
            
            NSMutableDictionary<NSString *, NSError *> *tempErrors = [NSMutableDictionary new];
            for (NSString *key in results) {
                id value = results[key];
                if ([value isKindOfClass:[NSError class]]) {
                    tempErrors[key] = value;
                }
            }
            
            self.results = results;
            self.errors = [NSDictionary dictionaryWithDictionary:tempErrors];
            
        }
        
    }
    
    return self;
}

- (NSArray *)identifiers
{
    return self.results.allKeys;
}

- (id)resultForIdentifier:(NSString *)identifier
{
    return self.results[identifier];
}

@end

#pragma mark - TCBlockParallelBlocks -

@interface TCBlockParallelBlocks ()

@property (nonatomic, readwrite) NSMutableDictionary<NSString *, TCBlockTask *> *tasks;

- (NSUInteger)count;

@end

@implementation TCBlockParallelBlocks

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        self.tasks = [NSMutableDictionary new];
    }
    
    return self;
}

- (void)addBlock:(TCBlockParallelBlock)block withIdentifier:(NSString *)identifier
{
    NSParameterAssert(block);
    NSParameterAssert(identifier);

    TCBlockTask *task = [[TCBlockTask alloc] initWithBlock:block stopOnFailure:NO];
    [self _addTask:task withIdentifier:identifier];
}

- (void)addBlock:(TCBlockParallelBlock)block withIdentifier:(NSString *)identifier stopOnFailure:(BOOL)stopOnFailure
{
    NSParameterAssert(block);
    NSParameterAssert(identifier);
    
    TCBlockTask *task = [[TCBlockTask alloc] initWithBlock:block stopOnFailure:stopOnFailure];
    [self _addTask:task withIdentifier:identifier];
}

- (TCBlockParallelBlock)blockForIdentifier:(NSString *)identifier
{
    return [_tasks[identifier] block];
}

- (BOOL)stopOnFailureForIdentifier:(NSString *)identifier
{
    return [_tasks[identifier] stopOnFailure];
}

- (NSArray *)identifiers
{
    return self.tasks.allKeys;
}

- (NSUInteger)count
{
    return self.tasks.count;
}

#pragma mark -

- (void)_addTask:(TCBlockTask *)task withIdentifier:(NSString *)identifier
{
    NSParameterAssert(task);
    NSParameterAssert(identifier);
    
    self.tasks[identifier] = task;
}

@end

#pragma mark - TCBlockStep -

void blockStep2Enum(NSEnumerator *enumerator, BOOL const * isCanceled, NSInteger * blockIndexBeingExecuted, id result, NSError *error, void (^completion)(id result, NSError *error))
{
    if (error) {
        return completion(nil, error);
    }
    
    if (*isCanceled) {
        return completion(nil, nil);
    }
    
    if (blockIndexBeingExecuted) {
        *blockIndexBeingExecuted += 1;
    }
    
    TCBlockStepCallback cb = enumerator.nextObject;
    if (!cb) {
        return completion(result, error);
    }
    else {
        cb(result, isCanceled, ^(id result, NSError *error) {
            return blockStep2Enum(enumerator, isCanceled, blockIndexBeingExecuted, result, error, completion);
        });
    }
}

@implementation TCBlockStep

+ (void)stepWithBlocks:(NSArray<TCBlockStepCallback> *)blocks timeout:(NSTimeInterval)timeout completionHandler:(TCBlockStepCompletion)completion
{
    NSParameterAssert(blocks);
    NSCParameterAssert(timeout >= 0);
    
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    __block BOOL isCanceled = NO;
    __block BOOL isFinished = NO;
    __block id ourResult = nil;
    __block NSError *ourError = nil;
    __block NSInteger blockIndexBeingExecuted = -1;
    
    blockStep2Enum(blocks.objectEnumerator, &isCanceled, &blockIndexBeingExecuted, nil, nil, ^(id result, NSError *error) {
        ourResult = result;
        ourError = error;
        isFinished = YES;
    });
    
    while (!isFinished && !isCanceled) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
        isCanceled = ([NSDate timeIntervalSinceReferenceDate] - start > timeout);
    }
    
    if (isCanceled) {
        // Canceled due to a timeout
        NSString *errorMessage = [NSString stringWithFormat:@"Block at index %li was canceled due to a timeout (set to %.0f seconds)", blockIndexBeingExecuted, timeout];
        if (ourError) {
            errorMessage = [errorMessage stringByAppendingString:[NSString stringWithFormat:@". Error: (%@)", ourError.localizedDescription]];
        }
        NSError *canceledError = [NSError errorWithDomain:@"TCBlockStepDomain" code:1 userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
        if (completion) completion(nil, canceledError);
    } else {
        // Success!
        if (completion) completion(ourResult, ourError);
    }
}

+ (void)parallelBlocks:(TCBlockParallelBlocks *)blocks timeout:(NSTimeInterval)timeout completionHandler:(TCBlockParallelCompletion)completion
{
    NSParameterAssert(blocks);
    NSCParameterAssert(timeout >= 0);
    NSCParameterAssert(completion);
    
    NSUInteger numBlocks = [blocks count];
    __block NSUInteger completedBlocks = 0;
    __block NSUInteger numberOfErrors = 0;
    __block BOOL bailedOutDueToError = NO;
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    NSMutableDictionary *ourResults = [[NSMutableDictionary alloc] initWithCapacity:numBlocks];
    
    dispatch_queue_t resultsLock = dispatch_queue_create(__TC_BlockStep_ResultsQueue_Key, DISPATCH_QUEUE_SERIAL);
    
    for (NSString *identifier in blocks.identifiers) {
        
        TCBlockParallelBlock block = [blocks blockForIdentifier:identifier];
        BOOL stopOnFailure = [blocks stopOnFailureForIdentifier:identifier];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            block(^(id result, NSError *error){
                dispatch_async(resultsLock, ^{
                    completedBlocks++;
                    
                    if (error) {
                        if (!bailedOutDueToError) {
                            ourResults[identifier] = error;
                            numberOfErrors++;
                            if (stopOnFailure) {
                                bailedOutDueToError = YES;
                            }
                        }
                    } else {
                        if (!bailedOutDueToError) {
                            ourResults[identifier] = result;
                        }
                    }
                });
            });
        });
        
    }
    
    // Wait on the group for as long as the timeout allows (converted to nanoseconds)
    BOOL hasTimedOut = NO;
    __block BOOL allDone = NO;
    
    while (!hasTimedOut && !allDone && !bailedOutDueToError) {
        dispatch_sync(resultsLock, ^{
            allDone = (completedBlocks == numBlocks);
        });
        
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
        hasTimedOut = [NSDate timeIntervalSinceReferenceDate] - start > timeout;
    }
    
    // If the operation has timed out, discard all results
    if (hasTimedOut) {
        ourResults = nil;
    }
    
    if (completion) {
        TCBlockParallelResults *parallelResult = [TCBlockParallelResults resultsWithDictionary:ourResults];
        completion(parallelResult);
    }
    
}

@end
