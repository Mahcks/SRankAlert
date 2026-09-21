# SRankAlert

**A small warning that pops up mid-mission when something happens that can cost you an S rank in Ready or Not.**

Kill a civilian, lose a human teammate, trip a penalty, fail an objective: a short message appears just above your crosshair so you know right away, instead of finding out at the debrief screen. Version 0.5.1 (prepared for release; not yet published).

Two things to know up front:

- It's an early warning, not a judge. If it stays quiet, that does **not** promise you an S rank. It only watches for the things listed under [What you'll see](#what-youll-see).
- By default, it reads scoring data and shows alerts. An experimental mission-restart action is available only if you enable it in your settings; see [Controls](#controls).

## Why does this need UE4SS?

The game doesn't offer a way to ask "did the score just change?" from the outside. To see live scoring, a mod has to reach into the game while it runs.

That's what **UE4SS** does. It's a free, widely used tool that lets small scripts (written in a language called Lua) run inside Unreal Engine games and read what the game is doing. Think of it as the socket, and SRankAlert as one thing you plug into it.

This isn't unusual for Ready or Not. Other mods use it too, like [MissionObjectiveCounter](https://github.com/Nokama0/ReadyOrNot-MissionObjectiveCounter) (which this mod borrowed some techniques from, with thanks to Nokama) and [Weapon FOV ADS](https://www.nexusmods.com/readyornot/mods/8562). If you install one UE4SS mod, you've done the hard part for all of them.

If you get stuck on UE4SS itself, its [documentation](https://docs.ue4ss.com/installation-guide) is the best place to start. The wider UE4SS and Ready or Not modding community is also a good place to ask. Plenty of people there have already solved "UE4SS won't start" problems.

## Installing

The public repository is [Mahcks/SRankAlert](https://github.com/Mahcks/SRankAlert). Version 0.5.1 is being prepared for publication; its ZIP and a Nexus Mods listing link are pending. Once published, download `SRankAlert-0.5.1.zip` from [GitHub Releases](https://github.com/Mahcks/SRankAlert/releases).

There are two ways to install it: let a small **install script** do the copying and the `mods.txt` edit for you, or do everything by hand. Either way, you do steps 0 to 2 yourself, because the script doesn't install UE4SS.

Take your time. You're copying a few files and editing one line in a text file. Nothing here touches your saves, and every step can be undone (see [Uninstalling](#uninstalling)).

### Step 0: Close the game

Windows and the game don't like files changing underneath a running program. Close Ready or Not before you start.

### Step 1: Find your game folder

You'll be working inside the folder where Ready or Not is installed.

- **Steam:** right-click Ready or Not in your library, then **Manage**, then **Browse local files**. A folder opens. It contains a folder named `ReadyOrNot`.
- **Epic or elsewhere:** open the folder you installed the game into. You're looking for the same thing, a folder containing `ReadyOrNot`.

Inside it, go to `ReadyOrNot\Binaries\Win64\`. This is where the game's program lives, and where UE4SS goes too. The rest of this guide calls it **Win64**.

### Step 2: Install UE4SS (the experimental build)

Download the **experimental** build from the [experimental-latest release page](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest). Download the main UE4SS `.zip` (skip any extra "dev" or "custom game configs" downloads the page lists), and unzip its contents into **Win64**.

**Why experimental, and not the normal "stable" release?**

SRankAlert draws its message on the game's HUD (the on-screen display), and it needs UE4SS to tell it when that HUD appears. The stable release has trouble with that. The mod this one learned from ran into the same problem. Experimental also has fixes for some crashes that older builds had.

**How to tell which one you have.** This is the confusing part: **both builds report the same version number** (v3.0.1 Beta), so the version won't tell you. Look at your Win64 folder instead:

| What you see in Win64 | What it means |
|---|---|
| A folder named `ue4ss`, with `UE4SS.dll` inside it | Experimental. This is what you want. |
| `UE4SS.dll` sitting loose in Win64 itself | Stable. Replace it with the experimental download. |

This layout check cannot tell you the build's age or prove that UE4SS works. If you're unsure, close the game, keep a backup of your existing UE4SS settings and mods, and follow the linked UE4SS installation guide before replacing its files.

When you're done, Win64 should contain `dwmapi.dll` and a `ue4ss` folder (among the game's own files).

### Easy way for steps 3 and 4: the install script (optional)

The ZIP includes a script called `Install.ps1`. It's an annotated PowerShell program (PowerShell is the command-line tool built into Windows) that does steps 3 and 4 for you. If you'd rather see exactly what changes, skip to step 3 and do it by hand. Both routes end up in the same place.

1. Close the game.
2. Extract the **whole** ZIP somewhere easy, like your Desktop. Keep `Install.ps1` next to the `Scripts` folder. The script looks for the mod files beside itself.
3. Right-click `Install.ps1` and choose **Run with PowerShell**. (On Windows 11 you may need to click **Show more options** first.)
4. Follow the messages. The window stays open at the end so you can read the summary.

Here's what it does:

- **Finds your game.** It looks for a Steam install. If it can't find one, it asks you to paste the game folder (the one that contains `ReadyOrNot`).
- **Checks UE4SS first.** If UE4SS is missing, or it's the stable layout, it stops with a message and the download link. It changes nothing in that case. It never downloads UE4SS for you.
- **Refuses to run while the game is open.**
- **Copies the mod files** into `Mods\SRankAlert`.
- **Adds `SRankAlert : 1` to `mods.txt`,** above `Keybinds`.
- **Asks before replacing anything.** If a file already exists, it asks you to type `YES` before replacing it. It saves a backup copy first, next to the original, with `.SRankAlert-backup-` and a long random code added to the end of the name.
- **Preserves your settings.** They live in `Mods\SRankAlert\config.json` and are never touched by an update. The mod creates this file with defaults on first launch if it is missing.
- **Never asks for administrator access.** If Windows denies it access to your game folder, it tells you so.

**If Windows blocks the script** with a message about "execution policy": that's PowerShell's built-in rule about which scripts may run. You can get past it for this one run without changing any Windows settings. Open PowerShell and run this, with the path changed to wherever you extracted the ZIP:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\SRankAlert\Install.ps1"
```

That relaxes the rule only for that one PowerShell window. It doesn't change your saved policy or give the script administrator rights. As with any script you download, feel free to open `Install.ps1` in Notepad and read it first. Only run a copy you trust.

Once it says **Installation complete**, jump to step 5.

### Step 3: Copy in this mod (by hand)

Unzip SRankAlert so you have a folder called `SRankAlert`, and put that folder inside:

```
ReadyOrNot\Binaries\Win64\ue4ss\Mods\
```

Then check the result. This exact file should exist:

```
ReadyOrNot\Binaries\Win64\ue4ss\Mods\SRankAlert\Scripts\main.lua
```

The classic mistake is a doubled-up folder, like `Mods\SRankAlert\SRankAlert\Scripts\main.lua`. If yours looks like that, move the inner folder up a level.

### Step 4: Tell UE4SS to load it (`mods.txt`, by hand)

This package uses UE4SS's plain text `mods.txt` list to enable the mod. In that list, `: 1` means on and `: 0` means off. Adding a line is how you say "yes, this one."

1. Open `ReadyOrNot\Binaries\Win64\ue4ss\Mods\mods.txt` in Notepad.
2. Add this line **above** the `Keybinds : 1` line:

   ```
   SRankAlert : 1
   ```
3. Save the file.

Why above `Keybinds`? UE4SS's own built-in keybinds mod is meant to stay last on the list, so new mods go above it. Your file will end up looking something like this (yours may list different mods):

```
CheatManagerEnablerMod : 0
ConsoleCommandsMod : 0
SRankAlert : 1
Keybinds : 1
```

### Step 5: Start the game

Launch Ready or Not and load into a mission. You don't have to press anything to turn the mod on. A few seconds after the mission starts, you should see a short message above your crosshair saying **S-RANK ALERTS ACTIVE**. That's the mod saying hello. (If it can't read some of the mission's data, you'll see a yellow **S-RANK CHECK INCOMPLETE** instead.) See [Did it work?](#did-it-work) if you see neither.

## Did it work?

The easiest check is in-game: a brief **S-RANK ALERTS ACTIVE** message shortly after a mission starts.

For a proper check, open `ReadyOrNot\Binaries\Win64\ue4ss\UE4SS.log` in Notepad (UE4SS starts a fresh one each time you launch the game) and search for `[SRankAlert]`. A healthy start looks roughly like this:

```
[SRankAlert] loaded v0.5.1; ... F9 tap dismiss / restart disabled
[SRankAlert] game-thread route: ExecuteInGameThreadWithDelay
[SRankAlert] character HUD observed; waiting for widget tree
[SRankAlert] toast attached after 250ms; poll=350ms
[SRankAlert] configured core data readable; monitoring active (no final-rank guarantee)
```

(The timing number will differ. The `toast attached` line only appears once you're in a mission.)

**If nothing shows up, check these in order:**

1. **No `[SRankAlert]` lines at all.** UE4SS never loaded the mod. Recheck step 4 (is the line in `mods.txt`, spelled exactly `SRankAlert : 1`?) and step 3 (is `main.lua` in the right place?). If `UE4SS.log` doesn't exist at all, UE4SS itself isn't running. Recheck step 2.
2. **`game-thread route: NONE (disabled)`.** Your UE4SS is too old or the wrong build. Reinstall the experimental one.
3. **`attach abandoned after 15000ms`.** The mod saw a HUD but couldn't finish building the alert. Read the reason on that log line: the widget tree, a required UI class or another construction step may be unavailable. Recheck the experimental UE4SS requirement (step 2), and include the full line in a bug report.
4. **A yellow S-RANK CHECK INCOMPLETE message in-game.** The mod is running but couldn't read some of the mission's data. Alerts may be missing for whatever couldn't be read. The log line starting `coverage UNKNOWN` says what.
5. **F9 seems to do nothing.** F9 only does something **while an alert is on screen**. With nothing showing, there's nothing to dismiss. If an alert is on screen and F9 still does nothing, check whether another mod or a custom key binding uses F9. You can pick a different key ([Configuration](#configuration)).

## What you'll see

An alert is short, uppercase text just above your crosshair. It has a headline (like **CIVILIAN KILLED**), a line of detail underneath if there is any, and a dismiss key tile. A second tile appears for incident alerts when host restart is available.

The mod raises an alert when the game records any of these:

- A **civilian killed**.
- A **suspect killed**. The mod only counts. It can't tell a justified shooting from an unjustified one, so this alert can appear for a perfectly legitimate kill.
- A **human player death** (bots and AI officers aren't counted). This alert shows even if the mod is unsure about scoring rules, since a death is a death.
- A **penalty recorded**. The headline is the penalty's own name, such as a team kill.
- An **objective failed**.

Two more alerts exist but are **off by default**, because I couldn't confirm they affect S rank: a civilian being **injured**, and a required **bonus** becoming unavailable. Their alerts say WARNING. You can turn them on in [Configuration](#configuration).

Some things worth knowing:

- **Incident alerts don't fade on their own.** Dismiss with F9, or they clear when you leave the mission or the game replaces the character HUD. If more incidents happen while one is showing, the same alert updates to say **MULTIPLE INCIDENTS** with a count of alert groups, rather than stacking up.
- **Startup and status notices** (like S-RANK ALERTS ACTIVE) disappear by themselves after about five and a half seconds.
- **Missing data is reported as missing.** If the mod can't read something, it says so instead of assuming zero.
- **Scoring rules have to be readable and marked official.** Otherwise, rank-related incident alerts are suppressed; human player deaths can still be reported. The incomplete-check notice explains that coverage is limited.
- **Some incidents may already be recorded when monitoring starts.** Those say "Already recorded; timing unknown" rather than pretending they just happened.
- **Full details go to `UE4SS.log`.** The on-screen text is deliberately brief.

## Controls

**F8 toggles alerts off/on during a mission**, even when no alert is visible.
You'll see a brief confirmation. Turning alerts off clears the current alert,
cancels any restart hold and mutes future incident popups and sounds. Monitoring
and event logging continue, so already observed incidents don't replay on enable.

The toggle lasts for the current game session, including mission changes. Your
next launch uses `START_ENABLED` again; pressing F8 does not edit `config.json`.
It requires an attached character HUD and does not work in menus or spectator view.

F8 is unassigned in the saved game bindings checked for development, but some
other mods use it, including [Universal Weapon P.O.I Crosshair](https://www.nexusmods.com/readyornot/mods/8681).
Change `"TOGGLE_KEY": "F8"` in `config.json` if needed. Use a different key from
`ACTION_KEY`; set `TOGGLE_KEY` to `""` if you want no toggle shortcut.

**F9 handles the current alert:**

**Restart is off by default.** If you choose to try this experimental feature,
set `"RESTART_ENABLED": true` in `config.json`. The hold actions below apply only
when you've enabled it. Without it, you get the dismiss tile alone.

| What you do | What happens |
|---|---|
| **Press F8** | Turns incident alerts off/on and shows a brief confirmation. |
| **Tap F9** (a quick press and release, under about 0.3 seconds) | Dismisses the alert. Future alerts still appear. |
| **Hold F9 for 3 seconds** during an incident alert | Asks the game to **restart the mission**. The restart icon fills up while you hold. Single-player and co-op **host** only. |
| **Hold F9, then let go early** | Cancels the restart. The alert stays up and you can try again. |

When enabled, restart is **always manual**. The mod never restarts anything by itself. With the default hold duration, it takes a deliberate three-second hold, and:

- Holding F9 *before* an alert appears can't trigger it. Let go of F9 first, then hold it again.
- If you're a client in someone else's co-op game, you only get dismiss. The restart icon doesn't show.
- **Restart is experimental.** It calls the game's own restart function, which I've tested with a simulator but **not yet in a real mission**. Treat it as "should work" rather than "does work." Don't try it during a run you care about.
- Leave `"RESTART_ENABLED": false` to keep restart off, or set it back to `false` after testing.

Both keys are editable, and there are no modifier settings. To stop loading the
mod entirely, disable it in `mods.txt` (see [Uninstalling](#uninstalling)).

## Configuration

There's no in-game settings menu yet. Your settings live in `Mods\SRankAlert\config.json`, beside the `Scripts` folder. Start the game once and the mod creates this file with all defaults if it is missing.

To change something, close the game, open `config.json` in Notepad, edit and save it as UTF-8, then restart. JSON uses double quotes around names and text, plain numbers, and lowercase `true`/`false`. For example, change `"RESTART_ENABLED": true` to `"RESTART_ENABLED": false` to remove the restart action. Keep commas between fields, with no comma after the final field.

See **[CONFIG.md](CONFIG.md)** for every field, its default, allowed range and a plain-language explanation. `ACTION_KEY`, `SCALE`, `WIDTH`, `CENTER_OFFSET` and the switches inside `TRIGGERS` are good places to start.

**Your settings survive updates.** Neither the installer nor the release ZIP replaces `config.json`. An older config can omit newly added settings: those fields use the current defaults. Invalid values fall back to their defaults with a `config warning: FIELD_NAME` message in `UE4SS.log`; the file stays untouched so you can fix it. Broken JSON uses all defaults for that session instead of preventing the mod from loading.

Missing or invalid `RESTART_ENABLED` values, unreadable files and broken JSON leave
restart **off**. An existing valid `"RESTART_ENABLED": true` remains enabled through
updates, including files generated by older versions that defaulted to true. Set
it to `false` yourself if you want to turn it off; updates do not rewrite your choices.

If you customized an older version's `main.lua`, transfer those values once from your old script or installer backup into the generated JSON. Old Lua code is not automatically imported. Future updates no longer require this step.

## Known limitations

I'd rather you hear these from me:

- **It's a young mod with little real-world playtime.** The core detection worked in-game on an early version and hasn't changed since. But I've only played it a bit, in a few situations.
- **Visual verification is partial.** The Roboto alphabet specimen and the solid, progressing fill were confirmed by the tester in-game. The latest bottom-edge fill correction still needs a near-full screenshot. Current alert legibility, HUD overlap and bright/dark-scene comparisons also remain pending; automated layout checks cannot establish those.
- **Resolutions are checked on paper only.** I checked layout math for 1920x1080, 2560x1440 and 3440x1440 at a few UI scales, but not by looking at the game at each one. Unusual aspect ratios haven't been tested. If it looks off for you, `SCALE`, `WIDTH` and `CENTER_OFFSET` can help, and please report it.
- **Restart is unverified in a real game** (see [Controls](#controls)).
- **The detail on an alert is basic.** You get the headline, and sometimes a player or objective name or a count. When several things happen at once, you get the first related event and a "+N more", not the full list. It can't tell you *which* civilian, or who shot them.
- **The mod estimates, it doesn't know.** There's no official "you've lost S rank" signal to read, so the mod applies the standard rules to the numbers the game exposes. A quiet screen isn't a guarantee, and edge cases (special scripted exceptions, for instance) may be wrong.
- **Co-op:** every player who wants alerts needs their own install. The mod only sees data the game shares with each player. Spectator view isn't supported.
- **Other mods and game updates** can change what the mod can read.
- **Turning off a trigger only stops its alerts.** The mod still reads the underlying data, so missing data for that category may still produce a coverage warning. Missing optional bonus/injury data is logged when detected, but is not comprehensively represented in the on-screen coverage notice.
- **Very quick taps can be missed.** Input is sampled every 50 milliseconds, so a press and release entirely between samples may not dismiss the alert.
- **It has crashed the game once.** The early version crashed in testing. That was traced to one specific call and removed in 0.1.1, but a fix for one crash isn't proof there are no others. If it happens to you, please report it.
- **If you reload mods mid-mission** with a UE4SS hot reload, the mod forgets what it already told you. Restart the game if you want a clean state.

The mod makes no direct save-file writes or scoring edits. If you enable restart
and deliberately request one, the game handles the restart and any resulting
score resets or save behavior; those side effects have not been verified in a live mission.

## Reporting a bug

Bugs and problems go in [GitHub Issues](https://github.com/Mahcks/SRankAlert/issues). Open a new issue and include the details below so I can reproduce it.

1. **What happened** and what you expected.
2. **`UE4SS.log`.** Copy it before relaunching the game, since it's overwritten on the next start. It's at `ReadyOrNot\Binaries\Win64\ue4ss\UE4SS.log`. At minimum, send every line containing `[SRankAlert]`, plus the lines around the problem. (Turning on `VERBOSE` first helps.) **Check it for player names before posting**, since alerts can log them.
3. **Game version or build number**, and whether you play on Steam or another store.
4. **UE4SS build.** Experimental or stable, and which folder layout you have (see step 2).
5. **Solo, co-op host, or co-op client.**
6. **Mission, screen resolution, and UI scale** (especially for anything visual).
7. **Other mods you have installed**, and any custom key bindings.
8. **For a crash**, the newest folder in `%LOCALAPPDATA%\ReadyOrNot\Saved\Crashes`. The file `CrashContext.runtime-xml` inside it is the useful one.

A screenshot helps a lot for anything visual.

## Uninstalling

1. Close the game.
2. Open `ue4ss\Mods\mods.txt` and delete the `SRankAlert : 1` line. (Changing `1` to `0` also works if you might come back.)
3. Delete the `ue4ss\Mods\SRankAlert` folder.

That removes the mod. It made no direct save-file writes or scoring edits to undo.
Uninstalling does not undo a mission restart or anything the game saved afterward.

UE4SS stays installed for any other mods you use. If you want it gone too, delete `dwmapi.dll` and the `ue4ss` folder from Win64. (Only do this if no other mod needs UE4SS.)

## Licence and credits

MIT licence. Some of the techniques for finding the HUD, scheduling work safely and reading scoring data are adapted from Nokama's [MissionObjectiveCounter](https://github.com/Nokama0/ReadyOrNot-MissionObjectiveCounter), and Nokama's licence notice is kept as required. No game assets, SDK files or UE4SS files are included in this mod.

See [CHANGELOG.md](CHANGELOG.md) for version history and [THIRD-PARTY.md](THIRD-PARTY.md) for the included JSON library's licence and source.

## Development and CI

On Windows, install Python 3.10 or newer and run these commands from the project folder:

```powershell
python -m pip install -r tools/requirements-test.txt
python tools/test.py
powershell -NoProfile -ExecutionPolicy Bypass -File tests/deploy_spec.ps1
python tests/package_spec.py
```

The tests use simulated game objects and isolated folders; they don't need the game
or change your installed mods. The package check builds `dist/SRankAlert-0.5.1.zip`
and checks its contents and reproducibility. `python tools/package.py` builds the
ZIP by itself. Build output stays out of Git.

[GitHub Actions](.github/workflows/ci.yml) runs the same checks on Windows for pushes
and pull requests, and can also be started from the Actions tab. A successful run
keeps the tested ZIP as a downloadable artifact for 14 days. These builds aren't
automatically published as releases. In-game appearance and behavior still need
live checks; CI can't establish those.

Release names use `vMAJOR.MINOR.PATCH` tags and `SRankAlert-MAJOR.MINOR.PATCH.zip`
downloads. For this prepared release, use tag `v0.5.1`, title **SRankAlert v0.5.1**,
and `SRankAlert-0.5.1.zip`. The package test checks that the runtime log, README,
config guide, changelog and ZIP version agree. Create the tag and GitHub release
only after the pending live checks and release decisions are resolved.
