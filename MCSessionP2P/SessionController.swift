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

    private func startServices() {
        setupSession()
        serviceAdvertiser?.startAdvertisingPeer()
        serviceBrowser?.startBrowsingForPeers()
    }

    private func stopServices() {
        serviceBrowser?.stopBrowsingForPeers()
        serviceAdvertiser?.stopAdvertisingPeer()
        teardownSession()
    }

    // MARK: MCSessionDelegate protocol conformance
    
    func session(session: MCSession, didReceiveCertificate certificate: [AnyObject]?, fromPeer peerID: MCPeerID, certificateHandler: (Bool) -> Void) {
        certificateHandler(true)
    }

    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        NSLog("Peer [%@] changed state to %@", peerID.displayName, MCSession.stringForPeerConnectionState(state))
        
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
        // Decode the incoming data to a UTF8 encoded string
        let receivedMessage = NSString(data: data, encoding: NSUTF8StringEncoding)
        
        NSLog("didReceiveData %@ from %@", receivedMessage!, peerID.displayName)
    }
    
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
        NSLog("didStartReceivingResourceWithName [%@] from %@ with progress [%@]", resourceName, peerID.displayName, progress)
    }
    
    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) {
        NSLog("didFinishReceivingResourceWithName [%@] from %@", resourceName, peerID.displayName)
        
        // If error is not nil something went wrong
        if (error != nil) {
            NSLog("Error [%@] receiving resource from %@ ", error!, peerID.displayName)
        }
        else {
            // No error so this is a completed transfer. The resources is located in a temporary location and should be copied to a permenant location immediately.
            // Write to documents directory
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            let copyPath = NSString(format: "%@/%@", paths.first!, resourceName)
            
            do {
                try NSFileManager.defaultManager().copyItemAtPath(localURL.path!, toPath: copyPath as String)
                // Get a URL for the path we just copied the resource to
                let url = NSURL(fileURLWithPath: copyPath as String)
                NSLog("url=%@", url)
            }
            catch _ {
                print(error?.localizedDescription)
            }
        }
    }

    // Streaming API not utilized in this sample code
    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("didReceiveStream %@ from %@", streamName, peerID.displayName)
    }

    // MARK: MCNearbyServiceBrowserDelegate protocol conformance

    // Found a nearby advertising peer
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let remotePeerName = peerID.displayName
        
        NSLog("Browser found %@", remotePeerName)
        
        if let myPeerID = session?.myPeerID {
        
            let shouldInvite = (myPeerID.displayName.compare(remotePeerName) == .OrderedDescending)
            
            if (shouldInvite) {
                NSLog("Inviting %@", remotePeerName)
                browser.invitePeer(peerID, toSession: session!, withContext: nil, timeout: 30.0)
            }
            else {
                NSLog("Not inviting %@", remotePeerName)
            }
        }
        
        delegate?.sessionDidChangeState()
    }
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("lostPeer %@", peerID.displayName)
        
        connectingPeersOrderedSet.removeObject(peerID)
        disconnectedPeersOrderedSet.addObject(peerID)
        
        delegate?.sessionDidChangeState()
    }

    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        NSLog("didNotStartBrowsingForPeers: %@", error)
    }

    // MARK: MCNearbyServiceAdvertiserDelegate protocol conformance

    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: (Bool, MCSession) -> Void) {
        NSLog("didReceiveInvitationFromPeer %@", peerID.displayName)
        
        invitationHandler(true, session!)
        
        connectingPeersOrderedSet.addObject(peerID)
        disconnectedPeersOrderedSet.removeObject(peerID)
        
        delegate?.sessionDidChangeState()
    }

    func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
        NSLog("didNotStartAdvertisingForPeers: %@", error)
    }

}
