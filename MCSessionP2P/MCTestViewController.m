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

#import "MCTestViewController.h"

@implementation MCTestViewController
{
    MCPeerID *_peerID;
    MCSession *_mcSession;
    MCNearbyServiceBrowser *_nearbyServiceBrowser;
    MCNearbyServiceAdvertiser *_nearbyServiceAdvertiser;
}

static NSString * const kMCSessionServiceType = @"mcsessionp2p";

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupSession];
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

    // Register for notifications when the application leaves the background state
    // on its way to becoming the active application.
    [defaultCenter addObserver:self 
                      selector:@selector(setupSession) 
                          name:UIApplicationWillEnterForegroundNotification
                        object:nil];

    // Register for notifications when when the application enters the background.
    [defaultCenter addObserver:self 
                      selector:@selector(teardownSession) 
                          name:UIApplicationDidEnterBackgroundNotification
                        object:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    }
    else
    {
        return YES;
    }
}

#pragma mark - Memory management

- (void)dealloc
{
    // Unregister for notifications on deallocation.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private methods

- (void)setupSession
{
    _peerID = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
    
    // Create the session that peers will be invited/join into.
    _mcSession = [[MCSession alloc] initWithPeer:_peerID];
    
    // Set ourselves as delegate
    _mcSession.delegate = self;

    _nearbyServiceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:_peerID
                                                                 discoveryInfo:nil
                                                                   serviceType:kMCSessionServiceType];
    _nearbyServiceAdvertiser.delegate = self;
    [_nearbyServiceAdvertiser startAdvertisingPeer];
    
    _nearbyServiceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:_peerID
                                                             serviceType:kMCSessionServiceType];
    _nearbyServiceBrowser.delegate = self;
    [_nearbyServiceBrowser startBrowsingForPeers];
    
    self.title = [NSString stringWithFormat:@"MCSession: %@", _mcSession.myPeerID.displayName];
}

- (void)teardownSession
{
    //[_advertiserAssistant stop];
    [_nearbyServiceBrowser stopBrowsingForPeers];
    [_nearbyServiceAdvertiser stopAdvertisingPeer];
    
    [_mcSession disconnect];
    _mcSession.delegate = nil;
}

// Helper method for human readable printing of MCSessionState.  This state is per peer.
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
    [self.tableView reloadData];
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

// Streaming API not utilized in this sample code
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    NSLog(@"didReceiveStream %@ from %@", streamName, peerID.displayName);
}

#pragma mark - MCNearbyServiceBrowserDelegate protocol conformance

// Found a nearby advertising peer
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    NSLog(@"Browser found peerID %@", peerID);
    
    BOOL shouldInvite = ([_peerID.displayName hash] > [peerID.displayName hash]);
    
    if (shouldInvite)
        [browser invitePeer:peerID toSession:_mcSession withContext:nil timeout:1.0];
    else
        NSLog(@"Not inviting");
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    NSLog(@"lostPeer %@", peerID);
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    NSLog(@"didNotStartBrowsingForPeers: %@", error);
}

- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate fromPeer:(MCPeerID *)peerID certificateHandler:(void (^)(BOOL accept))certificateHandler
{
    certificateHandler(true);
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler
{
    NSLog(@"didReceiveInvitationFromPeer %@", peerID);

    invitationHandler(YES, _mcSession);
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
    NSLog(@"didNotStartAdvertisingForPeers: %@", error);
}

#pragma mark - UITableViewDataSource protocol conformance

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // We have 3 sections in our grouped table view,
    // one for each MCSessionState
	return 3;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    NSInteger rows = 0;
    
    // Each tableView section represents an MCSessionState
    switch (section)
    {
        case MCSessionStateConnecting:
        {
            break;
        }
            
        case MCSessionStateConnected:
        {
            NSArray *connectedPeers = _mcSession.connectedPeers;
            rows = connectedPeers.count;
            break;
        }
            
        case MCSessionStateNotConnected:
        {
            break;
        }
    }
    
    // Always show at least 1 row for each GKPeerConnectionState.
    if (rows < 1)
    {
        rows = 1;
    }
    
	return rows;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSInteger peerConnectionState = section;
    
    return [self stringForPeerConnectionState:peerConnectionState];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    cell.textLabel.text = @"None";
	
    NSInteger peerConnectionState = indexPath.section;

	NSArray *peers = nil;

    switch (peerConnectionState)
    {
        case MCSessionStateConnected:
        {
            peers = _mcSession.connectedPeers;
            break;
        }
    }

	NSInteger peerIndex = indexPath.row;
    
    if ((peers.count > 0) && (peerIndex < peers.count))
    {
        MCPeerID *peerID = [peers objectAtIndex:peerIndex];
        
        if (peerID)
        {
            cell.textLabel.text = peerID.displayName;
        }
    }
	
	return cell;
}

@end
