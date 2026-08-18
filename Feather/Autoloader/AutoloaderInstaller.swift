//
//  AutoloaderInstaller.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation
import IDeviceSwift
import UIKit

/// Installs a signed app through Feather's idevice InstallationProxy path.
///
/// `installation_proxy_install_with_callback` is called with nil options.
/// When an app with the same CFBundleIdentifier is already installed, installd
/// upgrades that app in place. Autoloader never uninstalls first.
final class AutoloaderInstaller {
	static let shared = AutoloaderInstaller()

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
