/*
 * Copyright 2020 shrtlist@gmail.com
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

extension MCSession {
    /// Gets the string for a peer connection state
    ///
    /// - parameter state: Peer connection state, an MCSessionState enum value
    /// - returns: String for peer connection state
    ///
    class func stringForPeerConnectionState(_ state: MCSessionState) -> String {
        switch state {
        case .connecting:
            return "Connecting"
            
        case .connected:
            return "Connected"
            
        case .notConnected:
            return "Not Connected"
        }
    }
}
