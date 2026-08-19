# LLM / agent notes for Autoloader

Read [docs/AUTOLOADER.md](docs/AUTOLOADER.md) before changing Autoloader or wiring it into another app’s CI.

Autoloader is a one-job iPhone installer: open `autoloader://install?url=...`, get the new build running. Do not add storefront UX.

When you add Autoloader to another repo, the definition of done is a PR comment with a tappable HTTPS install link after CI builds the IPA. GitHub Actions artifact URLs are not enough.
