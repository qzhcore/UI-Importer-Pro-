# Beta Launch Checklist

Use this list for 0.3.0-beta.3 and future public betas.

## Product

- [x] Toolbar name, icon, hover text, and dock widget are present.
- [x] PSD import succeeds on the beta test document.
- [x] Imported output is created under `StarterGui`.
- [x] Photoshop effects are preserved through `RenderedDesign`.
- [x] Semantic Roblox controls are available for scripting.
- [x] Adaptive and preserve-aspect modes are available.
- [x] Lint, format, and Rojo build checks pass.
- [ ] Repeat the smoke test on a clean Studio installation.
- [ ] Test one PSD without effects and one native `.fig`.
- [ ] Test phone, tablet, desktop, console, and supported VR viewports.

## GitHub

- [x] README, guide, scripting guide, troubleshooting, changelog, and policies.
- [x] Bug and feature request forms.
- [x] Pull request template.
- [x] CI build and lint workflow.
- [x] GitHub Pages deployment workflow.
- [x] Tagged-release build workflow.
- [ ] Merge the beta launch pull request into `main`.
- [ ] Set the repository description, topics, and website URL.
- [ ] Enable Issues and private vulnerability reporting.
- [ ] Configure GitHub Pages to use **GitHub Actions**.
- [ ] Add basic branch protection for `main`.
- [ ] Create and push the `v0.3.0-beta.3` tag.
- [ ] Verify the release contains the generated `UIImporterPro.rbxm`.
- [ ] Download the release asset and compare its SHA-256 to the validated build.

Suggested repository topics:

```text
roblox roblox-studio plugin ui psd figma design-import design-to-code luau
```

## Website

- [x] Responsive landing page.
- [x] Installation, workflow, scripting, limitations, and support links.
- [x] Original social preview card with no private user artwork.
- [ ] Verify the production URL after the PR merges.
- [ ] Test navigation and downloads on phone and desktop.
- [ ] Replace the "Discord is being prepared" message with the official invite.
- [ ] Add a privacy-friendly analytics tool only if there is a clear need.

## Discord

- [x] Server structure, roles, rules, welcome copy, and support template drafted.
- [ ] Create the server.
- [ ] Configure role permissions and AutoMod.
- [ ] Enable Community, rules screening, and onboarding.
- [ ] Post welcome, rules, and get-started messages.
- [ ] Create a non-expiring official invite.
- [ ] Add the invite to the website, README, and GitHub sidebar.
- [ ] Recruit at least one trusted moderator.

## Release operations

- [ ] Publish release notes with supported formats and known limitations.
- [ ] Label the build as beta everywhere.
- [ ] Keep the previous release available for rollback.
- [ ] Define a response target for reproducible beta bugs.
- [ ] Triage issues weekly into bug, enhancement, question, and unsupported-file.
- [ ] Never request confidential artwork in a public support channel.

## Release command

After the launch pull request is merged and the `main` build is green:

```bash
git switch main
git pull --ff-only
git tag -a v0.3.0-beta.3 -m "UI Importer Pro 0.3.0 beta 3"
git push origin v0.3.0-beta.3
```

The release workflow builds `UIImporterPro.rbxm` from the tagged source and
publishes it to GitHub Releases.

## Rollback

If a release-blocking defect is discovered:

1. Mark the GitHub release as a pre-release or remove the release from the
   recommended installation path.
2. Pin support messages to the last known-good version.
3. Open a public issue that describes impact without exposing private files.
4. Fix on a branch, repeat the test matrix, and publish a new beta tag.
5. Do not silently replace an existing tagged release asset.
