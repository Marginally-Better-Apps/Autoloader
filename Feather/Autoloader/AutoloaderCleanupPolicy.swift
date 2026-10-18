//
//  AutoloaderCleanupPolicy.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

enum AutoloaderCleanupPolicy {
	enum Artifact: Equatable {
		case imported
		case signed
	}

	static func artifactsToDelete(
		keepBuildArtifacts: Bool,
		hasImportedArtifact: Bool,
		hasSignedArtifact: Bool
	) -> [Artifact] {
		guard !keepBuildArtifacts else { return [] }
		return hasImportedArtifact ? [.imported] : []
	}
}
