# Upstream

Autoloader is a fork of [Feather](https://github.com/clamation/Feather).

| Field | Value |
| --- | --- |
| Upstream repository | https://github.com/clamation/Feather |
| Upstream default branch | `main` |
| Fork point (`HEAD` at clone) | `0de794dbcf362b292695ae4fe68297cba3d1acc4` |
| Upstream commit subject | `lang(pl): update translations (#681)` |
| Upstream commit date | 2026-07-24 |
| Local working branch | `autoloader` |

Submodules at fork point:

| Path | Repository | Commit |
| --- | --- | --- |
| `IDeviceKitten` | https://github.com/khcrysalis/IDeviceKit | `837cf1e14d4875771dd5ee1b754a4c86215c5db3` |
| `Zsign` | https://github.com/khcrysalis/Zsign-Package | `6ffe703df73ef9069adacdbb19d571f11a69a801` |

Feather is licensed under GPL-3.0. This fork keeps that license and upstream attribution.

When rebasing onto newer Feather:

1. Fetch `upstream/main`.
2. Rebase `autoloader` onto the new Feather commit.
3. Expect conflicts mainly around `FeatherApp.swift` URL handling, `InstallPreviewView`, `FR.swift`, `SigningHandler`, `AppFileHandler`, and settings.
4. Update the table above with the new fork point.
