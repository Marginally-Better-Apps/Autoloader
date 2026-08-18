//
//  AutoloaderModels.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation

struct ImportedArtifact: Sendable, Equatable {
	let uuid: String
	let appURL: URL
	let bundleIdentifier: String
	let name: String?
	let version: String?
}

struct SignedArtifact: Sendable, Equatable {
	let uuid: String
	let appURL: URL
	let bundleIdentifier: String
	let name: String?
	let version: String?
	let launchScheme: String
}

struct AutoloaderResult: Sendable, Equatable {
	let jobID: UUID
	let appName: String?
	let bundleIdentifier: String
	let version: String?
	let launchScheme: String
	let launched: Bool
	let launchAttempted: Bool
	let duration: TimeInterval
}

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

enum AutoloaderState: Equatable {
	case idle
	case downloading(progress: Double)
	case resolvingArtifact
	case importing
	case preparing
	case signing
	case installing
	case launching
	case completed(AutoloaderResult)
	case failed(stage: AutoloaderStage, message: String)

	var title: String {
		switch self {
		case .idle:
			return "Ready"
		case .downloading(let progress):
			return "Downloading… \(Int((progress * 100).rounded()))%"
		case .resolvingArtifact:
			return "Unpacking…"
		case .importing:
			return "Importing…"
		case .preparing:
			return "Preparing…"
		case .signing:
			return "Signing…"
		case .installing:
			return "Installing…"
		case .launching:
			return "Launching…"
		case .completed(let result):
			if result.launchAttempted && !result.launched {
				return "Installed, launch failed"
			}
			return "Installed"
		case .failed:
			return "Install failed"
		}
	}

	var isActive: Bool {
		switch self {
		case .idle, .completed, .failed:
			return false
		default:
			return true
		}
	}
}

struct AutoloaderAppRef: AppInfoPresentable {
	let name: String?
	let version: String?
	let identifier: String?
	let date: Date?
	let icon: String?
	let uuid: String?
	let source: URL?
	let isSigned: Bool
}
