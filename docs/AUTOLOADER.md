# Autoloader

Autoloader is a development-loop installer on the iPhone. After it is set up, a successful run is one action: open an `autoloader://` link. It downloads the artifact, signs it with the certificate already in Settings, installs or upgrades the app, and launches it.

This is not a storefront. Feather’s certificate and installation screens remain for first-time setup.

Upstream signing internals: [HOW_IT_WORKS.md](../HOW_IT_WORKS.md). Fork point: [UPSTREAM.md](../UPSTREAM.md).

---

## Pipeline

```
autoloader://install?url=<encoded-https-url>
    |
    +--> download artifact
    +--> treat it as an IPA if Payload/*.app exists (filename does not matter)
    +--> or unwrap a ZIP that contains exactly one IPA
    +--> import
    +--> inject a deterministic launch URL scheme
    +--> sign with the configured certificate
    +--> install using the method in Settings → Installation
    |       same bundle ID => upgrade in place, never uninstall first
    +--> launch the app
    +--> delete temp copies (unless Keep build artifacts is on)
```

Jobs are serialized. A second link while a job is running replaces the pending request. An install that has already started is not cancelled.

Keep the target app’s `CFBundleIdentifier` stable. Autoloader does not add PPQ suffixes or random IDs on this path.

---

## Protocol

```
autoloader://install?v=1&url=<percent-encoded-artifact-url>
```

Usual form:

```
autoloader://install?url=<encoded-url>
```

| Query | Default | Meaning |
| --- | --- | --- |
| `v` | `1` | Protocol version. Only `1` is supported. |
| `url` | required | Artifact URL. Encoded as one query value. |
| `sha256` | none | Optional 64-character lowercase hex digest. |
| `launch` | `1` | `0` installs without launching. |

Build the URL with a query encoder so inner `?`, `&`, and `=` on the artifact URL survive.

```python
from urllib.parse import quote
print("autoloader://install?url=" + quote(artifact_url, safe=""))
```

```swift
var components = URLComponents()
components.scheme = "autoloader"
components.host = "install"
components.queryItems = [
    URLQueryItem(name: "v", value: "1"),
    URLQueryItem(name: "url", value: artifactURL.absoluteString)
]
let url = components.url
```

`url` must be `https` (or `http` if **Allow insecure HTTP** is on). `file://` is rejected. If **Allowed artifact hosts** is nonempty, the host must match exactly.

Autoloader’s downloader is a plain `URLSession` GET. The `url` value has to be something that returns IPA/ZIP bytes without a browser login.

---

## How installation works on the phone

Signing always happens on-device with the certificate you already imported. Installation is a separate step. Autoloader uses **whatever Installation Type is selected in Settings → Installation**, the same switch Feather uses.

### Server (default)

This is the same path you already use in Feather. Autoloader hosts the signed IPA on a local server on the phone, then asks iOS to install it with `itms-services://` (fully local) or the semi-local web trick.

- No pairing file.
- No VPN.
- No extra app to keep running.

iOS itself performs the install. You may still get the system “Install” sheet. That is iOS, not Autoloader’s signing UI.

Fully local needs the SSL certificates Feather already downloads from backloop.dev. Semi local uses the palera plist helper, same as Feather.

### idevice

This talks to `installd` the way a computer running `ideviceinstaller` would.

It needs a **pairing file** (exported once from a computer; see Settings → Installation).

On **iOS before 17.4**, it also needs **LocalDevVPN** (or an equivalent loopback VPN) **while the install is happening**. That VPN is not a general privacy VPN. It creates a tunnel so the app can reach lockdownd at `10.7.0.1` as if a USB computer were attached. You do not leave it on all day. You only need it connected for an idevice install.

On **iOS 17.4 and later**, Feather uses RSD instead of that `10.7.0.1` TCP tunnel, and the in-app LocalDevVPN buttons are hidden. A pairing file is still required for idevice.

idevice is more reliable and usually skips the system install sheet. It is optional. If you do not want pairing or VPN, leave Installation Type on **Server**.

---

## Setup on the phone

1. Install Autoloader (sign its IPA with Feather the first time).
2. Import a signing certificate.
3. Leave **Automatic installs** on.
4. Leave Installation Type on **Server** unless you specifically want idevice.

Then open `autoloader://install?url=...`.
