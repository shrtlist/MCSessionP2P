//
//  MCSession+stringForPeerConnectionState.swift
//  MCSessionP2P
//
//  Created by Marco Abundo on 12/7/15.
//  Copyright © 2015 shrtlist. All rights reserved.
//

import MultipeerConnectivity

extension MCSession {
    /*!
     @abstract Gets the string for a peer connection state
     @param peer connection state, an MCSessionState enum value
     @return string for peer connection state
     */
    class func stringForPeerConnectionState(state: MCSessionState) -> String {
        switch state {
        case .Connecting:
            return "Connecting"
            
        case .Connected:
            return "Connected"
            
        case .NotConnected:
            return "Not Connected"
        }
    }
}
