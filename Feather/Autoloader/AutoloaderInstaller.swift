//
//  AutoloaderInstaller.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation
import IDeviceSwift
import UIKit

/// Installs a signed app using the method already chosen in Settings → Installation.
///
/// Server (Feather default): local itms-services install. No pairing file, no VPN.
/// idevice: talks to installd through a pairing file. On iOS before 17.4 this also
/// needs LocalDevVPN so the phone can reach lockdownd at 10.7.0.1. That VPN only
/// has to be up while an idevice install is running, not all day.
///
/// Same CFBundleIdentifier replaces the existing app. Autoloader never uninstalls first.
final class AutoloaderInstaller {
	static let shared = AutoloaderInstaller()

	private static let installationMethodKey = "Feather.installationMethod"
	private static let serverMethodKey = "Feather.serverMethod"

	func installOrUpgrade(_ artifact: SignedArtifact) async throws {
		let app = AutoloaderAppRef(
			name: artifact.name,
			version: artifact.version,
			identifier: artifact.bundleIdentifier,
			date: nil,
			icon: nil,
			uuid: artifact.uuid,
			source: nil,
			isSigned: true
		)
		try await installOrUpgrade(app: app, suspend: false)
	}

	func installOrUpgrade(
		app: AppInfoPresentable,
		viewModel: InstallerStatusViewModel? = nil,
		suspend: Bool = false
	) async throws {
		if usesIDevice {
			try await installWithIDevice(app: app, viewModel: viewModel, suspend: suspend)
		} else {
			try await installWithServer(app: app, viewModel: viewModel)
		}
	}

	private var usesIDevice: Bool {
		UserDefaults.standard.integer(forKey: Self.installationMethodKey) == 1
	}

	private func installWithIDevice(
		app: AppInfoPresentable,
		viewModel: InstallerStatusViewModel?,
		suspend: Bool
	) async throws {
		guard FileManager.default.fileExists(atPath: HeartbeatManager.pairingFile()) else {
			throw AutoloaderError.pairingMissing
		}

		let status = viewModel ?? InstallerStatusViewModel(isIdevice: true)

		do {
			let archive = ArchiveHandler(app: app, viewModel: status)
			try await archive.move()
			let packageURL = try await archive.archive()

			let proxy = InstallationProxy(viewModel: status)
			try await proxy.install(at: packageURL, suspend: suspend)
		} catch let error as AutoloaderError {
			throw error
		} catch {
			let message = AutoloaderErrorFormatting.describe(error)
			if message.localizedCaseInsensitiveContains("missing pairing") {
				throw AutoloaderError.pairingMissing
			}
			throw AutoloaderError.installationFailed(message)
		}
	}

	private func installWithServer(
		app: AppInfoPresentable,
		viewModel: InstallerStatusViewModel?
	) async throws {
		guard let bundleID = app.identifier, !bundleID.isEmpty else {
			throw AutoloaderError.bundleIdentifierMissing
		}

		let status = viewModel ?? InstallerStatusViewModel(isIdevice: false)
		let archive = ArchiveHandler(app: app, viewModel: status)
		try await archive.move()
		let packageURL = try await archive.archive()

		#if !targetEnvironment(macCatalyst)
		await MainActor.run { BackgroundAudioManager.shared.start() }
		defer {
			Task { @MainActor in
				BackgroundAudioManager.shared.stop()
			}
		}
		#endif

		let installer = try await MainActor.run {
			try ServerInstaller(app: app, viewModel: status)
		}
		defer { _ = installer }
		installer.packageUrl = packageURL
		await MainActor.run {
			status.status = .ready
		}

		let serverMethod = UserDefaults.standard.integer(forKey: Self.serverMethodKey)
		if serverMethod == 0 {
			guard let url = URL(string: installer.iTunesLink) else {
				throw AutoloaderError.installationFailed("Could not build itms-services install URL.")
			}
			_ = await open(url)
		} else {
			_ = await open(installer.pageEndpoint)
		}

		try await waitForServerInstall(bundleID: bundleID, viewModel: status)
	}

	private func waitForServerInstall(
		bundleID: String,
		viewModel: InstallerStatusViewModel
	) async throws {
		let deadline = ContinuousClock.now + .seconds(300)
		var hasStarted = false

		while ContinuousClock.now < deadline {
			let current = await MainActor.run { viewModel.status }
			if case .broken(let error) = current {
				throw AutoloaderError.installationFailed(AutoloaderErrorFormatting.describe(error))
			}
			if case .completed(.failure(let error)) = current {
				throw AutoloaderError.installationFailed(AutoloaderErrorFormatting.describe(error))
			}
			if case .completed(.success) = current {
				return
			}

			let rawProgress = await UIApplication.installProgress(for: bundleID) ?? 0.0
			if rawProgress > 0 {
				hasStarted = true
			}
			let progress = hasStarted
				? min(1.0, max(0.0, (rawProgress - 0.6) / 0.3))
				: 0.0
			await MainActor.run {
				viewModel.installProgress = progress
			}

			if hasStarted && rawProgress == 0 {
				await MainActor.run {
					viewModel.installProgress = 1.0
					viewModel.status = .completed(.success(()))
				}
				return
			}

			try await Task.sleep(for: .milliseconds(50))
		}

		throw AutoloaderError.installationFailed("Timed out waiting for the system installer to finish.")
	}

	func launch(scheme: String) async throws {
		let url = TargetLaunchScheme.launchURL(scheme: scheme)
		let deadlines = [0, 150, 350, 750, 1500]
		let start = ContinuousClock.now

		for (index, millisecond) in deadlines.enumerated() {
			if index > 0 {
				let target = Duration.milliseconds(millisecond)
				let elapsed = start.duration(to: .now)
				if elapsed < target {
					try await Task.sleep(for: target - elapsed)
				}
			}

			let opened = await open(url)
			if opened {
				return
			}
		}

		throw AutoloaderError.launchFailed
	}

	@MainActor
	private func open(_ url: URL) async -> Bool {
		await withCheckedContinuation { continuation in
			UIApplication.shared.open(url, options: [:]) { success in
				continuation.resume(returning: success)
			}
		}
	}
}
