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

#import "SessionController.h"

@implementation SessionController
{
    MCPeerID *_peerID;
    MCSession *_session;
    MCNearbyServiceAdvertiser *_serviceAdvertiser;
    MCNearbyServiceBrowser *_serviceBrowser;
    
    // Connected peers are stored in the MCSession
    // Manually track connecting and disconnected peers
    NSMutableOrderedSet *_connectingPeersOrderedSet;
    NSMutableOrderedSet *_disconnectedPeersOrderedSet;
}

static NSString * const kMCSessionServiceType = @"mcsessionp2p";

#pragma mark - Initializer

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _peerID = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
        
        _connectingPeersOrderedSet = [[NSMutableOrderedSet alloc] init];
        _disconnectedPeersOrderedSet = [[NSMutableOrderedSet alloc] init];
        
        NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
        
        // Register for notifications
        [defaultCenter addObserver:self
                          selector:@selector(startServices)
                              name:UIApplicationWillEnterForegroundNotification
                            object:nil];
        
        [defaultCenter addObserver:self
                          selector:@selector(stopServices)
                              name:UIApplicationDidEnterBackgroundNotification
                            object:nil];
        
        [self startServices];

        _displayName = _session.myPeerID.displayName;
    }
    
    return self;
}

#pragma mark - Memory management

- (void)dealloc
{
    // Unregister for notifications on deallocation.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Nil out delegates
    _session.delegate = nil;
    _serviceAdvertiser.delegate = nil;
    _serviceBrowser.delegate = nil;
}

#pragma mark - Private methods

- (void)setupSession
{
    // Create the session that peers will be invited/join into.
    _session = [[MCSession alloc] initWithPeer:_peerID];
    _session.delegate = self;
    
    // Create the service advertiser
    _serviceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:_peerID
                                                           discoveryInfo:nil
                                                             serviceType:kMCSessionServiceType];
    _serviceAdvertiser.delegate = self;
    
    // Create the service browser
    _serviceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:_peerID
                                                       serviceType:kMCSessionServiceType];
    _serviceBrowser.delegate = self;
}

- (void)teardownSession
{
    [_session disconnect];
    [_connectingPeersOrderedSet removeAllObjects];
    [_disconnectedPeersOrderedSet removeAllObjects];
}

- (void)startServices
{
    [self setupSession];
    [_serviceAdvertiser startAdvertisingPeer];
    [_serviceBrowser startBrowsingForPeers];
}

- (void)stopServices
{
    [_serviceBrowser stopBrowsingForPeers];
    [_serviceAdvertiser stopAdvertisingPeer];
    [self teardownSession];
}

- (void)updateDelegate
{
    _connectedPeers = _session.connectedPeers;
    _connectingPeers = [_connectingPeersOrderedSet array];
    _disconnectedPeers = [_disconnectedPeersOrderedSet array];
    
    [self.delegate sessionDidChangeState];
}

- (NSString *)stringForPeerConnectionState:(MCSessionState)state
{
    switch (state) {
        case MCSessionStateConnected:
            return @"Connected";
            
        case MCSessionStateConnecting:
            return @"Connecting";
            
        case MCSessionStateNotConnected:
            return @"Not Connected";
    }
}

#pragma mark - MCSessionDelegate protocol conformance

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    NSLog(@"Peer [%@] changed state to %@", peerID.displayName, [self stringForPeerConnectionState:state]);
    
    switch (state)
    {
        case MCSessionStateConnecting:
        {
            [_connectingPeersOrderedSet addObject:peerID];
            [_disconnectedPeersOrderedSet removeObject:peerID];
            break;
        }
            
        case MCSessionStateConnected:
        {
            [_connectingPeersOrderedSet removeObject:peerID];
            [_disconnectedPeersOrderedSet removeObject:peerID];
            break;
        }
            
        case MCSessionStateNotConnected:
        {
            [_disconnectedPeersOrderedSet addObject:peerID];
            [_connectingPeersOrderedSet removeObject:peerID];
            break;
        }
    }
    
    [self updateDelegate];
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    // Decode the incoming data to a UTF8 encoded string
    NSString *receivedMessage = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSLog(@"didReceiveData %@ from %@", receivedMessage, peerID.displayName);
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    NSLog(@"didStartReceivingResourceWithName [%@] from %@ with progress [%@]", resourceName, peerID.displayName, progress);
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    NSLog(@"didFinishReceivingResourceWithName [%@] from %@", resourceName, peerID.displayName);
    
    // If error is not nil something went wrong
    if (error)
    {
        NSLog(@"Error [%@] receiving resource from %@ ", [error localizedDescription], peerID.displayName);
    }
    else
    {
        // No error so this is a completed transfer.  The resources is located in a temporary location and should be copied to a permenant location immediately.
        // Write to documents directory
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *copyPath = [NSString stringWithFormat:@"%@/%@", [paths firstObject], resourceName];
        if (![[NSFileManager defaultManager] copyItemAtPath:[localURL path] toPath:copyPath error:nil])
        {
            NSLog(@"Error copying resource to documents directory");
        }
        else
        {
            // Get a URL for the path we just copied the resource to
            NSURL *url = [NSURL fileURLWithPath:copyPath];
            NSLog(@"url = %@", url);
        }
    }
}

- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate fromPeer:(MCPeerID *)peerID certificateHandler:(void (^)(BOOL accept))certificateHandler
{
    NSLog(@"didReceiveCertificate %@ from %@", certificate, peerID.displayName);
    
    // Trust the nearby peer
    certificateHandler(true);
}

// Streaming API not utilized in this sample code
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    NSLog(@"didReceiveStream %@ from %@", streamName, peerID.displayName);
}

#pragma mark - MCNearbyServiceBrowserDelegate protocol conformance

// Found a nearby advertising peer
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    NSString *remotePeerName = peerID.displayName;
    
    NSLog(@"Browser found %@", remotePeerName);
    
    MCPeerID *myPeerID = _session.myPeerID;
    BOOL shouldInvite = ([myPeerID.displayName hash] > [remotePeerName hash]);
    
    if (shouldInvite)
    {
        NSLog(@"Inviting %@", remotePeerName);
        [browser invitePeer:peerID toSession:_session withContext:nil timeout:30.0];
    }
    else
    {
        NSLog(@"Not inviting %@", remotePeerName);
    }
    
    [self updateDelegate];
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    NSLog(@"lostPeer %@", peerID.displayName);
    
    [_connectingPeersOrderedSet removeObject:peerID];
    [_disconnectedPeersOrderedSet addObject:peerID];
    
    [self updateDelegate];
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    NSLog(@"didNotStartBrowsingForPeers: %@", error);
}

#pragma mark - MCNearbyServiceAdvertiserDelegate protocol conformance

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler
{
    NSLog(@"didReceiveInvitationFromPeer %@", peerID.displayName);
    
    invitationHandler(YES, _session);
    
    [_connectingPeersOrderedSet addObject:peerID];
    [_disconnectedPeersOrderedSet removeObject:peerID];
    
    [self updateDelegate];
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
    NSLog(@"didNotStartAdvertisingForPeers: %@", error);
}

@end
