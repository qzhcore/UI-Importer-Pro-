# Privacy

UI Importer Pro 0.3.0-beta.3 reads the design file chosen through Roblox
Studio's local file picker. The plugin does not include analytics, advertising,
telemetry, account login, or intentional HTTP requests.

Decoded image pixels are converted into DataModel-scoped content with Roblox
Studio's `AssetService`. The plugin does not publish the source PSD or `.fig` as
a public marketplace asset.

Important limits:

- The generated place file can contain embedded visual content derived from the
  selected design.
- Anyone who receives that place or model may be able to view the generated UI.
- Do not share a reproduction place, PSD, `.fig`, screenshot, or Output log if
  it contains confidential client artwork or personal information.
- Community support should accept minimal reproduction files and never require
  users to post private production designs publicly.

Review source changes before installing unofficial builds. Download official
builds only from this repository's GitHub Releases page.
