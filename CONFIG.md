# Editing your settings

Settings reference for version 0.5.1.

Want a different key, a bigger alert, or no restart button? Start with
[Settings most people will want to change](#settings-most-people-will-want-to-change).
You can leave the rest alone. For a worked example before installing, see
[config.example.json](config.example.json) in the repo: it uses F11, a slightly
larger and higher alert, and warnings for civilian injuries. Restart stays off;
its four-second hold setting only takes effect if you explicitly enable restart.
That last option is off by default because its S-rank effect is unverified.

Start the game once and SRankAlert will make your settings file for you:
`ReadyOrNot\Binaries\Win64\ue4ss\Mods\SRankAlert\config.json`. You'll find it beside
`Scripts`, not inside it. To make a change, close the game, open that file in
Notepad, save it as UTF-8, and start the game again. Settings don't reload while
you're playing, and there isn't an in-game settings menu yet.

Your choices stay put when you update. The installer leaves `config.json` alone,
and the ZIP doesn't include a replacement for it. You don't have to add every
setting listed here, either: anything missing uses its current default, including
individual switches inside `TRIGGERS`. If an update adds a new option, add it to
your file only when you want to change it.

**Jump to:**

- [Settings most people will want to change](#settings-most-people-will-want-to-change)
- [Which incidents produce alerts](#which-incidents-produce-alerts)
- [Advanced / visual tuning](#advanced--visual-tuning)
- [A few editing tips](#a-few-editing-tips)

## Settings most people will want to change

These are the everyday choices. Change one or two, try a mission, and see how it
feels. You don't need to work through the whole file.

| Field | Default | What it does and allowed values |
|---|---|---|
| `ACTION_KEY` | `"F9"` | One Unreal Engine key name for both dismiss and restart, such as `F9`, `F11`, `Home` or `ThumbMouseButton`. Use a letter first, then letters, digits or underscores, up to 64 characters. Names are case-sensitive to the game. The loader checks the format, not whether the game recognizes the name or another mod uses it. No chords such as `Ctrl+F9`; this mod has no modifier settings. Choose a key that is not a movement/combat control. |
| `TOGGLE_KEY` | `"F8"` | Turns alerts off/on while the character HUD is attached, even with no alert showing. Same key-name format as `ACTION_KEY`, or `""` to disable the shortcut. Must differ from `ACTION_KEY`; a matching name disables the toggle with a log warning. Other mods may also use F8. Missing fields in older configs use F8 automatically. |
| `RESTART_ENABLED` | `false` | `true` opts into the experimental host/single-player hold-to-restart action, which is still unverified in a live mission. Tap-to-dismiss works either way. Missing or invalid values leave restart off. |
| `RESTART_HOLD_SECONDS` | `3` | Seconds to hold before requesting restart; 1–5. Host/single-player only. |
| `SCALE` | `1` | Scales the entire alert; 0.5–3. Try this first if everything looks too small. |
| `START_ENABLED` | `true` | Whether alerts start on at game launch. F8 (or `TOGGLE_KEY`) can change this for the current session without rewriting the file. While off, incident popups/sounds are muted but monitoring and event logging continue. |
| `SOUND` | `false` | `true` attempts to play a sound for incidents. Requires a valid `SOUND_PATH`; visuals continue if playback fails. |
| `TRIGGERS` | See the switches below | Choose which incidents produce alerts. This is an object containing `true`/`false` switches, each with its own default. |

### Which incidents produce alerts

Look for the `TRIGGERS` block in your file. Each switch below goes inside its
braces and accepts `true` or `false`. Turning one off leaves the others alone;
leaving one out keeps its default. These are still early warnings, not a final
verdict on your rank.

| Field inside `TRIGGERS` | Default | What it watches |
|---|---|---|
| `CIVILIAN_KILLED` | `true` | Increases in recorded civilian kills. |
| `SUSPECT_KILLED` | `true` | Increases in recorded suspect kills, including justified kills. |
| `PLAYER_DIED` | `true` | Recorded deaths of human players. |
| `PENALTIES` | `true` | Newly recorded scoring penalties. |
| `OBJECTIVE_FAILED` | `true` | Entries in the game's mission-objective list entering a failed state; the mod does not separately filter required versus optional objectives. |
| `CIVILIAN_INJURED` | `false` | Recorded civilian injuries. Their S-rank effect is unverified, so these are labeled warnings. |
| `REQUIRED_BONUS_LOST` | `false` | Required bonuses becoming unavailable. Their S-rank effect is also unverified. |

## Advanced / visual tuning

You probably don't need this section unless you want to customize the look in
detail or troubleshoot something. The defaults are a starting point you can come
back to if a change doesn't look right.

All ranges include both endpoints. Fractions are fine unless a row says "whole
number." Sizes and spacing use Unreal UI units, so game or Windows scaling can
make them look larger or smaller than the same number of pixels. Staying within
the limits prevents bad inputs, but some combinations may still crowd your screen.

### Input timing and notice duration

These change how quickly taps, scoring checks and status notices behave. You can
usually leave them as they are.

| Field | Default | What it does and allowed values |
|---|---|---|
| `DISMISS_TAP_SECONDS` | `0.3` | Longest press counted as a dismiss tap; 0.1–0.5 seconds. Longer interrupted holds leave the alert visible. |
| `POLL_MS` | `350` | Time between scoring checks, in milliseconds; whole number 100–5000. Larger values reduce checks but delay alerts. |
| `ALERT_MS` | `5500` | Lifetime of startup/status notices in milliseconds; whole number 1000–30000. Incident alerts remain until dismissed or the mission changes. |

### Alert placement and size

If changing `SCALE` wasn't enough, these let you move the alert and adjust its spacing.

| Field | Default | What it does and allowed values |
|---|---|---|
| `ANCHOR` | `"AboveCrosshair"` | Placement preset: `AboveCrosshair`, `TopCenter`, `Center`, `TopLeft`, `TopRight`, `BottomLeft` or `BottomRight`. Use the exact spelling. |
| `CENTER_OFFSET` | `140` | Distance above screen center when using `AboveCrosshair`; 0–500. |
| `WIDTH` | `420` | Width available to headline/context text; 200–600. Long text may wrap. |
| `MARGIN` | `24` | Space around the alert's anchor; 0–500. |
| `CONTEXT_GAP` | `3` | Additional space before context text; 0–12. |
| `DIVIDER_WIDTH` | `64` | Width of the short line between headline and context; 0–600. Zero hides its width. |
| `DIVIDER_TOP_GAP` | `10` | Space above that line; 0–100. |
| `DIVIDER_BOTTOM_GAP` | `6` | Space below that line; 0–100. |
| `DIVIDER_OPACITY` | `0.3` | Visibility of the divider; 0–1, where 0 is invisible and 1 is fully opaque. |

### Key tiles and progress fill

These control the two key tiles and the colored fill that appears during a hold.

| Field | Default | What it does and allowed values |
|---|---|---|
| `SHOW_HOLD_PROGRESS` | `true` | Show the restart tile filling while you hold. `false` hides the fill, not the restart action. |
| `KEY_TILE_SIZE` | `40` | Side length of each square key tile; 16–96. Very small tiles may not fit their key labels. |
| `KEY_GLYPH_SIZE` | `16` | Font size of the key name inside each tile; whole number 8–32. |
| `KEY_LABEL_SIZE` | `13` | Font size of DISMISS and HOLD TO RESTART below the tiles; whole number 8–24. |
| `KEY_GROUP_WIDTH` | `170` | Space reserved for each tile/label group; 60–400. Too little room can crowd labels. |
| `KEY_OUTLINE_OPACITY` | `1` | Visibility of the light tile outline; 0–1. The dark backing strokes remain. |
| `KEY_FILL_OPACITY` | `1` | Visibility of the colored progress fill; 0–1. |
| `KEY_FILL_SATURATION` | `0.95` | How vivid the fill is; 0–1. Zero removes its color, while 1 uses full saturation. |
| `KEY_FILL_BRIGHTNESS` | `1` | Fill brightness; 0–1. Zero makes the fill black. |
| `KEY_EMPTY_COLOR` | `"080808"` | Color of the unfilled tile background. Use six hexadecimal digits as described below. |

### Fonts, shadows and text colors

For font faces, use a name available in the selected font, such as `Regular` or
`Bold`. It must be nonempty, no more than 64 characters, and contain no control
characters (such as tabs or line breaks). The loader can check the spelling format,
but it can't tell whether Unreal has loaded that font. Asset paths start with `/`,
allow up to 1024 characters, and also can't contain control characters.

Colors need **exactly six hexadecimal digits**, without a `#`, inside quotes.
For example, `"FF0000"` is red, `"000000"` is black, and `"FFFFFF"` is white.
Uppercase and lowercase both work. Where an opacity setting is available, use
that separately to make the color more transparent.

| Field | Default | What it does and allowed values |
|---|---|---|
| `HEADLINE_SIZE` | `18` | Main headline font size; whole number 10–24. |
| `CONTEXT_SIZE` | `13` | Supporting detail font size; whole number 9–20. |
| `CONTROL_SIZE` | `18` | Font size of the optional diagnostic alphabet specimen; whole number 10–24. Normal controls use the key glyph/label sizes instead. |
| `FONT_HEADLINE_FACE` | `"Bold"` | Face used for the headline. |
| `SMALL_FONT_PATH` | `"/Engine/EngineFonts/Roboto.Roboto"` | Font asset for context, controls and specimens. If unavailable, the renderer logs a fallback to its default font. |
| `SMALL_FONT_FACE` | `"Regular"` | Face for context, action labels and specimens; key glyphs use Bold. |
| `SMALL_FONT_TRACKING` | `25` | Extra character spacing in Unreal's font tracking units; whole number -100–200. Negative values tighten spacing. |
| `INHERIT_HUD_FONT` | `true` | Borrow the game's HUD font for the headline when available. Small text still uses `SMALL_FONT_PATH`. |
| `FONT_PROBE` | `false` | Show the diagnostic alphabet specimen after HUD attachment, until dismissed or replaced by an incident. Leave off for ordinary play. |
| `TEXT_OUTLINE_SIZE` | `2` | Thickness of text outlines; whole number 0–4. Zero disables the outlines. |
| `TEXT_OUTLINE_COLOR` | `"000000"` | Color of text outlines and the dark tile backing strokes. Six hex digits. |
| `SHADOW_OPACITY` | `1` | Text-shadow visibility; 0–1. |
| `SHADOW_OFFSET` | `2` | Text-shadow offset down and right; 0–3. |
| `HEADLINE_COLOR` | `"E6E9E7"` | Initial headline color before a notice supplies its severity color. Six hex digits. |
| `CONTEXT_COLOR` | `"C1C6C5"` | Context, labels, key glyphs, divider and light outline color. Six hex digits. |
| `CRITICAL_COLOR` | `"C58A80"` | Incident headline color; the progress fill derives its hue from this. Six hex digits. |
| `WARNING_COLOR` | `"C7AE78"` | Warning headline color and the basis for its fill. Six hex digits. |
| `INFO_COLOR` | `"E6E9E7"` | Startup/information headline color. Six hex digits. |

### Animation, sound and diagnostics

Sound takes a little extra setup: turning `SOUND` on isn't enough by itself. It
also needs a sound asset that the game has already loaded. The log options are
mostly useful when you're trying to understand why something isn't working.

| Field | Default | What it does and allowed values |
|---|---|---|
| `FADE_IN_MS` | `180` | Fade-in duration in milliseconds; whole number 0–10000 and no more than one third of `ALERT_MS`. Zero shows the alert immediately. |
| `FADE_OUT_MS` | `300` | Status-notice fade-out duration; same limits as fade-in. Incident alerts do not fade out automatically. |
| `ANIMATION_STEP_MS` | `30` | Time between fade animation steps; whole number 16–100 milliseconds. Does not change hold-input sampling. |
| `SOUND_PATH` | `""` | Empty to leave unconfigured, or a path starting with `/` to a sound asset already loaded by the game; at most 1024 characters, no control characters. Not a Windows audio-file path. |
| `VERBOSE` | `false` | Adds HUD-attachment and successful font-selection/readback details to the log. Font readback also appears when `FONT_PROBE` is on. |
| `DIAGNOSTICS` | `false` | Adds reflection/read-shape diagnostics for troubleshooting. Ordinary failures are logged even when off. |

## A few editing tips

JSON is fussy about punctuation, but you only need a few rules:

- Put double quotes around names and text, but not around numbers or `true`/`false`.
- Put a comma between fields, with no comma after the last one.
- Don't paste Lua assignments (`NAME = value`) or Lua comments (`-- comment`).
- Save as UTF-8 rather than UTF-16.

Here's a small, complete config you can use as a starting point. Every setting
left out will still use its default. The [worked example](config.example.json)
shows the full structure if you'd rather see everything together.

```json
{
  "ACTION_KEY": "F11",
  "RESTART_ENABLED": false,
  "SCALE": 1.25,
  "TRIGGERS": {
    "CIVILIAN_INJURED": true
  }
}
```

If you mistype a value, you haven't ruined the mod. That setting uses its default
and leaves a `config warning: FIELD_NAME` message in `ue4ss\UE4SS.log` to help you
find it. If the JSON itself is broken, the mod uses all defaults for that session.
It leaves your file alone so you can fix it. If it can't read the file or create
it on first run, it also logs the problem and carries on with defaults.

Those defaults keep restart off. An existing valid `"RESTART_ENABLED": true`
still works and survives updates, even if an older version generated it for you.
Set it to `false` to turn it off; the installer does not change existing settings.

Coming from an older version that kept settings in `main.lua`? Keep your old
script or the installer's backup, launch once to create JSON, then copy over your
custom values using JSON syntax. The mod won't import or run that old Lua code.
You only need to make this move once; later updates keep your JSON settings.
