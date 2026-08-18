//
//  AutoloaderSettingsView.swift
//  Autoloader
//
//  A Feather fork. GPL-3.0.
//

import SwiftUI
import NimbleViews

struct AutoloaderSettingsView: View {
	@ObservedObject var settings = AutoloaderSettings.shared
	@State private var hostDraft = ""

	var body: some View {
		Form {
			Section {
				Toggle("Automatic installs", isOn: $settings.automaticInstalls)
				Toggle("Allow insecure HTTP", isOn: $settings.allowInsecureHTTP)
				Toggle("Keep build artifacts", isOn: $settings.keepBuildArtifacts)
			} footer: {
				Text("Automatic installs always use the idevice/installd backend. HTTP is for LAN or Tailscale development servers and is off by default. When Keep build artifacts is off, Autoloader deletes the imported and signed copies after a successful install.")
			}

			Section {
				ForEach(settings.allowedHosts, id: \.self) { host in
					HStack {
						Text(host)
						Spacer()
						Button(role: .destructive) {
							settings.removeHost(host)
						} label: {
							Image(systemName: "minus.circle.fill")
						}
						.buttonStyle(.plain)
					}
				}

				HStack {
					TextField("builds.example.com", text: $hostDraft)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
						.keyboardType(.URL)
					Button("Add") {
						settings.addHost(hostDraft)
						hostDraft = ""
					}
					.disabled(hostDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
				}
			} header: {
				Text("Allowed artifact hosts")
			} footer: {
				Text("If this list is empty, any HTTPS host is allowed. If it contains hosts, the artifact URL host must match exactly.")
			}

			Section {
				NavigationLink("Certificates") {
					CertificatesView()
				}
				NavigationLink("Installation & pairing") {
					InstallationView()
				}
				NavigationLink("Signing options") {
					ConfigurationView()
				}
			} header: {
				Text("Setup")
			} footer: {
				Text("Configure these once. Automatic installs do not present signing or install screens.")
			}

			Section {
				LabeledContent("This app") {
					Text(Bundle.main.bundleIdentifier ?? "unknown")
						.font(.caption)
						.textSelection(.enabled)
				}
				Text("Change FEATHER_PRODUCT_BUNDLE_IDENTIFIER in Feather.xcconfig before building if you need a different ID. Do not leave the upstream thewonderofyou.Feather identifier.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			} header: {
				Text("Bundle identifier")
			}
		}
		.navigationTitle("Autoloader")
	}
}
