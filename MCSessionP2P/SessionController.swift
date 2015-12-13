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
            return session!.connectedPeers
        }
    }
    
    var connectingPeers: [MCPeerID] {
        get {
            return connectingPeersOrderedSet.array as! [MCPeerID]
        }
    }

    var disconnectedPeers: [MCPeerID] {
        get {
            return disconnectedPeersOrderedSet.array as! [MCPeerID]
        }
    }
    
    var displayName: NSString {
        get {
            return session!.myPeerID.displayName
        }
    }

    var delegate: SessionControllerDelegate?
    
    // MARK: Private properties
    
    private var session: MCSession?
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser: MCNearbyServiceBrowser?
    
    // Connected peers are stored in the MCSession
    // Manually track connecting and disconnected peers
    private var connectingPeersOrderedSet = NSMutableOrderedSet()
    private var disconnectedPeersOrderedSet = NSMutableOrderedSet()

    private let kMCSessionServiceType = "mcsessionp2p"

    // MARK: Initializer

    override init() {
        super.init()
        
        // Register for notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "startServices", name: UIApplicationWillEnterForegroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "stopServices", name: UIApplicationDidEnterBackgroundNotification, object: nil)
        
        startServices()
    }

    // MARK: Deinitialization

    deinit {
        // Unregister for notifications on deinitialization.
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
        // Nil out delegates
        session?.delegate = nil
        serviceAdvertiser?.delegate = nil
        serviceBrowser?.delegate = nil
    }

    // MARK: Multipeer Connectivity session setup / teardown

    private func setupSession() {
        // Create the session that peers will be invited/join into.
        let peerID = MCPeerID(displayName: UIDevice.currentDevice().name)
        session = MCSession(peer: peerID)
        session?.delegate = self
        
        // Create the service advertiser
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: kMCSessionServiceType)
        serviceAdvertiser?.delegate = self
        
        // Create the service browser
        serviceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: kMCSessionServiceType)
        serviceBrowser?.delegate = self
    }

    private func teardownSession() {
        session?.disconnect()
        connectingPeersOrderedSet.removeAllObjects()
        disconnectedPeersOrderedSet.removeAllObjects()
    }
    
    // MARK: Services start / stop

    func startServices() {
        setupSession()
        serviceAdvertiser?.startAdvertisingPeer()
        serviceBrowser?.startBrowsingForPeers()
    }

    func stopServices() {
        serviceBrowser?.stopBrowsingForPeers()
        serviceAdvertiser?.stopAdvertisingPeer()
        teardownSession()
    }

    // MARK: MCSessionDelegate protocol conformance

    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        NSLog("%@ [%@] %@", __FUNCTION__, peerID.displayName, MCSession.stringForPeerConnectionState(state))

        switch state {
        case .Connecting:
            connectingPeersOrderedSet.addObject(peerID)
            disconnectedPeersOrderedSet.removeObject(peerID)
            
        case .Connected:
            connectingPeersOrderedSet.removeObject(peerID)
            disconnectedPeersOrderedSet.removeObject(peerID)
            
        case .NotConnected:
            connectingPeersOrderedSet.removeObject(peerID)
            disconnectedPeersOrderedSet.addObject(peerID)
        }
        
        delegate?.sessionDidChangeState()
    }
    
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        NSLog("%@ from [%@]", __FUNCTION__, peerID.displayName)
    }
    
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
        NSLog("%@ [%@] from %@ with progress [%@]", __FUNCTION__, resourceName, peerID.displayName, progress)
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
        
        if let myPeerID = session?.myPeerID {
        
            let shouldInvite = (myPeerID.displayName.compare(remotePeerName) == .OrderedDescending)
            
            if (shouldInvite) {
                NSLog("%@ Inviting [%@]", __FUNCTION__, remotePeerName)
                browser.invitePeer(peerID, toSession: session!, withContext: nil, timeout: 30.0)
            }
            else {
                NSLog("%@ Not inviting [%@]", __FUNCTION__, remotePeerName)
            }
            
            delegate?.sessionDidChangeState()
        }
    }
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        connectingPeersOrderedSet.removeObject(peerID)
        disconnectedPeersOrderedSet.addObject(peerID)
        
        delegate?.sessionDidChangeState()
        NSLog("%@ lostPeer [%@]", __FUNCTION__, peerID.displayName)
    }

    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        NSLog("%@ %@", __FUNCTION__, error)
    }

    // MARK: MCNearbyServiceAdvertiserDelegate protocol conformance

    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: (Bool, MCSession) -> Void) {
        NSLog("%@ Accepting invitation from [%@]", __FUNCTION__, peerID.displayName)
        
        invitationHandler(true, session!)
    }

    func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
        NSLog("%@ %@", __FUNCTION__, error)
    }

}
