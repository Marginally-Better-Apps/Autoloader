//
//  AutoloaderImporter.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation

enum AutoloaderImporter {
	static func importIPA(_ ipa: URL) async throws -> ImportedArtifact {
		try await FR.importPackage(ipa)
	}
}

enum AutoloaderPrepare {
	static func prepare(_ imported: ImportedArtifact) throws -> String {
		let bundleIdentifier = try TargetLaunchScheme.bundleIdentifier(atApp: imported.appURL)
		return try TargetLaunchScheme.schemeForLaunch(
			atApp: imported.appURL,
			bundleIdentifier: bundleIdentifier
		)
	}
}
