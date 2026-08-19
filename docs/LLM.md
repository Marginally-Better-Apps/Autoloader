# LLM guide

Follow [AUTOLOADER.md](./AUTOLOADER.md), especially **For LLMs: put the install link on the PR**.

Short contract:

1. After CI builds an unsigned IPA, upload the IPA bytes to a public HTTPS host (Planista or a GitHub Release). Not `actions/upload-artifact`.
2. Build `autoloader://install?url=` + a single `urllib.parse.quote(..., safe="")` of that permalink.
3. Host a tiny HTML trampoline that `location.replace`s that Autoloader URL, and put the HTML permalink on the PR so it is tappable.
4. Also paste the raw `autoloader://` URL in a fenced code block.

If Autoloader’s host allowlist is nonempty, include `planista.shloklab.us` and/or `github.com`.
