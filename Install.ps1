# ===== Before you start =====
# Keep this script beside the extracted Scripts folder and README.md.
# This installs only SRankAlert. It does not download UE4SS or elevate itself.
# Close Ready or Not first. Press Ctrl+C whenever you want to cancel.

# Optionally supply the outer game folder; NoPause is useful when running from a terminal.
param([string]$GameRoot, [switch]$NoPause)

# Treat failures as stopping points instead of continuing with an incomplete installation.
$ErrorActionPreference = 'Stop'
# Keep the official prerequisite link ready for users who need to install or replace UE4SS.
$download = 'https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest'
# Record completed work so even a failed installation ends with an accurate summary.
$changes = [System.Collections.Generic.List[string]]::new()
# Collect tasks the installer could not finish, such as an edit the user declined.
$manual = [System.Collections.Generic.List[string]]::new()
# Only mark the installation finished after the copy and enabling steps have both run.
$finished = $false

# ===== Helpers used by the walkthrough =====

# Check a candidate game folder before trusting a Steam result or a pasted path.
function Test-GameFolder([string]$Folder) {
    # Reject empty paths without passing them to filesystem commands.
    if ([string]::IsNullOrWhiteSpace($Folder)) { return $false }
    # Steam opens the outer folder; Ready or Not keeps its binaries underneath this relative path.
    return (Test-Path -LiteralPath (Join-Path $Folder 'ReadyOrNot\Binaries\Win64') -PathType Container)
}

# Read Steam's registry entries and library files without changing any Steam settings.
function Find-SteamGames {
    # Explain why the script is about to read Windows and Steam configuration.
    Write-Host 'Looking for your Ready or Not install via Steam...'
    # Steam can register its install folder either for this user or for the whole computer.
    $locations = @(
        @{ Path = 'HKCU:\Software\Valve\Steam'; Name = 'SteamPath' },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam'; Name = 'InstallPath' },
        @{ Path = 'HKLM:\SOFTWARE\Valve\Steam'; Name = 'InstallPath' }
    )
    # Gather every Steam location because not all computers use the same registry entry.
    $steamFolders = @()
    # Try each known registry entry independently.
    foreach ($location in $locations) {
        # Missing entries are normal and do not require an error or administrator access.
        $entry = Get-ItemProperty -LiteralPath $location.Path -Name $location.Name -ErrorAction SilentlyContinue
        # Add only entries that actually exist.
        if ($entry) { $steamFolders += $entry.($location.Name) }
    }
    # Also check the usual Steam folder if the registry was incomplete.
    if (${env:ProgramFiles(x86)}) { $steamFolders += Join-Path ${env:ProgramFiles(x86)} 'Steam' }
    # Steam's own folder is also a game library, even without a library list.
    $libraries = @($steamFolders)
    # Windows paths ignore letter case; merge differently capitalized copies of the same Steam path.
    foreach ($folder in @($steamFolders | Sort-Object -Unique)) {
        # This text file tells Steam about libraries on other drives.
        $vdf = Join-Path $folder 'steamapps\libraryfolders.vdf'
        # A missing library list still leaves the default library available for checking.
        if (-not (Test-Path -LiteralPath $vdf -PathType Leaf)) { continue }
        # If a library list cannot be read, continue toward the manual path prompt.
        try {
            # Read the library settings as text, without modifying the file.
            $text = [System.IO.File]::ReadAllText($vdf)
            # Recognize both current path entries and older numbered library entries.
            foreach ($match in [regex]::Matches($text, '"(?:path|\d+)"\s+"([^"]+)"')) {
                # Steam doubles backslashes in this file; restore normal Windows paths.
                $libraries += $match.Groups[1].Value.Replace('\\', '\')
            }
        } catch {
            # Explain a missed library instead of hiding an auto-detection problem.
            Write-Host "Could not read $vdf. You can paste the game folder if needed."
        }
    }
    # Search each library once, ignoring path capitalization, including libraries on other drives.
    foreach ($library in @($libraries | Sort-Object -Unique)) {
        # This app ID identifies Ready or Not's installation record in Steam.
        $manifest = Join-Path $library 'steamapps\appmanifest_1144200.acf'
        # Keep the standard folder as a fallback when no installation record is available.
        $candidate = Join-Path $library 'steamapps\common\Ready Or Not'
        # Use Steam's recorded folder name when possible.
        if (Test-Path -LiteralPath $manifest -PathType Leaf) {
            # A locked or unreadable record should not prevent trying other game locations.
            try {
                # Extract only the installed folder name from the game's record.
                if ([System.IO.File]::ReadAllText($manifest) -match '"installdir"\s+"([^"\r\n]+)"') {
                    # Combine the library root with the actual game folder name.
                    $candidate = Join-Path $library ('steamapps\common\' + $Matches[1])
                }
            } catch {
                # Tell the user why the usual folder is being tried instead.
                Write-Host "Could not read $manifest; checking the usual folder."
            }
        }
        # Return only folders with the expected game layout.
        if (Test-GameFolder $candidate) { $candidate }
    }
}

# Make every overwrite a deliberate choice; an empty answer always means no.
function Confirm-Change([string]$Message) {
    # Describe the proposed change before asking for permission.
    Write-Host $Message
    # Accept only Y or YES, avoiding accidental consent from simply pressing Enter.
    return ((Read-Host 'Type YES to approve, or press Enter to leave it alone') -match '^(?i:y|yes)$')
}

# Save the original of an approved replacement so settings can be recovered later.
function Backup-File([string]$Path) {
    # A unique name ensures a previous backup is never silently replaced.
    $backup = $Path + '.SRankAlert-backup-' + [guid]::NewGuid().ToString('N')
    # Show where the original is about to be saved.
    Write-Host "Backing up $Path to $backup"
    # The false setting refuses replacement if that backup name already exists.
    [System.IO.File]::Copy($Path, $backup, $false)
    # Keep the backup path in the summary even if the next step fails.
    $changes.Add("Original saved: $backup")
}

# Catch installation problems and always display a readable summary afterward.
try {
    # ===== Step 1: Finding your game install =====

    # Explain the script's scope before reading or writing installation files.
    Write-Host 'SRankAlert guided installer. Close Ready or Not first. Ctrl+C cancels.'
    # Set expectations about the separate third-party prerequisite.
    Write-Host 'This copies this mod and enables it in mods.txt. Experimental UE4SS must already be installed.'
    # Prefer Steam detection unless a caller explicitly supplied the game folder.
    if (-not $GameRoot) {
        # Merge case-only path differences so one installation is not mistaken for several copies.
        $found = @(Find-SteamGames | Sort-Object -Unique)
        # A single match can be used for the following read-only prerequisite checks.
        if ($found.Count -eq 1) { $GameRoot = $found[0] }
        # Show all matches when a choice is needed; the path prompt below makes that choice.
        elseif ($found.Count -gt 1) {
            # Explain why the installer cannot choose automatically.
            Write-Host 'Several installs found. Paste the one you play at the prompt below:'
            # Display full paths so the user can copy the correct one.
            $found | ForEach-Object { Write-Host "  $_" }
        }
    }
    # Ask again for invalid paths, stopping when the user cancels rather than guessing.
    while (-not (Test-GameFolder $GameRoot)) {
        # Give a familiar way to find the folder without knowing Steam's disk layout.
        Write-Host 'In Steam: right-click Ready or Not > Manage > Browse local files.'
        # Accept pasted paths with surrounding double quotes, as copied by Windows Explorer.
        $GameRoot = (Read-Host 'Paste that outer game folder path, or press Enter to cancel').Trim().Trim('"')
        # Cancellation happens before any installation writes.
        if (-not $GameRoot) { throw 'Cancelled: no game folder selected.' }
        # Explain what is missing when the folder does not match the game layout.
        if (-not (Test-GameFolder $GameRoot)) { Write-Host 'That folder does not contain ReadyOrNot\Binaries\Win64. Please try again.' }
    }
    # Resolve a full filesystem path so all later messages identify the exact installation.
    $GameRoot = (Resolve-Path -LiteralPath $GameRoot).ProviderPath
    # Display the selected game before taking further action.
    Write-Host "Game folder: $GameRoot"
    # Calculate the folder where the game loads UE4SS.
    $win64 = Join-Path $GameRoot 'ReadyOrNot\Binaries\Win64'

    # ===== Step 2: Checking experimental UE4SS =====

    # Announce the prerequisite check before inspecting its files.
    Write-Host 'Checking whether experimental UE4SS is installed...'
    # Experimental UE4SS uses a subfolder under Win64.
    $ue4ss = Join-Path $win64 'ue4ss'
    # A loose DLL indicates stable, including a potentially mixed stable/experimental installation.
    if (Test-Path -LiteralPath (Join-Path $win64 'UE4SS.dll')) {
        # Explain the incompatibility and stop without deleting or replacing either build.
        throw "Stable UE4SS layout detected (possibly mixed with experimental). This mod needs experimental UE4SS because stable does not trigger the HUD callbacks needed to display alerts. Follow the experimental installation instructions and rerun: $download"
    }
    # Missing UE4SS is a prerequisite problem, not permission to install it automatically.
    if (-not (Test-Path -LiteralPath $ue4ss -PathType Container)) {
        # Provide the official link and stop before creating any mod files.
        throw "UE4SS is not installed in the expected location. Install experimental UE4SS first, then rerun: $download"
    }
    # Locate the existing experimental loader's mod directory.
    $mods = Join-Path $ue4ss 'Mods'
    # Refuse an empty or incomplete ue4ss folder instead of treating it as a working prerequisite.
    if (-not (Test-Path -LiteralPath (Join-Path $ue4ss 'UE4SS.dll') -PathType Leaf) -or
        -not (Test-Path -LiteralPath $mods -PathType Container)) {
        # Explain the missing pieces and where to obtain a complete installation.
        throw "The ue4ss folder exists, but UE4SS.dll or Mods is missing. Finish installing experimental UE4SS first: $download"
    }
    # A folder layout cannot establish the exact build number or age; say so plainly.
    Write-Host 'Experimental folder layout found. This does not prove its build date; use a recent official experimental download.'
    # Avoid replacing Lua files while a running game could reload only part of the mod.
    if (Get-Process -Name 'ReadyOrNot*' -ErrorAction SilentlyContinue) { throw 'Close Ready or Not, then rerun this installer.' }

    # ===== Step 3: Reviewing files before copying =====

    # Use the exact mod name so it matches both the folder and the mods.txt entry.
    $destination = Join-Path $mods 'SRankAlert'
    # Show the destination before asking about any replacements.
    Write-Host "Preparing to copy this mod into: $destination"
    # Settings belong to the player, not this package; never copy or replace config.json.
    Write-Host 'Your settings in config.json are left untouched. The mod creates it on first launch if missing.'
    # List only runtime modules and documentation, preserving the Scripts subfolder.
    $files = @('Scripts\main.lua', 'Scripts\controls.lua', 'Scripts\diff.lua', 'Scripts\presentation.lua',
        'Scripts\queue.lua', 'Scripts\source.lua', 'Scripts\toast.lua', 'Scripts\sra_config.lua',
        'Scripts\sra_dkjson.lua', 'LICENSE', 'README.md', 'CHANGELOG.md', 'CONFIG.md', 'config.example.json', 'THIRD-PARTY.md')
    # Plan all copies before writing so declining a replacement does not create a partial upgrade.
    $copies = @()
    # Review every file that this package needs to install.
    foreach ($file in $files) {
        # Find packaged files relative to this script, not the terminal's current working folder.
        $source = Join-Path $PSScriptRoot $file
        # Preserve the exact relative path under Mods\SRankAlert.
        $target = Join-Path $destination $file
        # An incomplete extraction should stop before any files are copied.
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing package file: $source. Extract the whole mod ZIP and try again." }
        # Save a fingerprint to verify that the packaged file does not change during installation.
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        # A missing destination has no previous contents or replacement approval.
        $targetHash = $null
        # Inspect an existing target rather than silently replacing it.
        if (Test-Path -LiteralPath $target) {
            # Do not remove a directory that unexpectedly occupies a required file path.
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "A folder blocks this file: $target. Resolve it manually and rerun." }
            # Compare contents so an identical file can be left alone without asking for replacement.
            $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
            # Skip files already matching this package, including a script run from the installed mod.
            if ($targetHash -eq $sourceHash) {
                # Explain the skip immediately so the user knows it was intentional.
                Write-Host "Already identical; leaving alone: $target"
                # Include unchanged files in the final report.
                $changes.Add("Already identical; left alone: $target")
                # Continue reviewing the remaining package files.
                continue
            }
            # Describe the exact file being replaced; settings live separately in config.json.
            $replacementMessage = "File exists: $target. Back it up and replace it with the packaged version?"
            # Require consent for this specific replacement before adding it to the copy plan.
            if (-not (Confirm-Change $replacementMessage)) {
                # Stop before copying any part of the upgrade if the user declines a replacement.
                throw 'Replacement declined. No mod files have been copied. Review your existing files and rerun when ready.'
            }
        }
        # Retain the reviewed fingerprints for a last-minute check immediately before copying.
        $copies += [pscustomobject]@{ Source = $source; Target = $target; SourceHash = $sourceHash; TargetHash = $targetHash }
    }

    # ===== Step 4: Copying files and preserving approved originals =====

    # Actual file operations check permissions; denied access is explained by the error handler below.
    Write-Host 'Copying reviewed files. Windows will check write permissions; this script never elevates itself.'
    # The game might have started during the prompts, so check again before writing.
    if (Get-Process -Name 'ReadyOrNot*' -ErrorAction SilentlyContinue) { throw 'Ready or Not started during review. Close it and rerun.' }
    # Perform only copies included in the reviewed plan.
    foreach ($copy in $copies) {
        # Do not install a package file changed after the user reviewed the copy plan.
        if ((Get-FileHash -LiteralPath $copy.Source -Algorithm SHA256).Hash -ne $copy.SourceHash) { throw "Package changed during review: $($copy.Source). Rerun." }
        # Only existing files with an approved fingerprint may be replaced.
        if ($copy.TargetHash) {
            # Stop if another program changed an approved target while the prompts were open.
            if ((Get-FileHash -LiteralPath $copy.Target -Algorithm SHA256).Hash -ne $copy.TargetHash) { throw "Destination changed during review: $($copy.Target). Rerun." }
            # Save the original before overwriting the approved file.
            Backup-File $copy.Target
        }
        # Determine which directory must exist for this file, including the Scripts subfolder.
        $parentFolder = Split-Path -Parent $copy.Target
        # Reuse existing directories without deleting or replacing them.
        if (-not (Test-Path -LiteralPath $parentFolder -PathType Container)) {
            # Announce each new directory before creating it.
            Write-Host "Creating folder: $parentFolder"
            # Let Windows create missing parent directories and report any access problem.
            [System.IO.Directory]::CreateDirectory($parentFolder) | Out-Null
            # Record directory creation in case a later file copy fails.
            $changes.Add("Created folder: $parentFolder")
        }
        # Show the complete source and destination immediately before copying.
        Write-Host "Copying $($copy.Source) -> $($copy.Target)"
        # Permit overwriting only when approved; a newly appearing conflict must cause an error.
        [System.IO.File]::Copy($copy.Source, $copy.Target, [bool]$copy.TargetHash)
        # Record completed copies before verification so a later error still gives an honest summary.
        $changes.Add("Copied: $($copy.Target)")
        # Verify that the installed file is byte-for-byte identical to its packaged source.
        if ((Get-FileHash -LiteralPath $copy.Target -Algorithm SHA256).Hash -ne $copy.SourceHash) { throw "Copy verification failed: $($copy.Target). Rerun before launching the game." }
    }

    # ===== Step 5: Checking and updating mods.txt =====

    # This shared file controls which UE4SS mods load when the game starts.
    $modsTxt = Join-Path $mods 'mods.txt'
    # Announce the check before reading the shared configuration.
    Write-Host "Checking the mod loading list: $modsTxt"
    # Remember whether this will be a new file or an edit requiring consent and backup.
    $exists = Test-Path -LiteralPath $modsTxt -PathType Leaf
    # A missing list begins empty; an existing list is read as bytes to preserve its formatting.
    $bytes = [byte[]]@()
    # Read the original bytes without altering the file's encoding or line endings.
    if ($exists) { $bytes = [System.IO.File]::ReadAllBytes($modsTxt) }
    # A one-byte text mapping preserves all original bytes in ordinary UTF-8 and legacy text files.
    $encoding = [System.Text.Encoding]::GetEncoding(28591)
    # Files without a Unicode marker need no extra bytes at the beginning.
    $markerLength = 0
    # Recognize Unicode markers, longest first so UTF-32 is not mistaken for UTF-16.
    foreach ($unicode in @([System.Text.Encoding]::UTF32, [System.Text.UTF32Encoding]::new($true, $true),
        [System.Text.Encoding]::UTF8, [System.Text.Encoding]::Unicode, [System.Text.Encoding]::BigEndianUnicode)) {
        # Each Unicode encoding provides its own identifying byte sequence.
        $marker = $unicode.GetPreamble()
        # Compare only when the file contains enough bytes for the whole marker.
        if ($bytes.Length -ge $marker.Length -and
            [System.BitConverter]::ToString($bytes, 0, $marker.Length) -eq [System.BitConverter]::ToString($marker)) {
            # Use the same Unicode encoding when reading and saving the updated file.
            $encoding = $unicode
            # Keep its marker separate so it cannot interfere with matching the first mod name.
            $markerLength = $marker.Length
            # The first matching marker settles the encoding choice.
            break
        }
    }
    # Decode the contents after the marker, which will be restored unchanged on save.
    $list = $encoding.GetString($bytes, $markerLength, $bytes.Length - $markerLength)
    # Match enabled entries with optional whitespace or inline comments, but not commented-out entries.
    if ([regex]::IsMatch($list, '(?im)^[ \t]*SRankAlert[ \t]*:[ \t]*1[ \t]*(?:(?:;|#|//)[^\r\n]*)?\r?$')) {
        # An existing enabled entry needs neither another entry nor a rewrite.
        Write-Host 'SRankAlert is already enabled in mods.txt; leaving it unchanged.'
        # Include that decision in the final report.
        $changes.Add('mods.txt already enables SRankAlert; left unchanged.')
    } elseif ($list.Contains([char]0) -or [regex]::IsMatch($list, '(?im)^[ \t]*SRankAlert[ \t]*:')) {
        # Do not invent a second entry when one is disabled/malformed, or guess at unusual encodings.
        $manual.Add("Review $modsTxt manually: an existing SRankAlert entry or unsupported encoding needs attention. Use one SRankAlert : 1 entry above Keybinds; do not add a duplicate.")
    } else {
        # Use Windows line endings for a new or single-line list.
        $newline = "`r`n"
        # Preserve the existing line-ending style when the list already has one.
        if ($list -match '\r\n|\n|\r') { $newline = $Matches[0] }
        # Find the first actual Keybinds entry, ignoring commented-out lines.
        $keybinds = [regex]::Match($list, '(?im)^[ \t]*Keybinds[ \t]*:')
        # Follow the documented convention by inserting SRankAlert immediately above Keybinds.
        if ($keybinds.Success) {
            # Insert only the new line and retain the original characters around it.
            $updated = $list.Insert($keybinds.Index, 'SRankAlert : 1' + $newline)
        } else {
            # Explain the fallback when the expected placement is unavailable.
            Write-Host 'No Keybinds line found; adding SRankAlert : 1 at the end instead.'
            # Add a separating newline only when the original final line lacks one.
            $separator = if ($list.Length -gt 0 -and $list -notmatch '[\r\n]$') { $newline } else { '' }
            # Append the new entry without making up or changing any other mod entry.
            $updated = $list + $separator + 'SRankAlert : 1' + $newline
        }
        # Creating a missing file needs no overwrite approval.
        $approved = -not $exists
        # Ask before changing an existing list, even though the edit only adds one line.
        if ($exists) { $approved = Confirm-Change "Update $modsTxt by adding SRankAlert : 1? The original will be backed up and its existing text kept." }
        # Write only when no replacement is needed or the user explicitly approved the edit.
        if ($approved) {
            # Recheck game state after the last user prompt.
            if (Get-Process -Name 'ReadyOrNot*' -ErrorAction SilentlyContinue) { throw 'Ready or Not started during installation. Close it and rerun to enable the mod.' }
            # Check and back up an existing list before replacing it.
            if ($exists) {
                # Exact byte comparison catches edits made by another program during the prompt.
                if ([System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($modsTxt)) -ne [System.Convert]::ToBase64String($bytes)) { throw 'mods.txt changed during review. Rerun to review its new contents.' }
                # Preserve the original list in case the user later wants to undo this edit.
                Backup-File $modsTxt
            }
            # Begin with no marker for files that did not originally contain one.
            $output = [byte[]]@()
            # Restore the original encoding marker exactly once when present.
            if ($markerLength -gt 0) { $output = $bytes[0..($markerLength - 1)] }
            # Encode the modified text using the same encoding as its source.
            $output = [byte[]]($output + $encoding.GetBytes($updated))
            # Announce the actual write immediately before opening the file.
            Write-Host "Writing SRankAlert : 1 into $modsTxt"
            # Refuse to overwrite any unexpected file that appears after a missing-file check.
            $mode = if ($exists) { [System.IO.FileMode]::Create } else { [System.IO.FileMode]::CreateNew }
            # Open exclusively so another program cannot write simultaneously through a shared handle.
            $stream = [System.IO.File]::Open($modsTxt, $mode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            # Always close the file, including after a write failure, to avoid leaving it locked.
            try { $stream.Write($output, 0, $output.Length) } finally { $stream.Dispose() }
            # Report the successful edit in the final summary.
            $changes.Add('Added SRankAlert : 1 to mods.txt.')
        } else {
            # Keep the user's decision and explain how to finish enabling the already-copied files.
            $manual.Add("Add SRankAlert : 1 above Keybinds in $modsTxt. You declined the automatic edit; the list was left unchanged.")
        }
    }
    # Reach this point only after the copying and enabling decisions are complete.
    $finished = $true
} catch {
    # Show the actual cause of an early stop instead of claiming installation succeeded.
    Write-Host ("Installation stopped: " + $_.Exception.Message) -ForegroundColor Yellow
    # PowerShell may wrap filesystem errors, so inspect their underlying cause.
    $cause = $_.Exception
    # Follow nested errors to identify Windows access-denied failures accurately.
    while ($cause.InnerException) { $cause = $cause.InnerException }
    # Explain administrator access only if Windows actually denied permission.
    if ($cause -is [System.UnauthorizedAccessException]) {
        # Offer a manual remedy without changing permissions or elevating automatically.
        Write-Host 'Windows denied access. Check folder permissions and whether the file is read-only. If your game folder requires administrator access (sometimes under Program Files), open PowerShell with Run as administrator and rerun this script. No elevation was attempted.'
    }
    # A late error can leave completed copies; tell the user to finish before launching the game.
    $manual.Add('Resolve the reason above, then rerun before launching. Completed changes and backups are listed below; no automatic rollback or deletion was attempted.')
} finally {
    # ===== Step 6: Showing what happened and what to do next =====

    # Always show the summary, including when a prerequisite was missing.
    Write-Host "`n===== Installation summary ====="
    # Explicitly report when no changes or identical-file decisions were recorded.
    if ($changes.Count -eq 0) { Write-Host 'No installation changes were made.' }
    # List completed copies, unchanged files and recovery backup paths.
    foreach ($change in $changes) { Write-Host "  $change" }
    # Call the installation complete only if it has no unresolved manual steps.
    if ($finished -and $manual.Count -eq 0) { Write-Host 'Installation complete.' }
    # Display all remaining work without disguising an incomplete install as success.
    foreach ($step in $manual) { Write-Host "MANUAL STEP: $step" }
    # Give launch and verification instructions after the installation phases have run.
    if ($finished) {
        # UE4SS reads mods.txt at startup, and this mod attaches its HUD inside a mission.
        Write-Host 'Next: finish any manual steps above, launch Ready or Not, and enter a mission. No hotkey is needed to start alerts.'
        # Tell hand-editors where the mod will create their persistent settings and where to find help.
        Write-Host ("Settings: " + (Join-Path $destination 'config.json') + ' (created on first launch if missing). See CONFIG.md; future updates leave this file alone.')
        # Supply the exact log path so the user can open it directly in Notepad.
        Write-Host ("To verify loading, open " + (Join-Path $ue4ss 'UE4SS.log') + ' in Notepad and search for [SRankAlert].')
        # Explain both the script-loading and visible-HUD evidence to look for.
        Write-Host 'Look for "loaded v" and then "toast attached" after entering a mission. If missing, inspect nearby errors and check the experimental UE4SS requirement.'
    }
    # Keep right-click launches open so users have time to read success messages and errors.
    if (-not $NoPause) { [void](Read-Host 'Press Enter to close this installer') }
}
