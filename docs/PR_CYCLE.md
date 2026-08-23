# PR cycle for apps Autoloader installs

GitHub Actions artifact URLs 404 unless you are logged in. GitHub markdown will not make `autoloader://` tappable.

1. Publish the unsigned IPA as a public prerelease tagged `pr-<number>` with a stable filename.
2. Comment this HTTPS link:

```
https://marginally-better-apps.github.io/Autoloader/?url=<percent-encoded release IPA URL>
```

That page is the shared shim. Do not add per-repo GitHub Pages trampolines.

QR Scanner still shows the older per-PR page pattern; new repos should use the shim above.

Do not upload the IPA to Planista. Do not use nightly.link. Leave Autoloader’s Installation Type on **Server**.
