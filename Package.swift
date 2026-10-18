// swift-tools-version: 6.0

import PackageDescription

let package = Package(
	name: "AutoloaderCore",
	platforms: [.macOS(.v13)],
	products: [
		.library(name: "AutoloaderCore", targets: ["AutoloaderCore"]),
	],
	targets: [
		.target(
			name: "AutoloaderCore",
			path: "Feather/Autoloader",
			exclude: [
				"ArtifactDownloader.swift",
				"ArtifactResolver.swift",
				"AutoloaderCoordinator.swift",
				"AutoloaderError.swift",
				"AutoloaderHistoryStore.swift",
				"AutoloaderImporter.swift",
				"AutoloaderInstaller.swift",
				"AutoloaderLogger.swift",
				"AutoloaderModels.swift",
				"AutoloaderRequest.swift",
				"AutoloaderSettings.swift",
				"AutoloaderSigner.swift",
				"TargetLaunchScheme.swift",
			],
			sources: [
				"AutoloaderCleanupPolicy.swift",
				"AutoloaderHistoryEntry.swift",
				"AutoloaderRetention.swift",
				"SigningEntitlementResolver.swift",
			]
		),
		.testTarget(
			name: "AutoloaderCoreTests",
			dependencies: ["AutoloaderCore"],
			path: "Tests/AutoloaderCoreTests"
		),
	]
	)
