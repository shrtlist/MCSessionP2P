/*
 * Copyright 2013 shrtlist.com
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

#import <MultipeerConnectivity/MultipeerConnectivity.h>

@protocol SessionControllerDelegate;

/*!
@class SessionController
@abstract
A SessionController creates the MCSession that peers will be invited/join
into, as well as creating service advertisers and browsers.

MCSessionDelegate calls occur on a private operation queue. If your app
needs to perform an action on a particular run loop or operation queue,
its delegate method should explicitly dispatch or schedule that work
*/
@interface SessionController : NSObject <MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate>

@property (nonatomic, weak) id<SessionControllerDelegate> delegate;

@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) NSArray *connectingPeers;
@property (nonatomic, readonly) NSArray *connectedPeers;
@property (nonatomic, readonly) NSArray *disconnectedPeers;

// Helper method for human readable printing of MCSessionState. This state is per peer.
- (NSString *)stringForPeerConnectionState:(MCSessionState)state;

@end

// Delegate methods for SessionController
@protocol SessionControllerDelegate <NSObject>

// Session changed state - connecting, connected and disconnected peers changed
- (void)sessionDidChangeState;

@end
