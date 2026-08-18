//
//  AutoloaderStatusHeader.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import SwiftUI

struct AutoloaderStatusHeader: View {
	@ObservedObject var coordinator = AutoloaderCoordinator.shared

	var body: some View {
		Group {
			if coordinator.state != .idle {
				VStack(alignment: .leading, spacing: 8) {
					Text("Autoloader")
						.font(.subheadline.weight(.semibold))
					if let name = coordinator.currentAppName, !name.isEmpty {
						Text(name)
							.font(.headline)
							.lineLimit(1)
					}
					Text(statusLine)
						.font(.subheadline)
						.foregroundStyle(statusColor)
					if case .downloading(let progress) = coordinator.state {
						ProgressView(value: progress)
							.progressViewStyle(.linear)
					} else if coordinator.state.isActive {
						ProgressView()
							.progressViewStyle(.linear)
					}
				}
				.padding(.horizontal)
				.padding(.vertical, 10)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color(UIColor.secondarySystemBackground))
			}
		}
		.animation(.smooth, value: coordinator.state.title)
	}

	private var statusLine: String {
		switch coordinator.state {
		case .failed(_, let message):
			return message
		default:
			return coordinator.state.title
		}
	}

	private var statusColor: Color {
		switch coordinator.state {
		case .failed:
			return .red
		case .completed(let result) where result.launchAttempted && !result.launched:
			return .orange
		case .completed:
			return .green
		default:
			return .secondary
		}
	}
}
