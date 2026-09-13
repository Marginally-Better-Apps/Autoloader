//
//  AutoloaderSigner.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation

enum AutoloaderSigner {
	/// Automatic signing uses the certificate already chosen in Settings.
	/// Bundle identifiers are preserved exactly — no PPQ suffix, no random
	/// identifier, and no per-run UUID. SigningView's identifier remapping is
	/// intentionally not applied here.
	static func sign(
		_ imported: ImportedArtifact,
		launchScheme: String
	) async throws -> SignedArtifact {
		let certificate = try await MainActor.run { () -> CertificatePair in
			try configuredCertificate()
		}

		var options = await MainActor.run { OptionsManager.shared.options }
		options.appIdentifier = nil
		options.appName = nil
		options.appVersion = nil
		options.removeURLScheme = false
		options.post_installAppAfterSigned = false
		options.post_deleteAppAfterSigned = false

		let entitlementsURL = try await resolvedEntitlementsFile(
			for: certificate,
			bundleIdentifier: imported.bundleIdentifier
		)
		options.appEntitlementsFile = entitlementsURL
		defer { try? FileManager.default.removeItem(at: entitlementsURL) }

		do {
			var signed = try await FR.signPackage(
				imported,
				using: options,
				certificate: certificate
			)
			if signed.launchScheme != launchScheme {
				signed = SignedArtifact(
					uuid: signed.uuid,
					appURL: signed.appURL,
					bundleIdentifier: signed.bundleIdentifier,
					name: signed.name,
					version: signed.version,
					launchScheme: launchScheme
				)
			}
			return signed
		} catch SigningFileHandlerError.missingCertifcate {
			throw AutoloaderError.certificateMissing
		} catch {
			throw AutoloaderError.signingFailed(AutoloaderErrorFormatting.describe(error))
		}
	}

	private static func resolvedEntitlementsFile(
		for certificate: CertificatePair,
		bundleIdentifier: String
	) async throws -> URL {
		let data = try await MainActor.run { () throws -> Data in
			guard
				let profile = Storage.shared.getProvisionFileDecoded(for: certificate),
				let teamIdentifier = profile.TeamIdentifier.first
			else {
				throw AutoloaderError.signingFailed("The provisioning profile has no Team ID.")
			}

			let profileEntitlements = profile.Entitlements?.mapValues(\.value) ?? [:]
			let resolved = try SigningEntitlementResolver.resolve(
				profileEntitlements: profileEntitlements,
				teamIdentifier: teamIdentifier,
				applicationIdentifierPrefix: profile.ApplicationIdentifierPrefix?.first,
				bundleIdentifier: bundleIdentifier
			)
			return try PropertyListSerialization.data(
				fromPropertyList: resolved,
				format: .xml,
				options: 0
			)
		}

		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("AutoloaderSigning", isDirectory: true)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		let url = directory.appendingPathComponent("\(UUID().uuidString).entitlements")
		try data.write(to: url, options: .atomic)
		return url
	}

	@MainActor
	static func configuredCertificate() throws -> CertificatePair {
		let index = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		guard let certificate = Storage.shared.getCertificate(for: index) else {
			throw AutoloaderError.certificateMissing
		}
		return certificate
	}
}
