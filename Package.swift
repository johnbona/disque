// swift-tools-version:4.0

import PackageDescription

let package = Package(
	name: "Disque",
	products: [
		.library(name: "Disque", targets: ["Disque"])
	],
	dependencies: [
		.package(url: "https://github.com/vapor/redis.git", from: "3.0.0")
	],
	targets: [
		.target(name: "Disque", dependencies: ["Redis"]),
		.testTarget(name: "DisqueTests", dependencies: ["Disque"])
	]
)
