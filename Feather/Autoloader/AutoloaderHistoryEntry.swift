//
//  AutoloaderHistoryEntry.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation

struct AutoloaderHistoryEntry: Codable, Identifiable, Equatable, Sendable {
	let id: UUID
	let appName: String?
	let bundleIdentifier: String?
	let version: String?
	let sourceURL: String
	let installedAt: Date
	let success: Bool
	let duration: TimeInterval
	let errorDescription: String?
	let stage: String?
	let launchSucceeded: Bool?
}
