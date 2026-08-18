//
//  TargetLaunchScheme.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import CryptoKit
import Foundation

enum TargetLaunchScheme {
	static let urlName = "dev.autoloader.launch"

	/// Deterministic URL scheme derived from the effective bundle identifier.
	/// The same bundle ID always produces the same scheme across processes.
	static func make(from bundleIdentifier: String) -> String {
		let digest = SHA256.hash(data: Data(bundleIdentifier.utf8))
		let hex = digest.map { String(format: "%02x", $0) }.joined()
		return "autoloader-" + hex.prefix(20)
	}

	static func launchURL(scheme: String) -> URL {
		URL(string: "\(scheme)://autoloader-installed")!
	}

	static func inject(intoApp appURL: URL, scheme: String) throws {
		let plistURL = appURL.appendingPathComponent("Info.plist")
		guard let dictionary = NSMutableDictionary(contentsOf: plistURL) else {
			throw AutoloaderError.bundleIdentifierMissing
		}

		var types: [NSMutableDictionary] = []
		if let existing = dictionary["CFBundleURLTypes"] as? [Any] {
			for item in existing {
				if let dict = (item as? NSDictionary)?.mutableCopy() as? NSMutableDictionary {
					types.append(dict)
				}
			}
		}

		let alreadyPresent = types.contains { type in
			let schemes = type["CFBundleURLSchemes"] as? [String] ?? []
			return schemes.contains(where: { $0.caseInsensitiveCompare(scheme) == .orderedSame })
		}

		if !alreadyPresent {
			types.append(NSMutableDictionary(dictionary: [
				"CFBundleTypeRole": "Viewer",
				"CFBundleURLName": urlName,
				"CFBundleURLSchemes": [scheme]
			]))
			dictionary["CFBundleURLTypes"] = types
			dictionary.write(to: plistURL, atomically: true)
		}
	}

	static func bundleIdentifier(atApp appURL: URL) throws -> String {
		let plistURL = appURL.appendingPathComponent("Info.plist")
		guard
			let dictionary = NSDictionary(contentsOf: plistURL),
			let bundleIdentifier = dictionary["CFBundleIdentifier"] as? String,
			!bundleIdentifier.isEmpty
		else {
			throw AutoloaderError.bundleIdentifierMissing
		}
		return bundleIdentifier
	}
}
