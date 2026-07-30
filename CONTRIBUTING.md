# Contributing

Thanks for helping improve UI Importer Pro.

## Before opening an issue

- Search existing issues.
- Confirm the problem still occurs with the newest beta.
- Remove confidential artwork from screenshots and reproduction files.
- Include exact Studio Output errors and document properties.

## Development setup

```bash
git clone https://github.com/qzhcore/UI-Importer-Pro-.git
cd UI-Importer-Pro-
aftman install
rojo build default.project.json --output UIImporterPro.rbxm
```

## Pull requests

1. Keep each pull request focused.
2. Add or update documentation for user-visible behavior.
3. Run:

   ```bash
   stylua --check src
   selene src
   rojo build default.project.json --output UIImporterPro.rbxm
   ```

4. Test the plugin in Roblox Studio with a minimal design file.
5. Describe the root cause, behavior change, and validation in the pull request.

Do not commit private PSD or `.fig` files, Roblox security cookies, API keys,
generated dependency folders, or editor settings.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
