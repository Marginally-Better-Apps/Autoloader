import XCTest
@testable import AutoloaderCore

final class SigningEntitlementResolverTests: XCTestCase {
	func testExpandsWildcardApplicationAndKeychainIdentifiers() throws {
		let resolved = try SigningEntitlementResolver.resolve(
			profileEntitlements: [
				"application-identifier": "KPAFTUKTFY.*",
				"com.apple.developer.team-identifier": "KPAFTUKTFY",
				"get-task-allow": true,
				"keychain-access-groups": ["KPAFTUKTFY.*", "com.apple.token"],
			],
			teamIdentifier: "KPAFTUKTFY",
			bundleIdentifier: "test.blenderfoundation.blender.ios"
		)

		XCTAssertEqual(
			resolved["application-identifier"] as? String,
			"KPAFTUKTFY.test.blenderfoundation.blender.ios"
		)
		XCTAssertEqual(
			resolved["keychain-access-groups"] as? [String],
			["KPAFTUKTFY.test.blenderfoundation.blender.ios", "com.apple.token"]
		)
		XCTAssertEqual(resolved["get-task-allow"] as? Bool, true)
	}

	func testPreservesMatchingExplicitApplicationIdentifier() throws {
		let applicationIdentifier = "TEAM123456.com.example.app"
		let resolved = try SigningEntitlementResolver.resolve(
			profileEntitlements: [
				"application-identifier": applicationIdentifier,
				"com.apple.developer.team-identifier": "TEAM123456",
			],
			teamIdentifier: "TEAM123456",
			bundleIdentifier: "com.example.app"
		)

		XCTAssertEqual(resolved["application-identifier"] as? String, applicationIdentifier)
	}

	func testUsesProfileAppIdentifierPrefixWhenItDiffersFromTeamIdentifier() throws {
		let resolved = try SigningEntitlementResolver.resolve(
			profileEntitlements: [
				"application-identifier": "LEGACYPFX1.*",
				"keychain-access-groups": ["LEGACYPFX1.*"],
			],
			teamIdentifier: "TEAM123456",
			applicationIdentifierPrefix: "LEGACYPFX1",
			bundleIdentifier: "com.example.app"
		)

		XCTAssertEqual(
			resolved["application-identifier"] as? String,
			"LEGACYPFX1.com.example.app"
		)
		XCTAssertEqual(
			resolved["keychain-access-groups"] as? [String],
			["LEGACYPFX1.com.example.app"]
		)
		XCTAssertEqual(
			resolved["com.apple.developer.team-identifier"] as? String,
			"TEAM123456"
		)
	}

	func testResolvesAConstrainedWildcardWithoutDuplicatingBundlePrefix() throws {
		let resolved = try SigningEntitlementResolver.resolve(
			profileEntitlements: [
				"application-identifier": "TEAM123456.com.example.*",
				"keychain-access-groups": ["TEAM123456.*"],
			],
			teamIdentifier: "TEAM123456",
			applicationIdentifierPrefix: "TEAM123456",
			bundleIdentifier: "com.example.app"
		)

		XCTAssertEqual(
			resolved["application-identifier"] as? String,
			"TEAM123456.com.example.app"
		)
	}

	func testRejectsProfileThatDoesNotAuthorizeBundleIdentifier() {
		XCTAssertThrowsError(
			try SigningEntitlementResolver.resolve(
				profileEntitlements: [
					"application-identifier": "TEAM123456.com.someone.else",
				],
				teamIdentifier: "TEAM123456",
				bundleIdentifier: "com.example.app"
			)
		)
	}
}
