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
    SessionController *_sessionController;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _sessionController = [[SessionController alloc] init];
    _sessionController.delegate = self;

    self.title = [NSString stringWithFormat:@"MCSession: %@", _sessionController.displayName];
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
    // Nil out delegate
    _sessionController.delegate = nil;
}

#pragma mark - SessionControllerDelegate protocol conformance

- (void)sessionDidChangeState
{
    // Ensure UI updates occur on the main queue.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
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
    MCSessionState sessionState = section;
    
    switch (sessionState)
    {
        case MCSessionStateConnecting:
        {
            rows = _sessionController.connectingPeers.count;
            break;
        }
            
        case MCSessionStateConnected:
        {
            rows = _sessionController.connectedPeers.count;
            break;
        }
            
        case MCSessionStateNotConnected:
        {
            rows = _sessionController.disconnectedPeers.count;
            break;
        }
    }
    
    // Always show at least 1 row for each MCSessionState.
    if (rows < 1)
    {
        rows = 1;
    }
    
	return rows;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    // Each tableView section represents an MCSessionState
    MCSessionState sessionState = section;
    
    return [_sessionController stringForPeerConnectionState:sessionState];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    cell.textLabel.text = @"None";

	NSArray *peers = nil;
    
    // Each tableView section represents an MCSessionState
    MCSessionState sessionState = indexPath.section;
	NSInteger peerIndex = indexPath.row;
    
    switch (sessionState)
    {
        case MCSessionStateConnecting:
        {
            peers = _sessionController.connectingPeers;
            break;
        }
            
        case MCSessionStateConnected:
        {
            peers = _sessionController.connectedPeers;
            break;
        }
            
        case MCSessionStateNotConnected:
        {
            peers = _sessionController.disconnectedPeers;
            break;
        }
    }

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
