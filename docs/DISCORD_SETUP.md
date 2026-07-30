# UI Importer Pro Discord Server Blueprint

This is the recommended launch structure for the official community server.

## Server identity

- Name: **UI Importer Pro**
- Purpose: installation help, beta testing, bug reports, feature requests,
  showcases, and contributor coordination
- Icon: the same UI Importer Pro icon used by the Roblox Studio toolbar

## Roles

Create roles in this order:

1. **Owner**
2. **Developer**
3. **Moderator**
4. **Contributor**
5. **Beta Tester**
6. **Community**

Only Owner, Developer, and Moderator should manage channels or moderate
members. Do not give broad Administrator permission to community roles.

## Categories and channels

```text
START HERE
#welcome
#rules
#announcements
#get-started

SUPPORT
#help-and-support
#bug-reports
#feature-requests

COMMUNITY
#general
#showcase
#resources

DEVELOPMENT
#beta-testing
#changelog
#github-updates

VOICE
General
Support Room
```

Recommended channel topics:

- `#welcome`: what the plugin does and where to download it.
- `#rules`: the community rules below.
- `#announcements`: verified releases and maintenance notices.
- `#get-started`: installation, first import, and documentation links.
- `#help-and-support`: questions using the support template.
- `#bug-reports`: reproducible plugin defects; link to GitHub for tracking.
- `#feature-requests`: one idea per thread with its Roblox workflow.
- `#showcase`: UI imported with the plugin, only with permission to share.
- `#beta-testing`: beta builds, test files, and device results.
- `#changelog`: release summaries linked to GitHub releases.
- `#github-updates`: pull requests and issues, preferably through a limited bot.

## Rules

1. Be respectful. No harassment, hate speech, threats, or targeted abuse.
2. Do not spam, advertise without permission, or impersonate the project team.
3. Share only files and artwork you own or have permission to distribute.
4. Do not post passwords, tokens, private client files, or personal information.
5. Use support channels for support and include enough information to reproduce
   the problem.
6. Do not redistribute unofficial builds as if they are official.
7. Report security problems privately according to `SECURITY.md`.
8. Follow Discord's Terms of Service and Community Guidelines.

## Welcome message

> Welcome to UI Importer Pro! This server is for help, beta testing, feature
> ideas, and showcases for the Roblox Studio PSD and native Figma importer.
> Start in #get-started, download builds only from the official GitHub
> repository, and never post a private design file unless you have permission.

## Get-started message

> **First import**
>
> 1. Download `UIImporterPro.rbxm` from the latest GitHub release.
> 2. In Studio, open Plugins → Plugins Folder.
> 3. Install the file and restart Studio.
> 4. Open UI Importer Pro, choose a root and sizing mode, then import a PSD or
>    native `.fig`.
> 5. Find the generated root under StarterGui and test it in Device Emulator.
>
> Guide: https://qzhcore.github.io/UI-Importer-Pro-/
> Bugs: https://github.com/qzhcore/UI-Importer-Pro-/issues

## Support template

```text
Plugin version:
Studio version:
Operating system:
File type and document mode:
Root class:
Sizing mode:
What I expected:
What happened:
Output error:
Can I share a minimal reproduction file? yes/no
```

## Moderation and privacy

- Require verified email accounts.
- Enable AutoMod for spam, mention abuse, and harmful content.
- Use forum-style channels for bug reports and feature requests if available.
- Keep release downloads read-only and link only to official GitHub releases.
- Never require users to upload proprietary PSD or `.fig` files publicly.
- Create a private moderator channel for reports and security escalation.

## Launch checklist

- Add the server icon and description.
- Create roles and restrict management permissions.
- Create the categories and channels above.
- Post the rules, welcome, and get-started messages.
- Enable Community, rules screening, AutoMod, and onboarding.
- Create one non-expiring invite for the website and repository.
- Test the invite in a signed-out browser.
- Add the invite to the website, README, and GitHub repository sidebar.
- Recruit at least one trusted moderator before public promotion.
