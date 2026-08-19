# LLM guide

Read [AUTOLOADER.md](./AUTOLOADER.md).

Autoloader is the on-phone installer. An `autoloader://install?url=` link is the API.

```
autoloader://install?url=<percent-encoded-https-url-to-ipa-or-zip>
```

Encode the artifact URL once:

```python
from urllib.parse import quote
print("autoloader://install?url=" + quote(artifact_url, safe=""))
```

Do not change Autoloader into a storefront. Do not invent extra signing or install screens on the success path.
