//
//  ArtifactDownloader.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import CryptoKit
import Foundation

struct DownloadedArtifact: Sendable {
	let url: URL
	let byteCount: Int64
}

final class ArtifactDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
	private var continuation: CheckedContinuation<URL, Error>?
	private var progressHandler: (@MainActor (Double) -> Void)?
	private var destinationDirectory: URL?
	private var session: URLSession!

	override init() {
		super.init()
		let configuration = URLSessionConfiguration.ephemeral
		configuration.waitsForConnectivity = true
		session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
	}

	func download(
		_ remoteURL: URL,
		to directory: URL,
		progress: @escaping @MainActor (Double) -> Void
	) async throws -> DownloadedArtifact {
		try FileManager.default.createDirectoryIfNeeded(at: directory)

		let fileURL: URL = try await withCheckedThrowingContinuation { continuation in
			self.continuation = continuation
			self.progressHandler = progress
			self.destinationDirectory = directory
			session.downloadTask(with: remoteURL).resume()
		}

		let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
		let byteCount = attributes[.size] as? Int64 ?? 0
		return DownloadedArtifact(url: fileURL, byteCount: byteCount)
	}

	func verifySHA256(at fileURL: URL, expected: String) throws {
		let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
		let digest = SHA256.hash(data: data)
		let actual = digest.map { String(format: "%02x", $0) }.joined()
		if actual != expected.lowercased() {
			throw AutoloaderError.sha256Mismatch(expected: expected.lowercased(), actual: actual)
		}
	}

	func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didFinishDownloadingTo location: URL
	) {
		guard let directory = destinationDirectory else {
			resume(.failure(AutoloaderError.downloadFailed("Missing download directory")))
			return
		}

		do {
			let suggested = URL(fileURLWithPath: downloadTask.response?.suggestedFilename ?? "artifact.bin").lastPathComponent
			let safeName = suggested.isEmpty ? "artifact.bin" : suggested
			let temporary = directory.appendingPathComponent("download.tmp")
			let destination = directory.appendingPathComponent(safeName)

			try FileManager.default.removeFileIfNeeded(at: temporary)
			try FileManager.default.removeFileIfNeeded(at: destination)
			try FileManager.default.copyItem(at: location, to: temporary)
			try FileManager.default.moveItem(at: temporary, to: destination)
			resume(.success(destination))
		} catch {
			resume(.failure(AutoloaderError.downloadFailed(error.localizedDescription)))
		}
	}

	func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didWriteData bytesWritten: Int64,
		totalBytesWritten: Int64,
		totalBytesExpectedToWrite: Int64
	) {
		let fraction: Double
		if totalBytesExpectedToWrite > 0 {
			fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
		} else {
			fraction = 0
		}
		let handler = progressHandler
		Task { @MainActor in
			handler?(min(1, max(0, fraction)))
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		guard let error else { return }
		resume(.failure(AutoloaderError.downloadFailed(error.localizedDescription)))
	}

	private func resume(_ result: Result<URL, Error>) {
		guard let continuation else { return }
		self.continuation = nil
		continuation.resume(with: result)
	}
}
