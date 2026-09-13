import Foundation
import XCTest
@testable import AutoloaderCore

final class AutoloaderRetentionTests: XCTestCase {
	private let now = Date(timeIntervalSince1970: 2_000_000_000)

	func testThirtyDayBoundaryIsRetained() {
		let cutoff = now.addingTimeInterval(-30 * 24 * 60 * 60)

		XCTAssertTrue(AutoloaderRetention.includes(cutoff, now: now))
		XCTAssertTrue(AutoloaderRetention.includes(now, now: now))
		XCTAssertFalse(AutoloaderRetention.includes(cutoff.addingTimeInterval(-1), now: now))
		XCTAssertFalse(AutoloaderRetention.includes(nil, now: now))
	}

	func testRecentHistoryDropsEntriesOlderThanThirtyDays() {
		let recent = makeHistoryEntry(date: now.addingTimeInterval(-29 * 24 * 60 * 60))
		let expired = makeHistoryEntry(date: now.addingTimeInterval(-31 * 24 * 60 * 60))

		XCTAssertEqual(
			AutoloaderRetention.recentHistory([expired, recent], now: now),
			[recent]
		)
	}

	private func makeHistoryEntry(date: Date) -> AutoloaderHistoryEntry {
		AutoloaderHistoryEntry(
			id: UUID(),
			appName: "App",
			bundleIdentifier: "com.example.app",
			version: "1",
			sourceURL: "https://example.com/app.ipa",
			installedAt: date,
			success: true,
			duration: 1,
			errorDescription: nil,
			stage: nil,
			launchSucceeded: true
		)
	}
}
