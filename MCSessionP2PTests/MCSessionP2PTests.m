/*
 * Copyright 2014 shrtlist.com
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <XCTest/XCTest.h>
#import "SessionController.h"

@interface MCSessionP2PTests : XCTestCase

@end

@implementation MCSessionP2PTests

- (void)testSessionController
{
    SessionController *sessionController = [[SessionController alloc] init];
    
    XCTAssertNotNil(sessionController.displayName, @"Expected non-nil displayName");
    XCTAssertNotNil(sessionController.connectingPeers, @"Expected non-nil connectingPeers");
    XCTAssertNotNil(sessionController.connectedPeers, @"Expected non-nil connectedPeers");
    XCTAssertNotNil(sessionController.disconnectedPeers, @"Expected non-nil disconnectedPeers");
}

@end
