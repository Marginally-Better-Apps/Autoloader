//
//  AutoloaderView.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import SwiftUI
import NimbleViews

struct AutoloaderView: View {
	@ObservedObject var coordinator = AutoloaderCoordinator.shared
	@ObservedObject var settings = AutoloaderSettings.shared

	var body: some View {
		NBNavigationView("Autoloader") {
			List {
				Section {
					VStack(alignment: .leading, spacing: 8) {
						Text(statusTitle)
							.font(.title3.weight(.semibold))
						if let name = coordinator.currentAppName {
							Text(name)
								.foregroundStyle(.secondary)
						}
						Text(statusDetail)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
					.padding(.vertical, 4)
				}

				Section {
					Toggle("Automatic installs", isOn: $settings.automaticInstalls)
					NavigationLink("Settings") {
						AutoloaderSettingsView()
					}
				} footer: {
					Text("Open autoloader://install?url=… to download, sign, install, and launch a build. A successful run does not ask for extra taps.")
				}

				if !coordinator.history.isEmpty {
					Section {
						ForEach(coordinator.history) { entry in
							VStack(alignment: .leading, spacing: 4) {
								HStack {
									Text(entry.appName ?? entry.bundleIdentifier ?? "Build")
										.font(.headline)
									Spacer()
									Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
										.foregroundStyle(entry.success ? .green : .red)
								}
								if let bundle = entry.bundleIdentifier {
									Text(bundle)
										.font(.caption)
										.foregroundStyle(.secondary)
								}
								Text(entry.sourceURL)
									.font(.caption2)
									.foregroundStyle(.secondary)
									.lineLimit(2)
								if let error = entry.errorDescription {
									Text(error)
										.font(.caption)
										.foregroundStyle(.orange)
								}
							}
							.padding(.vertical, 2)
						}
					} header: {
						Text("Recent")
					}
				}
			}
		}
	}

	private var statusTitle: String {
		switch coordinator.state {
		case .idle:
			return "Ready"
		default:
			return coordinator.state.title
		}
	}

	private var statusDetail: String {
		switch coordinator.state {
		case .idle:
			if settings.automaticInstalls {
				return "Waiting for an autoloader:// install link."
			}
			return "Automatic installs are off."
		case .failed(let stage, let message):
			return "\(stage.rawValue): \(message)"
		case .completed(let result) where result.launchAttempted && !result.launched:
			return "\(result.bundleIdentifier) installed, but launch failed."
		case .completed(let result):
			return result.bundleIdentifier
		default:
			return coordinator.currentAppName ?? "Working…"
		}
	}
}
