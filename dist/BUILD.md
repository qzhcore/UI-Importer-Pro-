# UI Importer Pro 0.4.0-beta.1

Built from the accompanying source using Rojo 7.6.1 on 2026-11-04.

- Artifact: UIImporterPro.rbxm
- SHA-256: 47E4DE92F15D2785B2B6EFB051CF875FE51888C9CE2643A893C1518F6A42BB2E
- Script entry point uses RunContext.Plugin; all 37 bundled scripts compile.
- 75 automated regression cases pass.
- Native Studio smoke checks pass for three root types, isolated flow/absolute
  layout, and temporary image pixel readback.
- Native architecture checks preserve script content, a custom attribute, object
  identity, and a live event connection. Padded geometry matches at 400/800 widths.
- Lint and formatting checks pass.

Install and test in a separate empty place using [these steps](../docs/TEST_BUILD.md).
The artifact contains plugin code only, with no private source designs or test place.
This is a beta test build; remaining visual and upload acceptance work is listed in
[validation](../docs/REFACTOR_VALIDATION.md).
