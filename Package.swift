// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Zemel",
    platforms: [ .macOS(.v14), .iOS(.v17) ],
    
	products: [
        .library(
            name: "Zemel",
            targets: [ "Zemel" ]
		),
    ],
    
    targets: [
        .target(
            name: "ZemelC",
            path: "./Sources/C"
        ),
        
        .target(
            name: "Zemel",
            dependencies: [ "ZemelC" ]
        ),
        
        .testTarget(
            name: "Tests",
            dependencies: [ "Zemel" ],
            path: "Tests"
        ),
    ],
    
    swiftLanguageModes: [ .v6 ]
)
