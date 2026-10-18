//
//  AutoloaderHistoryStore.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation

enum AutoloaderHistoryStore {
	private static let key = "Autoloader.history"
	private static let limit = 50

	static func load(now: Date = Date()) -> [AutoloaderHistoryEntry] {
		guard
			let data = UserDefaults.standard.data(forKey: key),
			let entries = try? JSONDecoder().decode([AutoloaderHistoryEntry].self, from: data)
		else {
			return []
		}
		return AutoloaderRetention.recentHistory(entries, now: now)
	}

	static func append(_ entry: AutoloaderHistoryEntry, now: Date = Date()) -> [AutoloaderHistoryEntry] {
		var entries = load(now: now)
		entries.insert(entry, at: 0)
		entries = AutoloaderRetention.recentHistory(entries, now: now)
		if entries.count > limit {
			entries = Array(entries.prefix(limit))
		}
		if let data = try? JSONEncoder().encode(entries) {
			UserDefaults.standard.set(data, forKey: key)
		}
		return entries
	}
}
