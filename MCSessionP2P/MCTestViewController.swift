/*
 * Copyright 2017 shrtlist.com
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
Presents peer connection states in a table view
*/
class MCTestViewController: UITableViewController {
    
    let sessionController = SessionController()

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
    
        sessionController.delegate = self
        
        title = "MCSession: \(sessionController.displayName)"
    }

    // MARK: Deinitialization
    
    deinit {
        // Nil out delegate
        sessionController.delegate = nil
    }

    // MARK: UITableViewDataSource protocol conformance

    override func numberOfSections(in tableView: UITableView) -> Int {
        // We have 3 sections in our grouped table view,
        // one for each MCSessionState
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rows = 0

        // Each tableView section represents an MCSessionState
        guard let sessionState = MCSessionState(rawValue: section) else { return rows }
        
        switch sessionState {
        case .connecting:
            rows = sessionController.connectingPeers.count
            
        case .connected:
            rows = sessionController.connectedPeers.count
            
        case .notConnected:
            rows = sessionController.disconnectedPeers.count
        }
        
        // Always show at least 1 row for each MCSessionState.
        if rows < 1 {
            rows = 1
        }
        
        return rows
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // Each tableView section represents an MCSessionState
        let sessionState = MCSessionState(rawValue: section)
        
        return MCSession.stringForPeerConnectionState(sessionState!)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = "None"

        var peers: [MCPeerID]
        
        // Each tableView section represents an MCSessionState
        guard let sessionState = MCSessionState(rawValue: indexPath.section) else { return cell }

        let peerIndex = indexPath.row
        
        switch sessionState {
        case .connecting:
            peers = sessionController.connectingPeers
            
        case .connected:
            peers = sessionController.connectedPeers
            
        case .notConnected:
            peers = sessionController.disconnectedPeers
        }

        if (peers.count > 0) && (peerIndex < peers.count) {
            let peerID = peers[peerIndex]
            cell.textLabel?.text = peerID.displayName
        }
        
        return cell
    }

    // MARK: UITableViewDelegate protocol conformance

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension MCTestViewController: SessionControllerDelegate {

    func sessionDidChangeState() {
        // Ensure UI updates occur on the main queue.
        DispatchQueue.main.async(execute: { [weak self] in
            self?.tableView.reloadData()
        })
    }
}
