# 0.5.4 live release checks

This is the current checklist, replacing the older per-version test instructions.
Unchecked items are pending. Simulated tests do not count as a live pass.
Record the game build, UE4SS build, resolution and UI scale with each result.

## Existing evidence

- [x] Earlier core incident detection observed in-game (limited playtime).
- [x] Roboto alphabet specimen confirmed by the tester; native log recorded Roboto.
- [x] Solid fill and visible progression confirmed by the tester before the latest
  bottom-edge adjustment.
- [x] Installer ran against the real game folder with the game closed; backups
  and copied-file hashes verified. First native load generated persistent JSON.
- [x] As co-op host, a teammate died, the alert appeared and holding F9 restarted the
  lobby; the score reset and the next attempt still earned an S rank (author's live
  play; mod version and config not recorded).

These observations do not establish a complete 0.5.4 release pass. The co-op
report did not record a mod version or config; do not infer them.

## Controls and mission behavior

- [ ] With restart enabled as host, die while another teammate is alive. Confirm
  the death alert and hold tile appear without first selecting spectate or Escape.
  With a two-second config, hold for less than two seconds and release (no restart),
  then deliberately complete a fresh hold. Confirm mission restart and no repeat.
- [ ] Repeat the death transition as a co-op client: dismiss works, restart is
  unavailable. Check F8, menu clicks, and that the overlay clears on mission exit.
- [ ] On a fresh config, confirm restart defaults on and the host sees both tiles.
  Use a disposable mission for the restart and hold-fill checks below.
- [ ] Check F9 against the base game's default controls and any custom bindings.
  Saved bindings inspected locally have no F9 mapping; this is not proof of defaults.
- [ ] With an alert showing, tap F9 for no more than about 0.3 seconds and release:
  it dismisses and future alerts still work. No R, F6 or modifier shortcut.
- [ ] Press F8 with and without an incident visible: one press toggles once, shows
  OFF/ON confirmation, and clears any current incident/restart hold when muted.
  Events while off must not replay when enabling; new events must still appear.
  Check `TOGGLE_KEY` customization and enabling from `START_ENABLED: false`.
- [ ] Hold for one second and release: the alert stays and its progress empties.
  A key held before the alert must first be released before restart can arm.
- [ ] Confirm co-op clients only see dismiss and cannot request restart.
- [ ] In a disposable single-player mission, deliberately hold for three seconds;
  verify a fresh mission starts and the request does not repeat. Then separately
  verify as co-op host. Do not perform these tests during a run you care about.
- [ ] With `"RESTART_ENABLED": false` in config.json, only dismiss is offered to the host.
- [ ] Leave an incident visible for 30 seconds; it remains. Trigger multiple
  incident groups: the current alert updates in place; full events remain in the log.
- [ ] Startup/status notices expire after 5.5 seconds, including fades. Mission
  changes clear old incidents. Check official-scoring suppression and partial reads.

## Appearance and accessibility

- [ ] Capture an incident at rest, around 50% hold, and near 90% hold. At 90%, release
  before three seconds unless ready to restart. The unfilled part on the right is
  expected below 100%; top and bottom should meet the inner border without a strip.
- [ ] Check both key glyphs and labels, current alert text and long names at 1080p,
  1440p and ultrawide, with representative UI scales. Look for clipping and overlap
  with compass, ammo, crosshair and other HUD elements.
- [ ] Compare actual alerts in bright and dark scenes, including a red vignette.
  Confirm INCIDENT / WARNING / STATUS wording remains readable without color.
- [ ] Verify the optional injury/bonus warning and incomplete-check notice; silence
  must never be presented as a final S-rank guarantee. Check the death/spectator
  transition separately; do not infer success from normal character-HUD captures.

Restart has only limited live evidence (the co-op host case above). Single-player,
save-file effects and the checks above still need evidence; do not mark them passed
from mocks.
