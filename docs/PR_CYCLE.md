# PR cycle for apps Autoloader installs

GitHub will not let Autoloader fetch Actions artifacts (login wall), and GitHub markdown will not make `autoloader://` tappable. PR CI should therefore:

1. Publish the unsigned IPA as a public prerelease tagged `pr-<number>` with a stable filename.
2. Put a GitHub Pages page at `/pr/<number>/` that opens `autoloader://install?url=<encoded release URL>`.
3. Comment the Pages `https://` link on the PR.

QR Scanner is the reference implementation: [AUTOLOADER_DEV_CYCLE.md](https://github.com/Marginally-Better-Apps/MB-QR-Code-Scanner/blob/main/docs/AUTOLOADER_DEV_CYCLE.md).

Do not upload the IPA to Planista. Do not use nightly.link. Leave Autoloader’s Installation Type on **Server**.
