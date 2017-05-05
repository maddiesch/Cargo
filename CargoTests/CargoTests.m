//
//  CargoTests.m
//  CargoTests
//
//  Created by Skylar Schipper on 4/25/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

@import XCTest;
@import Cargo;

@interface TestObserver : NSObject <CARObserver>

@end

@interface CargoTests : XCTestCase

@end

@implementation CargoTests

- (void)testCargoFetchingFile {
    XCTestExpectation *expect = [self expectationWithDescription:@"wait"];

    NSURL *url = [NSURL fileURLWithPath:[@"~/Desktop/dl-test/test-1" stringByExpandingTildeInPath]];

    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];

    CARContainer *container = [[CARContainer alloc] initWithLocation:url name:@"Test Download"];
    [container addURL:[NSURL URLWithString:@"https://source.unsplash.com/kBJEJqWNtNY"] fileName:@"img-1.png"];
    [container addURL:[NSURL URLWithString:@"https://source.unsplash.com/F0bx43QKhRA"] fileName:@"img-2.png"];
    [container addURL:[NSURL URLWithString:@"https://source.unsplash.com/JB-OPbInZWQ"] fileName:@"img-3.png"];
    [container setCompletion:^(CARContainer *con) {
        XCTAssertNil(con.allErrors);
        [expect fulfill];
    }];

    NSError *error = nil;
    [[CARManager defaultManager] scheduleContainer:container error:&error];

    XCTAssertNil(error);

    [self waitForExpectationsWithTimeout:8.0 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];

    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[url.path stringByAppendingPathComponent:@"img-1.png"]]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[url.path stringByAppendingPathComponent:@"img-2.png"]]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[url.path stringByAppendingPathComponent:@"img-3.png"]]);
}

- (void)testRemovingObserver {
    XCTAssertEqual([[[CARManager defaultManager] allObservers] count], 0);

    TestObserver *obs = [[TestObserver alloc] init];
    [[CARManager defaultManager] addObserver:obs];

    XCTAssertEqual([[[CARManager defaultManager] allObservers] count], 1);

    [[CARManager defaultManager] removeObserver:obs];

    XCTAssertEqual([[[CARManager defaultManager] allObservers] count], 0);
}

- (void)testFileCaching {
    XCTestExpectation *expect = [self expectationWithDescription:@"wait"];

    NSURL *url = [NSURL URLWithString:@"cargo://cache/test-file-cache"];

    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];

    CARContainer *container = [[CARContainer alloc] initWithLocation:url name:@"Test Download"];
    [container addURL:[NSURL URLWithString:@"https://source.unsplash.com/kBJEJqWNtNY"] fileName:@"img-1.png"];
    [container setCompletion:^(CARContainer *con) {
        XCTAssertNil(con.allErrors);
        [expect fulfill];
    }];

    NSError *error = nil;
    [[CARManager defaultManager] scheduleContainer:container error:&error];

    XCTAssertNil(error);

    [self waitForExpectationsWithTimeout:8.0 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];

    XCTAssertTrue([[CARCache sharedCache] fileExistsForKey:@"test-file-cache" fileName:@"img-1.png"]);
}

@end

@implementation TestObserver

@end
