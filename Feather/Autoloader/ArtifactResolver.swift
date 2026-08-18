//
//  ArtifactResolver.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import Foundation
import Zip

enum ArtifactResolver {
	static func resolveIPA(from artifact: URL, jobDirectory: URL) async throws -> URL {
		try await Task.detached(priority: .utility) {
			try resolveIPASync(from: artifact, jobDirectory: jobDirectory)
		}.value
	}

	private static func resolveIPASync(from artifact: URL, jobDirectory: URL) throws -> URL {
		try FileManager.default.createDirectoryIfNeeded(at: jobDirectory)

		let extractRoot = jobDirectory.appendingPathComponent("extract", isDirectory: true)
		try FileManager.default.removeFileIfNeeded(at: extractRoot)
		try unzip(artifact, to: extractRoot)
		try assertExtractedFilesStay(in: extractRoot)

		let payload = extractRoot.appendingPathComponent("Payload")
		if FileManager.default.fileExists(atPath: payload.path) {
			_ = try validatedPayloadApp(in: extractRoot)
			return try materializeIPA(from: artifact, jobDirectory: jobDirectory)
		}

		let candidates = try collectIPACandidates(in: extractRoot, root: extractRoot)
		if candidates.isEmpty {
			throw AutoloaderError.ipaNotFound
		}
		if candidates.count > 1 {
			throw AutoloaderError.multipleIPAsFound(candidates.count)
		}

		return try materializeIPA(from: candidates[0], jobDirectory: jobDirectory)
	}

	private static func materializeIPA(from source: URL, jobDirectory: URL) throws -> URL {
		let resolved = jobDirectory.appendingPathComponent("resolved.ipa")
		try FileManager.default.removeFileIfNeeded(at: resolved)
		try FileManager.default.copyItem(at: source, to: resolved)
		return resolved
	}

	private static func collectIPACandidates(in directory: URL, root: URL) throws -> [URL] {
		guard let enumerator = FileManager.default.enumerator(
			at: directory,
			includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey],
			options: [.skipsHiddenFiles]
		) else {
			return []
		}

		var archives: [URL] = []
		while let file = enumerator.nextObject() as? URL {
			try assertNoEscape(file, root: root)

			let values = try file.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
			if values.isSymbolicLink == true {
				try assertNoEscape(file.resolvingSymlinksInPath(), root: root)
			}
			if values.isDirectory == true {
				continue
			}
			if isZipArchive(file) {
				archives.append(file)
			}
		}

		var candidates: [URL] = []
		let inspectRoot = directory.deletingLastPathComponent().appendingPathComponent("ipa-inspect", isDirectory: true)
		try FileManager.default.createDirectoryIfNeeded(at: inspectRoot)

		for (index, file) in archives.enumerated() {
			let inspectDir = inspectRoot.appendingPathComponent("\(index)", isDirectory: true)
			do {
				try unzip(file, to: inspectDir)
				try assertExtractedFilesStay(in: inspectDir)
				_ = try validatedPayloadApp(in: inspectDir)
				candidates.append(file)
			} catch {
				try? FileManager.default.removeItem(at: inspectDir)
				continue
			}
			try? FileManager.default.removeItem(at: inspectDir)
		}

		try? FileManager.default.removeItem(at: inspectRoot)
		return candidates
	}

	private static func validatedPayloadApp(in extracted: URL) throws -> URL {
		let payload = extracted.appendingPathComponent("Payload")
		guard FileManager.default.fileExists(atPath: payload.path) else {
			throw AutoloaderError.payloadNotFound
		}

		let apps = try FileManager.default.contentsOfDirectory(
			at: payload,
			includingPropertiesForKeys: nil,
			options: [.skipsHiddenFiles]
		).filter { $0.pathExtension == "app" }

		guard !apps.isEmpty else {
			throw AutoloaderError.appBundleNotFound
		}
		guard apps.count == 1 else {
			throw AutoloaderError.appBundleNotFound
		}
		return apps[0]
	}

	private static func unzip(_ file: URL, to destination: URL) throws {
		try FileManager.default.createDirectoryIfNeeded(at: destination)

		var archive = file
		let ext = file.pathExtension.lowercased()
		if !["zip", "ipa", "tipa"].contains(ext) {
			archive = destination.deletingLastPathComponent().appendingPathComponent("source-\(UUID().uuidString).zip")
			try FileManager.default.copyItem(at: file, to: archive)
		}

		if archive.pathExtension.lowercased() == "ipa" {
			Zip.addCustomFileExtension("ipa")
		}
		if archive.pathExtension.lowercased() == "tipa" {
			Zip.addCustomFileExtension("tipa")
		}

		do {
			try Zip.unzipFile(archive, destination: destination, overwrite: true, password: nil)
		} catch {
			throw AutoloaderError.invalidArchive
		}
	}

	private static func isZipArchive(_ url: URL) -> Bool {
		guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
		defer { try? handle.close() }
		guard let header = try? handle.read(upToCount: 4), header.count >= 4 else { return false }
		let bytes = [UInt8](header)
		return bytes[0] == 0x50 && bytes[1] == 0x4B && (
			(bytes[2] == 0x03 && bytes[3] == 0x04) ||
			(bytes[2] == 0x05 && bytes[3] == 0x06) ||
			(bytes[2] == 0x07 && bytes[3] == 0x08)
		)
	}

	private static func assertExtractedFilesStay(in destination: URL) throws {
		let root = destination.standardizedFileURL.resolvingSymlinksInPath()
		let rootPath = root.path
		let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

		guard let enumerator = FileManager.default.enumerator(
			at: destination,
			includingPropertiesForKeys: [.isSymbolicLinkKey],
			options: []
		) else {
			return
		}

		while let file = enumerator.nextObject() as? URL {
			try assertNoEscape(file, root: root, prefix: prefix)
			let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey])
			if values.isSymbolicLink == true {
				try assertNoEscape(file.resolvingSymlinksInPath(), root: root, prefix: prefix)
			}
		}
	}

	private static func assertNoEscape(_ url: URL, root: URL, prefix: String? = nil) throws {
		let resolved = url.standardizedFileURL.path
		let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
		let rootPrefix = prefix ?? (rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
		if resolved != rootPath && !resolved.hasPrefix(rootPrefix) {
			throw AutoloaderError.invalidArchive
		}
	}
}
