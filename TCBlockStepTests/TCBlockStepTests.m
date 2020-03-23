//
//  TCBlockStepTests.m
//  TCBlockStep
//
//  Created by Tito Ciuro on 3/8/20.
//  Copyright (c) 2020 Webbo, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TCBlockStep.h"
//#import "TCConstants.h"

const NSTimeInterval UNIT_TEST_TIMEOUT_INTERVAL = 10;

@interface TCBlockStepTests : XCTestCase

@end

@implementation TCBlockStepTests

- (void)testBlockStep
{
    [TCBlockStep stepWithBlocks:@[^(id result, BOOL * cancelled, TCBlockStepNext next) {
        next (nil, nil);
    }, ^(id result, BOOL * cancelled, TCBlockStepNext next) {
        XCTAssertNil(result);
        next (nil, nil);
    }, ^(id result, BOOL * cancelled, TCBlockStepNext next) {
        XCTAssertNil(result);
        next (nil, nil);
    }] timeout:UNIT_TEST_TIMEOUT_INTERVAL completionHandler:^(id result, NSError *error) {
        XCTAssertNil(result);
        XCTAssertNil(error);
    }];
}

- (void)testBlockStepOneError
{
    [TCBlockStep stepWithBlocks:@[^(id result, BOOL * cancelled, TCBlockStepNext next) {
        next (nil, nil);
    }, ^(id result, BOOL * cancelled, TCBlockStepNext next) {
        XCTAssertNil(result);
        NSError *error = [NSError errorWithDomain:@"foo" code:-1 userInfo:@{}];
        next (nil, error);
    }, ^(id result, BOOL * cancelled, TCBlockStepNext next) {
        XCTAssertNil(result);
        next (nil, nil);
    }] timeout:UNIT_TEST_TIMEOUT_INTERVAL completionHandler:^(id result, NSError *error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
    }];
}

#pragma mark -

- (void)testParallelBlocks
{
    TCBlockParallelBlocks *blocks = [TCBlockParallelBlocks new];
    
    [blocks addBlock:^ (TCBlockParallelCallback completion) {
        if (2 == 2) {
            completion (@YES, nil);
        }
    } withIdentifier:@"one"];
    
    [blocks addBlock:^ (TCBlockParallelCallback completion) {
        if  (3 == 3) {
            completion (@YES, nil);
        }
    } withIdentifier:@"two"];
    
    [TCBlockStep parallelBlocks:blocks timeout:UNIT_TEST_TIMEOUT_INTERVAL completionHandler:^(TCBlockParallelResults *parallelResults) {
        XCTAssertEqual(parallelResults.identifiers.count, 2);
        NSArray *identifiers = @[@"one", @"two"];
        XCTAssertTrue([[NSSet setWithArray:parallelResults.identifiers] isEqualToSet:[NSSet setWithArray:identifiers]]);
        XCTAssertTrue([parallelResults resultForIdentifier:@"one"]);
        XCTAssertTrue([parallelResults resultForIdentifier:@"two"]);
    }];
}

- (void)testParallelBlocksOneError
{
    TCBlockParallelBlocks *blocks = [TCBlockParallelBlocks new];
    
    [blocks addBlock:^ (TCBlockParallelCallback completion) {
        if (2 == 2) {
            completion (@YES, nil);
        }
    } withIdentifier:@"one"];
    
    [blocks addBlock:^ (TCBlockParallelCallback completion) {
        if  (2 != 3) {
            completion (@NO, [NSError errorWithDomain:@"TCBlockStep" code:-1 userInfo:nil]);
        }
    } withIdentifier:@"two"];
    
    [TCBlockStep parallelBlocks:blocks timeout:UNIT_TEST_TIMEOUT_INTERVAL completionHandler:^(TCBlockParallelResults *parallelResults) {
        XCTAssertEqual(parallelResults.identifiers.count, 2);
        NSArray *identifiers = @[@"one", @"two"];
        XCTAssertTrue([[NSSet setWithArray:parallelResults.identifiers] isEqualToSet:[NSSet setWithArray:identifiers]]);
        XCTAssertTrue([parallelResults resultForIdentifier:@"one"]);
        XCTAssertTrue([[parallelResults resultForIdentifier:@"two"] isKindOfClass:[NSError class]]);
    }];
}

- (void)testParallelBlocksThreeBlocks
{
    TCBlockParallelBlocks *blocks = [TCBlockParallelBlocks new];

    [blocks addBlock:^ (TCBlockParallelCallback completion) {
        if (2 == 2) {
            completion (@YES, nil);
        }
    } withIdentifier:@"one"];
    
    [blocks addBlock:^ (TCBlockParallelCallback completion) {
        if  (2 != 3) {
            completion (@NO, [NSError errorWithDomain:@"TCBlockStep" code:-1 userInfo:nil]);
        }
    } withIdentifier:@"two"];
    
    [blocks addBlock:^ (TCBlockParallelCallback completion) {
        if  (3 == 3) {
            completion (@YES, nil);
        }
    } withIdentifier:@"three"];
    
    [TCBlockStep parallelBlocks:blocks timeout:UNIT_TEST_TIMEOUT_INTERVAL completionHandler:^(TCBlockParallelResults *parallelResults) {
        XCTAssertEqual(parallelResults.identifiers.count, 3);
        NSArray *identifiers = @[@"one", @"two", @"three"];
        XCTAssertTrue([[NSSet setWithArray:parallelResults.identifiers] isEqualToSet:[NSSet setWithArray:identifiers]]);
        XCTAssertTrue([parallelResults resultForIdentifier:@"one"]);
        XCTAssertTrue([[parallelResults resultForIdentifier:@"two"] isKindOfClass:[NSError class]]);
        XCTAssertTrue([parallelResults resultForIdentifier:@"three"]);
    }];
}

- (void)testParallelBlocksThreeBlocksStopOnFailure
{
    TCBlockParallelBlocks *blocks = [TCBlockParallelBlocks new];
    
    [blocks addBlock:^ (TCBlockParallelCallback completion) {
        if (1 != 0) {
            completion (@NO, [NSError errorWithDomain:@"TCBlockStep" code:-1 userInfo:nil]);
        }
    } withIdentifier:@"one" stopOnFailure:YES];
    
    [blocks addBlock:^ (TCBlockParallelCallback completion) {
        if (1 != 0) {
            completion (@NO, [NSError errorWithDomain:@"TCBlockStep" code:-1 userInfo:nil]);
        }
    } withIdentifier:@"two" stopOnFailure:YES];
    
    [blocks addBlock:^ (TCBlockParallelCallback completion) {
        if (1 != 0) {
            completion (@NO, [NSError errorWithDomain:@"TCBlockStep" code:-1 userInfo:nil]);
        }
    } withIdentifier:@"three" stopOnFailure:YES];
    
    [TCBlockStep parallelBlocks:blocks timeout:UNIT_TEST_TIMEOUT_INTERVAL completionHandler:^(TCBlockParallelResults *parallelResults) {
        XCTAssertEqual(parallelResults.identifiers.count, 1);
        NSArray *identifiers = @[@"one"];
        XCTAssertTrue([[NSSet setWithArray:parallelResults.identifiers] isEqualToSet:[NSSet setWithArray:identifiers]]);
        XCTAssertTrue([[parallelResults resultForIdentifier:@"one"] isKindOfClass:[NSError class]]);
        XCTAssertEqual(parallelResults.errors.count, 1);
    }];
}

@end
