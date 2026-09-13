//
//  SigningEntitlementResolver.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation

enum SigningEntitlementResolver {
	enum ResolutionError: Error, Equatable {
		case emptyBundleIdentifier
		case emptyTeamIdentifier
		case profileDoesNotAuthorizeBundle(String)
	}

	static func resolve(
		profileEntitlements: [String: Any],
		teamIdentifier: String,
		applicationIdentifierPrefix: String? = nil,
		bundleIdentifier: String
	) throws -> [String: Any] {
		guard !teamIdentifier.isEmpty else {
			throw ResolutionError.emptyTeamIdentifier
		}
		guard !bundleIdentifier.isEmpty else {
			throw ResolutionError.emptyBundleIdentifier
		}

		let rawPrefix = applicationIdentifierPrefix ?? teamIdentifier
		let prefix = rawPrefix.hasSuffix(".") ? String(rawPrefix.dropLast()) : rawPrefix
		let concreteApplicationIdentifier = "\(prefix).\(bundleIdentifier)"
		var resolved = profileEntitlements

		if let allowedApplicationIdentifier = profileEntitlements["application-identifier"] as? String {
			guard identifier(allowedApplicationIdentifier, authorizes: concreteApplicationIdentifier) else {
				throw ResolutionError.profileDoesNotAuthorizeBundle(bundleIdentifier)
			}
		}

		resolved["application-identifier"] = concreteApplicationIdentifier
		resolved["com.apple.developer.team-identifier"] = teamIdentifier

		if let groups = profileEntitlements["keychain-access-groups"] as? [String] {
			resolved["keychain-access-groups"] = groups.map { group in
				identifier(group, authorizes: concreteApplicationIdentifier)
					? concreteApplicationIdentifier
					: group
			}
		}

		return resolved
	}

	private static func identifier(_ allowed: String, authorizes concrete: String) -> Bool {
		if allowed == concrete { return true }
		guard allowed.hasSuffix("*") else { return false }
		return concrete.hasPrefix(allowed.dropLast())
	}
}
