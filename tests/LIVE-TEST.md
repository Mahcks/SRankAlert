# 0.5.0 live release checks

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

These observations predate the prepared 0.5.0 ZIP. They do not establish a complete
current-release pass.

## Controls and mission behavior

- [ ] On a fresh config, confirm restart defaults off and the host sees only dismiss.
  Enable `RESTART_ENABLED` explicitly in a disposable test config before the restart
  and hold-fill checks below. Restore it to false after testing if desired.
- [ ] Check F9 against the base game's default controls and any custom bindings.
  Saved bindings inspected locally have no F9 mapping; this is not proof of defaults.
- [ ] With an alert showing, tap F9 for no more than about 0.3 seconds and release:
  it dismisses and future alerts still work. No R, F6, toggle or modifier shortcut.
- [ ] Hold for one second and release: the alert stays and its progress empties.
  A key held before the alert must first be released before restart can arm.
- [ ] Confirm co-op clients only see dismiss and cannot request restart.
- [ ] In a disposable single-player mission, deliberately hold for three seconds;
  verify a fresh mission starts and the request does not repeat. Then separately
  verify as co-op host. Do not perform these tests during a run you care about.
- [ ] With `RESTART_ENABLED` false, only dismiss is offered to the host.
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
  must never be presented as a final S-rank guarantee. Spectator HUD is unsupported.

Restart is still unverified in a live mission. Keep the README's warning until
the relevant checks above have evidence; do not mark them passed from mocks.
