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

import Foundation
import MultipeerConnectivity

// Delegate method for SessionController
protocol SessionControllerDelegate {
    // Multipeer Connectivity session changed state - connecting, connected and disconnected peers changed
    func sessionDidChangeState()
}

/*!
@class SessionController
@abstract
A SessionController creates the MCSession that peers will be invited/join
into, as well as creating service advertisers and browsers.

MCSessionDelegate calls occur on a private operation queue. If your app
needs to perform an action on a particular run loop or operation queue,
its delegate method should explicitly dispatch or schedule that work
*/
class SessionController: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
    // MARK: Public properties
    
    var connectedPeers: [MCPeerID] {
        get {
            return session.connectedPeers
        }
    }
    
    var connectingPeers: [MCPeerID] {
        get {
            return connectingPeersDictionary.allValues as! [MCPeerID]
        }
    }

    var disconnectedPeers: [MCPeerID] {
        get {
            return disconnectedPeersDictionary.allValues as! [MCPeerID]
        }
    }
    
    var displayName: NSString {
        get {
            return session.myPeerID.displayName
        }
    }

    var delegate: SessionControllerDelegate?
    
    // MARK: Private properties
    
    private let peerID = MCPeerID(displayName: UIDevice.currentDevice().name)
    
    private lazy var session: MCSession = {
        let session = MCSession(peer: self.peerID)
        session.delegate = self
        return session
    }()
    
    private var serviceAdvertiser: MCNearbyServiceAdvertiser
    private var serviceBrowser: MCNearbyServiceBrowser
    
    // Connected peers are stored in the MCSession
    // Manually track connecting and disconnected peers
    private var connectingPeersDictionary = NSMutableDictionary()
    private var disconnectedPeersDictionary = NSMutableDictionary()

    // MARK: Initializer

    override init() {
        let kMCSessionServiceType = "mcsessionp2p"
        
        // Create the service advertiser
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: kMCSessionServiceType)
        
        // Create the service browser
        serviceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: kMCSessionServiceType)
        
        super.init()
        
        startServices()
    }

    // MARK: Deinitialization

    deinit {
        stopServices()

        session.disconnect()
        
        // Nil out delegate
        session.delegate = nil
    }

    // MARK: Services start / stop

    func startServices() {
        serviceBrowser.delegate = self
        serviceBrowser.startBrowsingForPeers()
        
        serviceAdvertiser.delegate = self
        serviceAdvertiser.startAdvertisingPeer()
    }

    func stopServices() {
        serviceAdvertiser.stopAdvertisingPeer()
        serviceAdvertiser.delegate = nil
        
        serviceBrowser.stopBrowsingForPeers()
        serviceBrowser.delegate = nil
    }

    // MARK: MCSessionDelegate protocol conformance

    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        let displayName = peerID.displayName
        
        NSLog("%@ [%@] %@", __FUNCTION__, displayName, MCSession.stringForPeerConnectionState(state))

        switch state {
        case .Connecting:
            connectingPeersDictionary.setObject(peerID, forKey: displayName)
            disconnectedPeersDictionary.removeObjectForKey(displayName)
            
        case .Connected:
            connectingPeersDictionary.removeObjectForKey(displayName)
            disconnectedPeersDictionary.removeObjectForKey(displayName)
            
        case .NotConnected:
            connectingPeersDictionary.removeObjectForKey(displayName)
            disconnectedPeersDictionary.setObject(peerID, forKey: displayName)
        }
        
        delegate?.sessionDidChangeState()
    }
    
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        NSLog("%@ from [%@]", __FUNCTION__, peerID.displayName)
    }
    
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
        NSLog("%@ %@ from [%@] with progress [%@]", __FUNCTION__, resourceName, peerID.displayName, progress)
    }
    
    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) {
        // If error is not nil something went wrong
        if (error != nil) {
            NSLog("%@ Error %@ from [%@]", __FUNCTION__, error!, peerID.displayName)
        }
        else {
            NSLog("%@ %@ from [%@]", __FUNCTION__, resourceName, peerID.displayName)
        }
    }

    // Streaming API not utilized in this sample code
    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("%@ %@ from [%@]", __FUNCTION__, streamName, peerID.displayName)
    }

    // MARK: MCNearbyServiceBrowserDelegate protocol conformance

    // Found a nearby advertising peer
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let remotePeerName = peerID.displayName
        
        let myPeerID = session.myPeerID
        
            let shouldInvite = (myPeerID.displayName.compare(remotePeerName) == .OrderedDescending)
            
            if (shouldInvite) {
                NSLog("%@ Inviting [%@]", __FUNCTION__, remotePeerName)
                browser.invitePeer(peerID, toSession: session, withContext: nil, timeout: 30.0)
            }
            else {
                NSLog("%@ Not inviting [%@]", __FUNCTION__, remotePeerName)
            }
            
            delegate?.sessionDidChangeState()
    }
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@ lostPeer [%@]", __FUNCTION__, peerID.displayName)
    }

    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        NSLog("%@ %@", __FUNCTION__, error)
    }

    // MARK: MCNearbyServiceAdvertiserDelegate protocol conformance

    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: (Bool, MCSession) -> Void) {
        NSLog("%@ Accepting invitation from [%@]", __FUNCTION__, peerID.displayName)
        
        invitationHandler(true, session)
    }

    func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
        NSLog("%@ %@", __FUNCTION__, error)
    }

}
