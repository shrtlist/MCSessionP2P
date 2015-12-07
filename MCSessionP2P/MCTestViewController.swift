/*
 * Copyright 2015 shrtlist.com
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

import MultipeerConnectivity
import UIKit

/*!
@class MCTestViewController
@abstract
Presents SNAP retailers and farmers markets in a table view
*/
class MCTestViewController: UITableViewController, SessionControllerDelegate {
    
    let sessionController = SessionController()

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
    
        sessionController.delegate = self
        
        title = NSString(format: "MCSession: %@", sessionController.displayName!) as String
    }

    // MARK: Memory management
    
    deinit {
        // Nil out delegate
        sessionController.delegate = nil
    }

    // MARK: SessionControllerDelegate protocol conformance
    
    func sessionDidChangeState() {
        // Ensure UI updates occur on the main queue.
        dispatch_async(dispatch_get_main_queue(), {
            self.tableView.reloadData()
        })
    }

    // MARK: UITableViewDataSource protocol conformance
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // We have 3 sections in our grouped table view,
        // one for each MCSessionState
        return 3;
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rows = 0

        // Each tableView section represents an MCSessionState
        let sessionState = MCSessionState(rawValue: section)
        
        switch sessionState! {
        case MCSessionState.Connecting:
            rows = sessionController.connectingPeers.count
            
        case MCSessionState.Connected:
            rows = sessionController.connectedPeers.count
            
        case MCSessionState.NotConnected:
            rows = sessionController.disconnectedPeers.count
        }
        
        // Always show at least 1 row for each MCSessionState.
        if (rows < 1)
        {
            rows = 1
        }
        
        return rows
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // Each tableView section represents an MCSessionState
        let sessionState = MCSessionState(rawValue: section)
        
        return MCSession.stringForPeerConnectionState(sessionState!)
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell")
        cell!.textLabel!.text = "None"

        var peers: NSArray
        
        // Each tableView section represents an MCSessionState
        let sessionState = MCSessionState(rawValue: indexPath.section)
        let peerIndex = indexPath.row
        
        switch sessionState! {
        case MCSessionState.Connecting:
            peers = sessionController.connectingPeers
            
        case MCSessionState.Connected:
            peers = sessionController.connectedPeers
            
        case MCSessionState.NotConnected:
            peers = sessionController.disconnectedPeers
        }

        if (peers.count > 0) && (peerIndex < peers.count) {
            let peerID = peers.objectAtIndex(peerIndex) as! MCPeerID
            cell!.textLabel!.text = peerID.displayName
        }
        
        return cell!
    }
    
}
