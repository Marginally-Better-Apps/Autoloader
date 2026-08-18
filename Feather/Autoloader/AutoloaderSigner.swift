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

	@MainActor
	static func configuredCertificate() throws -> CertificatePair {
		let index = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		guard let certificate = Storage.shared.getCertificate(for: index) else {
			throw AutoloaderError.certificateMissing
		}
		return certificate
	}
}
