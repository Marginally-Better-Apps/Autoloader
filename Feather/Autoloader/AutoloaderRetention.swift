//
//  AutoloaderRetention.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation

enum AutoloaderRetention {
	static let duration: TimeInterval = 30 * 24 * 60 * 60

	static func cutoff(now: Date = Date()) -> Date {
		now.addingTimeInterval(-duration)
	}

	static func includes(_ date: Date?, now: Date = Date()) -> Bool {
		guard let date else { return false }
		return date >= cutoff(now: now)
	}

	static func recentHistory(
		_ entries: [AutoloaderHistoryEntry],
		now: Date = Date()
	) -> [AutoloaderHistoryEntry] {
		entries.filter { includes($0.installedAt, now: now) }
	}
}
