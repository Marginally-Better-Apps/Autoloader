//
//  AutoloaderLogger.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation
import OSLog

enum AutoloaderLog {
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "org.marginallybetter.Autoloader", category: "Autoloader")

	static func jobPrefix(_ jobID: UUID) -> String {
		String(jobID.uuidString.prefix(8))
	}

	static func info(_ jobID: UUID, _ message: String) {
		logger.info("[Autoloader \(jobPrefix(jobID), privacy: .public)] \(message, privacy: .public)")
	}

	static func error(_ jobID: UUID, _ message: String) {
		logger.error("[Autoloader \(jobPrefix(jobID), privacy: .public)] \(message, privacy: .public)")
	}

	static func redactedURL(_ url: URL) -> String {
		guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			return url.absoluteString
		}
		if components.query != nil {
			components.percentEncodedQuery = "redacted"
		}
		if components.user != nil || components.password != nil {
			components.user = nil
			components.password = nil
		}
		return components.string ?? url.absoluteString
	}
}

extension Logger {
	static let autoloader = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "org.marginallybetter.Autoloader",
		category: "Autoloader"
	)
}
