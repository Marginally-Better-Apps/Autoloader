//
//  AutoloaderCoordinator.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation
import UIKit

@MainActor
final class AutoloaderCoordinator: ObservableObject {
	static let shared = AutoloaderCoordinator()

	@Published private(set) var state: AutoloaderState = .idle
	@Published private(set) var currentJobID: UUID?
	@Published private(set) var currentAppName: String?
	@Published private(set) var history: [AutoloaderHistoryEntry] = AutoloaderHistoryStore.load()

	private var isRunning = false
	private var pendingRequest: AutoloaderRequest?
	private var lastHandledURL: (URL, Date)?

	func handle(url: URL) {
		if let last = lastHandledURL, last.0 == url, Date().timeIntervalSince(last.1) < 1 {
			return
		}
		lastHandledURL = (url, Date())

		do {
			let request = try AutoloaderRequest.parse(url)
			handle(request)
		} catch {
			presentFailure(jobID: UUID(), source: url, startedAt: Date(), error: error)
		}
	}

	func handle(_ request: AutoloaderRequest) {
		if isRunning {
			pendingRequest = request
			return
		}
		Task { await install(request) }
	}

	private func install(_ request: AutoloaderRequest) async {
		isRunning = true
		pendingRequest = nil
		currentAppName = nil

		let jobID = UUID()
		currentJobID = jobID
		let startedAt = Date()
		let jobDirectory = FileManager.default.temporaryDirectory
			.appendingPathComponent("Autoloader", isDirectory: true)
			.appendingPathComponent(jobID.uuidString, isDirectory: true)

		var imported: ImportedArtifact?
		var signed: SignedArtifact?

		AutoloaderLog.info(jobID, "download started")
		AutoloaderLog.info(jobID, "source \(AutoloaderLog.redactedURL(request.url))")

		do {
			try FileManager.default.createDirectoryIfNeeded(at: jobDirectory)

			guard AutoloaderSettings.shared.automaticInstalls else {
				throw AutoloaderError.automaticInstallsDisabled
			}
			try AutoloaderSettings.shared.validate(request.url)

			state = .downloading(progress: 0)
			let downloader = ArtifactDownloader()
			let artifact = try await downloader.download(request.url, to: jobDirectory) { [weak self] progress in
				self?.state = .downloading(progress: progress)
			}
			if let expected = request.sha256 {
				try downloader.verifySHA256(at: artifact.url, expected: expected)
			}
			AutoloaderLog.info(jobID, "downloaded \(Self.byteCount(artifact.byteCount))")

			state = .resolvingArtifact
			let ipa = try await ArtifactResolver.resolveIPA(from: artifact.url, jobDirectory: jobDirectory)
			AutoloaderLog.info(jobID, "resolved IPA")

			state = .importing
			let importedArtifact = try await AutoloaderImporter.importIPA(ipa)
			imported = importedArtifact
			currentAppName = importedArtifact.name
			AutoloaderLog.info(jobID, "bundle id \(importedArtifact.bundleIdentifier)")

			state = .preparing
			let launchScheme = try AutoloaderPrepare.prepare(importedArtifact)
			AutoloaderLog.info(jobID, "launch scheme \(launchScheme)")

			state = .signing
			let signedArtifact = try await AutoloaderSigner.sign(importedArtifact, launchScheme: launchScheme)
			signed = signedArtifact
			currentAppName = signedArtifact.name
			AutoloaderLog.info(jobID, "signing complete")

			state = .installing
			try await AutoloaderInstaller.shared.installOrUpgrade(signedArtifact)
			AutoloaderLog.info(jobID, "installation complete")

			var launched = false
			if request.launch {
				state = .launching
				do {
					try await AutoloaderInstaller.shared.launch(scheme: signedArtifact.launchScheme)
					launched = true
					AutoloaderLog.info(jobID, "target launch succeeded")
				} catch {
					AutoloaderLog.error(jobID, "target launch failed")
					launched = false
				}
			}

			let duration = Date().timeIntervalSince(startedAt)
			let result = AutoloaderResult(
				jobID: jobID,
				appName: signedArtifact.name,
				bundleIdentifier: signedArtifact.bundleIdentifier,
				version: signedArtifact.version,
				launchScheme: signedArtifact.launchScheme,
				launched: launched,
				launchAttempted: request.launch,
				duration: duration
			)
			state = .completed(result)
			recordHistory(
				jobID: jobID,
				source: request.url,
				startedAt: startedAt,
				success: true,
				result: result,
				error: request.launch && !launched ? AutoloaderError.launchFailed : nil
			)

			await cleanupSuccessfulJob(
				jobID: jobID,
				directory: jobDirectory,
				imported: imported,
				signed: signed
			)
		} catch {
			AutoloaderLog.error(jobID, AutoloaderErrorFormatting.describe(error))
			try? FileManager.default.removeItem(at: jobDirectory)
			presentFailure(jobID: jobID, source: request.url, startedAt: startedAt, error: error)
		}

		isRunning = false
		currentJobID = nil
		if let pending = pendingRequest {
			pendingRequest = nil
			await install(pending)
		}
	}

	private func cleanupSuccessfulJob(
		jobID: UUID,
		directory: URL,
		imported: ImportedArtifact?,
		signed: SignedArtifact?
	) async {
		try? FileManager.default.removeItem(at: directory)

		if AutoloaderSettings.shared.keepBuildArtifacts {
			return
		}

		if let imported, let object = Storage.shared.imported(uuid: imported.uuid) {
			Storage.shared.deleteApp(for: object)
		}
		if let signed, let object = Storage.shared.signed(uuid: signed.uuid) {
			Storage.shared.deleteApp(for: object)
		}
		AutoloaderLog.info(jobID, "cleaned temporary artifacts")
	}

	private func presentFailure(jobID: UUID, source: URL, startedAt: Date, error: Error) {
		let stage = (error as? AutoloaderError)?.stage ?? .request
		let message = AutoloaderErrorFormatting.describe(error)
		state = .failed(stage: stage, message: message)
		recordHistory(
			jobID: jobID,
			source: source,
			startedAt: startedAt,
			success: false,
			result: nil,
			error: error
		)
	}

	private func recordHistory(
		jobID: UUID,
		source: URL,
		startedAt: Date,
		success _: Bool,
		result: AutoloaderResult?,
		error: Error?
	) {
		let entry = AutoloaderHistoryEntry(
			id: jobID,
			appName: result?.appName ?? currentAppName,
			bundleIdentifier: result?.bundleIdentifier,
			version: result?.version,
			sourceURL: AutoloaderLog.redactedURL(source),
			installedAt: Date(),
			success: result != nil,
			duration: Date().timeIntervalSince(startedAt),
			errorDescription: error.map(AutoloaderErrorFormatting.describe),
			stage: (error as? AutoloaderError)?.stage.rawValue,
			launchSucceeded: result?.launchAttempted == true ? result?.launched : nil
		)
		history = AutoloaderHistoryStore.append(entry)
	}

	private static func byteCount(_ count: Int64) -> String {
		ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
	}
}
