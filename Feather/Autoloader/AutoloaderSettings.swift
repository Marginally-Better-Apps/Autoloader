//
//  AutoloaderSettings.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation
import Combine

@MainActor
final class AutoloaderSettings: ObservableObject {
	static let shared = AutoloaderSettings()

	@Published var automaticInstalls: Bool {
		didSet { defaults.set(automaticInstalls, forKey: Keys.automaticInstalls) }
	}

	@Published var allowInsecureHTTP: Bool {
		didSet { defaults.set(allowInsecureHTTP, forKey: Keys.allowInsecureHTTP) }
	}

	@Published var keepBuildArtifacts: Bool {
		didSet { defaults.set(keepBuildArtifacts, forKey: Keys.keepBuildArtifacts) }
	}

	@Published var allowedHosts: [String] {
		didSet { defaults.set(allowedHosts, forKey: Keys.allowedHosts) }
	}

	private let defaults = UserDefaults.standard

	private enum Keys {
		static let automaticInstalls = "Autoloader.automaticInstalls"
		static let allowInsecureHTTP = "Autoloader.allowInsecureHTTP"
		static let keepBuildArtifacts = "Autoloader.keepBuildArtifacts"
		static let allowedHosts = "Autoloader.allowedHosts"
	}

	private init() {
		if defaults.object(forKey: Keys.automaticInstalls) == nil {
			automaticInstalls = true
		} else {
			automaticInstalls = defaults.bool(forKey: Keys.automaticInstalls)
		}
		allowInsecureHTTP = defaults.bool(forKey: Keys.allowInsecureHTTP)
		keepBuildArtifacts = defaults.bool(forKey: Keys.keepBuildArtifacts)
		allowedHosts = defaults.stringArray(forKey: Keys.allowedHosts) ?? []
	}

	func validate(_ url: URL) throws {
		guard let scheme = url.scheme?.lowercased() else {
			throw AutoloaderError.invalidRequest("Artifact URL is missing a scheme")
		}

		if scheme == "http" && !allowInsecureHTTP {
			throw AutoloaderError.insecureHTTPNotAllowed
		}

		guard scheme == "https" || scheme == "http" else {
			throw AutoloaderError.unsupportedRemoteScheme(scheme)
		}

		guard let host = url.host?.lowercased(), !host.isEmpty else {
			throw AutoloaderError.invalidRequest("Artifact URL is missing a host")
		}

		let allowlist = allowedHosts
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
			.filter { !$0.isEmpty }

		if !allowlist.isEmpty && !allowlist.contains(host) {
			throw AutoloaderError.hostNotAllowed(host)
		}
	}

	func addHost(_ raw: String) {
		let host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		guard !host.isEmpty, !allowedHosts.contains(host) else { return }
		allowedHosts.append(host)
	}

	func removeHost(_ host: String) {
		allowedHosts.removeAll { $0.caseInsensitiveCompare(host) == .orderedSame }
	}
}
