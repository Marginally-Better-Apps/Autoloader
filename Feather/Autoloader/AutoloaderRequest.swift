//
//  AutoloaderRequest.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct AutoloaderRequest: Equatable, Sendable {
	let version: Int
	let url: URL
	let sha256: String?
	let launch: Bool

	static let currentProtocolVersion = 1
	static let scheme = "autoloader"
	static let installHost = "install"

	static func parse(_ url: URL) throws -> AutoloaderRequest {
		guard url.scheme?.lowercased() == scheme else {
			throw AutoloaderError.invalidRequest("URL scheme must be autoloader")
		}

		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			throw AutoloaderError.invalidRequest("Malformed URL")
		}

		let host = (components.host ?? "").lowercased()
		let path = components.path
			.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
			.lowercased()
		let action = host.isEmpty ? path : host

		guard action == installHost else {
			throw AutoloaderError.invalidRequest("Unsupported Autoloader action ‘\(action)’")
		}

		let items = components.queryItems ?? []
		func queryValue(_ name: String) -> String? {
			items.first(where: { $0.name == name })?.value
		}

		let version: Int
		if let rawVersion = queryValue("v") {
			guard let parsed = Int(rawVersion) else {
				throw AutoloaderError.invalidRequest("Malformed protocol version")
			}
			guard parsed == currentProtocolVersion else {
				throw AutoloaderError.unsupportedProtocolVersion(parsed)
			}
			version = parsed
		} else {
			version = currentProtocolVersion
		}

		guard let encodedArtifact = queryValue("url"), !encodedArtifact.isEmpty else {
			throw AutoloaderError.invalidRequest("Missing url")
		}

		// URLComponents already percent-decodes query item values, so inner
		// ?, &, and = from the artifact URL survive here exactly.
		guard let artifactURL = URL(string: encodedArtifact) else {
			throw AutoloaderError.invalidRequest("Malformed artifact URL")
		}

		try validateArtifactURLShape(artifactURL)

		let sha256: String?
		if let rawSHA = queryValue("sha256") {
			sha256 = try parseSHA256(rawSHA)
		} else {
			sha256 = nil
		}

		let launch: Bool
		if let rawLaunch = queryValue("launch") {
			switch rawLaunch.lowercased() {
			case "1", "true", "yes":
				launch = true
			case "0", "false", "no":
				launch = false
			default:
				throw AutoloaderError.invalidRequest("Malformed launch flag")
			}
		} else {
			launch = true
		}

		return AutoloaderRequest(
			version: version,
			url: artifactURL,
			sha256: sha256,
			launch: launch
		)
	}

	static func parseSHA256(_ value: String) throws -> String {
		let hex = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		guard hex.count == 64, hex.allSatisfy(\.isHexDigit) else {
			throw AutoloaderError.malformedSHA256
		}
		return hex
	}

	private static func validateArtifactURLShape(_ url: URL) throws {
		guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
			throw AutoloaderError.invalidRequest("Artifact URL is missing a scheme")
		}

		switch scheme {
		case "https", "http":
			break
		case "file":
			throw AutoloaderError.unsupportedRemoteScheme("file")
		default:
			throw AutoloaderError.unsupportedRemoteScheme(scheme)
		}

		guard let host = url.host, !host.isEmpty else {
			throw AutoloaderError.invalidRequest("Artifact URL is missing a host")
		}
	}
}

enum AutoloaderInvoke {
	/// Build an `autoloader://install` URL. Another iOS development tool should
	/// call `UIApplication.shared.open` with the result.
	///
	/// Do not manually percent-encode `artifactURL`; `URLComponents` encodes query items.
	static func url(forArtifact artifactURL: URL, sha256: String? = nil, launch: Bool = true) -> URL? {
		var components = URLComponents()
		components.scheme = AutoloaderRequest.scheme
		components.host = AutoloaderRequest.installHost
		var items = [
			URLQueryItem(name: "v", value: "1"),
			URLQueryItem(name: "url", value: artifactURL.absoluteString)
		]
		if let sha256 {
			items.append(URLQueryItem(name: "sha256", value: sha256))
		}
		if !launch {
			items.append(URLQueryItem(name: "launch", value: "0"))
		}
		components.queryItems = items
		return components.url
	}

	#if canImport(UIKit)
	static func openInAutoloader(_ artifactURL: URL) {
		guard let url = url(forArtifact: artifactURL) else { return }
		Task { @MainActor in
			UIApplication.shared.open(url)
		}
	}
	#endif
}
