# Privacy

UI Importer Pro reads only the design file chosen through Roblox Studio's local
file picker. It has no analytics, advertising, telemetry, separate account login,
or custom HTTP client.

**Session preview** converts decoded artwork into temporary content through Roblox
Studio's AssetService. This content is scoped to the current Studio session.

**Upload to Roblox** explicitly uploads decoded image tiles to Roblox under the
owner selected in the plugin. Uploaded images include a name derived from the
source layer. They are subject to Roblox's moderation, permissions, and retention
rules. Cancelling or undoing an import does not delete uploaded assets. The plugin
does not upload the source PSD or FIG file itself.

Generated native UI includes design text, names, and source metadata. Anyone who
receives the place or model may be able to view those details and its artwork.
Avoid sharing confidential designs or Output logs as public bug reports; use
minimal reproduction files instead.

Review source changes before installing unofficial builds. Download official
builds only from this repository's GitHub Releases page.
