### MCSessionP2P
A universal (iPhone/iPad) storyboard project that illustrates the ad-hoc networking features of `MCSession`. The app advertises itself to nearby iOS devices via Wi-Fi or Bluetooth and automatically connects to available peers, establishing a peer-to-peer network.

![](http://i.imgur.com/ISJhge8.png)

### Usage
You'll need to run at least two instances of the app to set up a P2P network. Build the application using Xcode and run it on a device or the simulator. Wait for another application instance to join the network. Devices / simulators must be on the same network or within Bluetooth range to see each other. Connected peers will appear in the peer list.

Please note: Bluetooth networking is not supported in Simulator.

### Build requirements
Xcode 5, iOS 7.0 SDK, LLVM Compiler 4.1, Automated Reference Counting (ARC).

### Runtime requirements
iOS 7.0 and later

### License
The source code is available under the Apache License, Version 2.0

### Contributing
Forks, patches and other feedback are always welcome.
