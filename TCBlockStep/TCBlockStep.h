//
//  TCBlockStep.h
//  TCBlockStep
//
//  Created by Tito Ciuro on 3/8/20.
//  Copyright (c) 2020 Webbo, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <TCBlockStep/BlockStep.h>
/**
 *  Block step typedefs
 */

typedef void (^TCBlockStepNext)(id result, NSError *error);
typedef void (^TCBlockStepCallback)(id result, BOOL const * isCancelled, TCBlockStepNext next);
typedef void (^TCBlockStepCompletion)(id result, NSError *error);

/**
 *  Block parallel typedefs
 */

typedef void (^TCBlockParallelCallback)(id result, NSError *error);
typedef void (^TCBlockParallelBlock)(TCBlockParallelCallback cb);

@interface TCBlockParallelBlocks : NSObject

/**
 *  Adds a new block to be executed. If the block produces an error, the default behavior does not invoke the completion
 *  block.
 *
 *  @param block      The block to be executed.
 *  @param identifier The identifier associated with the block. If the identifier already exists, the block takes its place.
 */

- (void)addBlock:(TCBlockParallelBlock)block withIdentifier:(NSString *)identifier;

/**
 *  Adds a new block to be executed. If the block produces an error, the completion block will be invoked only if the stopOnFailure
 *  parameter has been to YES. Otherwise, the block will not invoke the completion block, allowing the other blocks to return
 *  their respective results.
 *
 *  @param block         The block to be executed.
 *  @param identifier    The identifier associated with the block. If the identifier already exists, the block takes its place.
 *  @param stopOnFailure Whether the block will invoke the completion block on failure.
 */

- (void)addBlock:(TCBlockParallelBlock)block withIdentifier:(NSString *)identifier stopOnFailure:(BOOL)stopOnFailure;

/**
 *  Returns a list of identifiers.
 *
 *  @return An array of strings containing the identifiers.
 */

- (NSArray<NSString *> *)identifiers;

/**
 *  Returns the block associated with an identifier.
 *
 *  @return The block associated with an identifier, NULL otherwise.
 */

- (TCBlockParallelBlock)blockForIdentifier:(NSString *)identifier;

@end

#pragma mark -

@interface TCBlockParallelResults : NSObject

/**
 *  A map of identifiers with their associated block.
 */

@property (nonatomic, readonly) NSDictionary<NSString *, NSError *> *errors;

/**
 *  Whether the parallel executions failed due to a timeout.
 */

@property (nonatomic, readonly) BOOL hasTimedOut;

/**
 *  Returns a list of identifiers.
 *
 *  @return An array of strings containing the identifiers.
 */

- (NSArray<NSString *> *)identifiers;

/**
 *  Returns the result associated with an identifier.
 *
 *  @return The result associated with an identifier, nil otherwise.
 */

- (id)resultForIdentifier:(NSString *)identifier;

@end

typedef void (^TCBlockParallelCompletion)(TCBlockParallelResults *results);

#pragma mark -

/*
 TCBlockStep API
 */

@interface TCBlockStep : NSObject

/**
 *  Executes the blocks serially, each one running once the previous block has completed. If any block in the series pass an error to
 *  its callback, the completion block is immediately called with the value of the error and no more blocks are run. Otherwise, each block
 *  passes the result to the next block, thus chaining the invocations until the completion handler received the final result.
 *
 *  @param blocks        The list of blocks to be executed.
 *  @param timeout       The maximum allowed time in seconds before the completion block is invoked with a timeout error.
 *  @param completion    The completion block invoked once all blocks have executed. It's also invoked if any of the blocks post an error.
 */

+ (void)stepWithBlocks:(NSArray<TCBlockStepCallback> *)blocks timeout:(NSTimeInterval)timeout completionHandler:(TCBlockStepCompletion)completion;

/**
 *  Executes the blocks in parallel without waiting for the previous function to be completed. Depending on whether the block has been set
 *  to stop on failure, the completion is immediately called. Otherwise, the results are passed to the final callback as an object
 *  of type TCBlockParallelCompletion.
 *
 *  @param blocks        The series of blocks to be executed.
 *  @param timeout       The maximum allowed time in seconds before the completion block is invoked with a timeout error.
 *  @param completion    The completion block invoked once all blocks have executed. It's also invoked if any of the blocks post an error and its
                         associated stopOnFailure property has been set to YES.
 */

+ (void)parallelBlocks:(TCBlockParallelBlocks *)blocks timeout:(NSTimeInterval)timeout completionHandler:(TCBlockParallelCompletion)completion;

@end
