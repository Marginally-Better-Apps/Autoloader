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

	static func load() -> [AutoloaderHistoryEntry] {
		guard
			let data = UserDefaults.standard.data(forKey: key),
			let entries = try? JSONDecoder().decode([AutoloaderHistoryEntry].self, from: data)
		else {
			return []
		}
		return entries
	}

	static func append(_ entry: AutoloaderHistoryEntry) -> [AutoloaderHistoryEntry] {
		var entries = load()
		entries.insert(entry, at: 0)
		if entries.count > limit {
			entries = Array(entries.prefix(limit))
		}
		if let data = try? JSONEncoder().encode(entries) {
			UserDefaults.standard.set(data, forKey: key)
		}
		return entries
	}
}
