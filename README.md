# Autoloader

Autoloader is a [Feather](https://github.com/clamation/Feather) fork for one job: open an `autoloader://` link, install the IPA on this iPhone, and launch the new build.

It is a development-loop tool, not a general IPA storefront. Feather’s certificate and installation screens stay for first-time setup. After that, a successful install should not ask for extra taps.

This project remains licensed under **GPL-3.0**. See [LICENSE](./LICENSE) and [UPSTREAM.md](./UPSTREAM.md).

## Download

Get the unsigned iPhone IPA from [Releases](https://github.com/Marginally-Better-Apps/Autoloader/releases):

https://github.com/Marginally-Better-Apps/Autoloader/releases/latest/download/Autoloader.ipa

That build is ad-hoc signed (not Apple-signed). Import it into Feather, sign it with your certificate, and install it. After Autoloader is on the phone, use `autoloader://` links instead of Feather for later builds.

## Docs

- [How Autoloader works](./docs/AUTOLOADER.md)
- [Short contract for LLMs](./docs/LLM.md)

## What it does

```
development tooling
    |
    | open:
    | autoloader://install?url=<encoded-url>
    v
Autoloader opens
    |
    +--> download artifact
    +--> locate IPA
    +--> import/extract
    +--> inject deterministic Autoloader launch URL scheme
    +--> sign with the configured certificate
    +--> install using Settings → Installation (Server by default, or idevice)
    +--> launch the newly installed app
```

If the same bundle ID is already installed, Autoloader upgrades it in place. It does not uninstall first.

## URL protocol

```
autoloader://install?v=1&url=<percent-encoded-artifact-url>
```

The usual link only needs:

```
autoloader://install?url=<encoded-url>
```

Optional query items:

| Item | Default | Meaning |
| --- | --- | --- |
| `v` | `1` | Protocol version |
| `sha256` | none | Lowercase hex SHA-256 of the artifact |
| `launch` | `1` | Set `0` to install without launching |

Use `URLComponents` so inner `?`, `&`, and `=` on the artifact URL survive:

```swift
func openInAutoloader(_ artifactURL: URL) {
    var components = URLComponents()
    components.scheme = "autoloader"
    components.host = "install"
    components.queryItems = [
        URLQueryItem(name: "v", value: "1"),
        URLQueryItem(name: "url", value: artifactURL.absoluteString)
    ]
    guard let url = components.url else { return }
    UIApplication.shared.open(url)
}
```

Examples:

```
autoloader://install?url=https%3A%2F%2Fexample.com%2FMyApp.ipa
autoloader://install?url=https%3A%2F%2Fexample.com%2Fartifact.zip
autoloader://install?url=<encoded>&sha256=0123456789abcdef...
autoloader://install?url=<encoded>&launch=0
```

Direct IPAs are detected by archive structure (`Payload/*.app`), not file extension. A wrapper ZIP may contain one IPA, including inside a subdirectory. Multiple IPAs in one wrapper is an error.

## First-time setup

1. Set `FEATHER_PRODUCT_BUNDLE_IDENTIFIER` in `Feather.xcconfig` to a bundle ID you control. The default is `org.marginallybetter.Autoloader`.
2. Open `Feather.xcworkspace` (not the project).
3. Choose your signing team in Xcode. This repo does not include an Apple Team ID.
4. Build and install Autoloader on a physical iPhone.
5. Import a signing certificate. Leave Installation Type on **Server** unless you want idevice (pairing file, and on older iOS a loopback VPN during the install only).
6. Leave **Automatic installs** on. Add allowed artifact hosts if you want a host allowlist. HTTP is off unless you enable **Allow insecure HTTP** for LAN/Tailscale servers.

Running a build after that should only require opening the `autoloader://` link.

## Build

```
git clone --recurse-submodules https://github.com/Marginally-Better-Apps/Autoloader.git
cd Autoloader
git submodule update --init --recursive
xed Feather.xcworkspace
```

Use the `Feather` scheme. Internal Xcode targets and Swift types are still named Feather so this stays mergeable with upstream.

## Status

The Autoloader tab shows the active job (`Downloading… 72%`, `Signing…`, `Installing…`, `Launching…`) and a short history. Errors are shown if something fails. A successful run does not present a confirmation that needs tapping.

## Security

`autoloader://install` can make this app download and sign arbitrary artifacts with your certificate. Settings therefore include:

- Automatic installs
- Allowed artifact hosts (empty means any HTTPS host)
- Allow insecure HTTP (off by default)

`file://` and other non-http(s) artifact URLs are rejected.

## Attribution

Autoloader is a fork of Feather by [Samara](https://github.com/clamation). See Feather’s [HOW_IT_WORKS.md](./HOW_IT_WORKS.md) for the underlying signing and idevice installation design. Upstream commit recorded in [UPSTREAM.md](./UPSTREAM.md).
