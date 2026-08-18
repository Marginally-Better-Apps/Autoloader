//
//  AutoloaderError.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation

enum AutoloaderStage: String, Sendable, Equatable {
	case request
	case download
	case resolve
	case importing = "import"
	case prepare
	case sign
	case install
	case launch
	case cleanup
}

enum AutoloaderError: Error, LocalizedError {
	case invalidRequest(String)
	case unsupportedProtocolVersion(Int)
	case unsupportedRemoteScheme(String)
	case automaticInstallsDisabled
	case hostNotAllowed(String)
	case insecureHTTPNotAllowed
	case downloadFailed(String)
	case sha256Mismatch(expected: String, actual: String)
	case malformedSHA256
	case invalidArchive
	case ipaNotFound
	case multipleIPAsFound(Int)
	case payloadNotFound
	case appBundleNotFound
	case bundleIdentifierMissing
	case certificateMissing
	case pairingMissing
	case signingFailed(String)
	case installationFailed(String)
	case launchFailed

	var stage: AutoloaderStage {
		switch self {
		case .invalidRequest, .unsupportedProtocolVersion, .unsupportedRemoteScheme,
			 .automaticInstallsDisabled, .hostNotAllowed, .insecureHTTPNotAllowed, .malformedSHA256:
			return .request
		case .downloadFailed, .sha256Mismatch:
			return .download
		case .invalidArchive, .ipaNotFound, .multipleIPAsFound, .payloadNotFound, .appBundleNotFound:
			return .resolve
		case .bundleIdentifierMissing:
			return .prepare
		case .certificateMissing, .signingFailed:
			return .sign
		case .pairingMissing, .installationFailed:
			return .install
		case .launchFailed:
			return .launch
		}
	}

	var errorDescription: String? {
		switch self {
		case .invalidRequest(let reason):
			return "Invalid Autoloader request: \(reason)"
		case .unsupportedProtocolVersion(let version):
			return "Unsupported Autoloader protocol version \(version). This build understands v=1."
		case .unsupportedRemoteScheme(let scheme):
			return "Unsupported artifact URL scheme ‘\(scheme)’."
		case .automaticInstallsDisabled:
			return "Automatic installs are turned off. Enable them in Settings → Autoloader."
		case .hostNotAllowed(let host):
			return "Artifact host ‘\(host)’ is not in the allowed hosts list."
		case .insecureHTTPNotAllowed:
			return "HTTP artifact URLs are disabled. Enable ‘Allow insecure HTTP’ in Settings → Autoloader for local development."
		case .downloadFailed(let message):
			return "Download failed: \(message)"
		case .sha256Mismatch(let expected, let actual):
			return "SHA-256 mismatch. Expected \(expected), got \(actual)."
		case .malformedSHA256:
			return "Malformed sha256 query value. Expected 64 lowercase hexadecimal characters."
		case .invalidArchive:
			return "The downloaded file is not a usable IPA or ZIP archive."
		case .ipaNotFound:
			return "No IPA was found in the artifact."
		case .multipleIPAsFound(let count):
			return "Artifact contains \(count) IPA files; expected exactly one."
		case .payloadNotFound:
			return "IPA is missing a Payload directory."
		case .appBundleNotFound:
			return "IPA Payload does not contain exactly one .app bundle."
		case .bundleIdentifierMissing:
			return "The app bundle is missing CFBundleIdentifier."
		case .certificateMissing:
			return "Autoloader needs a signing certificate configured."
		case .pairingMissing:
			return "Autoloader needs an idevice pairing file. Import one in Settings → Installation."
		case .signingFailed(let message):
			return "Signing failed: \(message)"
		case .installationFailed(let message):
			return "Install failed: \(message)"
		case .launchFailed:
			return "The app installed, but Autoloader could not launch it."
		}
	}
}

enum AutoloaderErrorFormatting {
	static func describe(_ error: Error) -> String {
		if let autoloader = error as? AutoloaderError {
			return autoloader.localizedDescription
		}
		if let localized = error as? LocalizedError, let description = localized.errorDescription, !description.isEmpty {
			return description
		}

		let mirror = Mirror(reflecting: error)
		if let message = mirror.children.first(where: { $0.label == "_message" })?.value as? String, !message.isEmpty {
			return message
		}

		let description = error.localizedDescription
		if description != String(describing: error) || !description.isEmpty {
			return description
		}
		return String(describing: error)
	}
}
