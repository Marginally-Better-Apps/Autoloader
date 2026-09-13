import Foundation
import XCTest
@testable import AutoloaderCore

final class AutoloaderCleanupPolicyTests: XCTestCase {
	func testSuccessfulAutomaticInstallRetainsSignedArtifactOnly() {
		XCTAssertEqual(
			AutoloaderCleanupPolicy.artifactsToDelete(
				keepBuildArtifacts: false,
				hasImportedArtifact: true,
				hasSignedArtifact: true
			),
			[.imported]
		)
	}

	func testKeepBuildArtifactsRetainsBothCopies() {
		XCTAssertEqual(
			AutoloaderCleanupPolicy.artifactsToDelete(
				keepBuildArtifacts: true,
				hasImportedArtifact: true,
				hasSignedArtifact: true
			),
			[]
		)
	}
}
