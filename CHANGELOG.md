# Changelog

Notable changes to SRankAlert, newest first. See [README.md](README.md) for setup
and [CONFIG.md](CONFIG.md) for settings. Earlier versions below describe development
milestones; their release dates were not recorded.

## Unreleased

## 0.5.0 (prepared; not yet published)

### Added

- Persistent `config.json`, created automatically on first launch. Missing settings
  use defaults, and invalid values produce a warning instead of stopping the mod.
- A guided PowerShell installer with Steam detection, UE4SS checks, replacement
  prompts, backups and installation verification.
- A common/advanced settings guide and a complete customized example config.
- Windows CI for tests, installer checks and downloadable build artifacts.

### Changed

- Experimental mission restart now defaults off and requires a valid explicit
  `RESTART_ENABLED: true`. Missing, unreadable or malformed configuration cannot
  enable it. Existing valid settings remain untouched, including older true values.
- Startup logs report whether restart is enabled, and documentation distinguishes
  direct mod file writes from the game's unverified restart side effects.
- Mod updates preserve the player's settings file.
- Restart fill now stretches between matching top and bottom border insets.
  Native screenshot confirmation of this small edge adjustment remains pending.
- Consolidated public version history here; local API research and generated
  build output are excluded from the repository and release package.

### Fixed

- Steam paths with different capitalization no longer appear as duplicate installs.
- Successful font readback and reflection-shape diagnostics now stay quiet unless
  their diagnostic setting is enabled; failures remain visible in ordinary logs.
- Updated installation availability, detection limitations and the live-test checklist
  to match the prepared release, and added package-to-installer and version checks.

### Removed

- Unused `FONT_CONTEXT_FACE` and `FONT_CONTROL_FACE` settings. Existing config
  files still load; obsolete entries are ignored.

## 0.4.4

### Changed

- Replaced the styled progress bar with a solid rectangle whose width follows
  hold progress. The fill stays inside the restart tile, below its outline and key label.

## 0.4.3

### Changed

- Made the restart fill solid and vivid against a dark tile background.
- Added fill saturation, brightness and empty-tile color settings.

## 0.4.2

### Changed

- Added stronger text outlines and shadows, plus dark backing for tile outlines.
- Kept action labels on one line with more room for HOLD TO RESTART.

## 0.4.1

### Changed

- Added explicit spacing above and below the headline divider.
- Made the progress fill fully opaque and adjusted the control-group spacing.

## 0.4.0

### Changed

- Replaced prose control hints with two outlined key tiles: DISMISS and HOLD TO RESTART.
- Integrated hold progress into the restart tile. Clients see only the dismiss action.

## 0.3.2

### Changed

- Standardized controls on F9: a short tap dismisses, and a deliberate three-second
  hold requests restart for the host. Releasing a longer, incomplete hold keeps the alert.
- Removed the older F6 toggle and Shift+R restart shortcut.
- Used Roboto for small text and added optional font-diagnostic specimens.
- Added explicit INCIDENT, WARNING and STATUS prefixes so meaning does not depend on color.
- Removed redundant context when it repeated the headline.
