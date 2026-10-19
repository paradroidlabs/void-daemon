# VOID//DAEMON — Windows desktop playtest

Build: `desktop-2026.10.19.1`. The title bar identifies the build and mode.

## Play without Godot

Double-click `VOID-DAEMON.exe` for the full survival run: five minutes of escalating waves followed by WATCHDOG. All game resources are embedded; no editor, Python, account, or network connection is required to play. Keep the license notices with redistributed copies. This is an unsigned prototype, not an installer.

The **VOID DAEMON - Combat Lab** desktop shortcut opens the same executable with `-- --combo-lab --fixture=cluster --loadout=chain`. The **VOID DAEMON** shortcut starts the full run. Desktop shortcuts are local conveniences; their absolute paths are not portable between computers.

The downloadable ZIP also includes `Play Combat Lab.cmd`; keep it beside the executable to open the lab on another desktop without creating a shortcut.

In a source checkout, `play_combo_lab.cmd` opens the lab and `run_game.cmd` opens survival through the portable editor engine. They are not the standalone release executable.

## Controls

| Input | Action |
|---|---|
| WASD / arrows | Move |
| Mouse | Aim priority |
| Hold M1 / release | Gather with gravity and load missiles / launch salvo |
| Shift or Space | One shared Phase Skip action and cooldown |
| Esc / P | Pause / resume |
| 1 / 2 / 3 or click | Select an upgrade during survival |
| T | Toggle touch preview |
| Lab F1 / F2 / F3 | Cluster / Dispersed / Boss |
| Lab F4 / F5 / F6 | Salvo Alone / Graviton + Salvo / Full Chain |
| Lab R | Reset the selected fixture |
| Lab F7 / Report | Actual scorecard; restart preserves fixture/loadout |

Shield regenerates passively. M2/Q has no combat action in this kit; Q quits only inside the pause menu. Classic mode has different VENT controls. F10 is a debug boss shortcut, not a legitimate full-run result.

## Hands-on pass

1. In the lab, try tap, partial, and full charges, movement during attack, and phase cancellation. Compare the three fixtures and three loadouts. Automatic baseline processes remain in all comparison presets.
2. Pause while holding, resume, change focus, reset, and open the report. Check that attacks do not stick and the scorecard remains readable without scrolling.
3. Play survival from level 1. Choose upgrades, reach death or the boss, inspect the scorecard, and restart. Check that automatic upgrades still matter alongside the manual salvo.
4. Note the build, fixture/loadout or seed, controls, what happened, and the one change you want. Check sound output, window resizing, and comfort on this actual desktop.

## Verification boundary

On October 19, 2026, the source regression suite passed: smoke, exact damage/scorecard, Graviton mechanics, full mouse-input sequence, and native two-thumb GUI-event routing. The stress fixture passed with 180 normal enemies plus a boss, at most six missiles, one field, twelve pull contacts, and reconciled damage totals. These are correctness checks, not frame-rate certification.

This build also fixes the rotating boss health bar: a separately transformed child follows world position while staying horizontal above the boss. A regression checks multiple rotations, a rotated/scaled parent, current health, and cleanup on death. The standalone release runtime passed the embedded smoke scenario; rendered release launch and mode selection are checked separately from headless tests.

The rendered source lab opened on the user's AMD Radeon desktop; external mouse hold/release and pause were inspected. The user's supplied Boss + Full Chain victory capture is preserved as `artifacts/desktop_boss_victory.png`. It shows a lab clear, not a full survival-run completion. Remaining human full-run, controller-hardware, and phone gates must not be silently marked complete.

## Rebuild

Install Godot 4.7.1 or use the ignored portable copy in `.tools/godot`. Run `python scripts/fetch_windows_template.py` to fetch the official matching Windows runtime into `.tools/windows` (HTTPS ranges and ZIP CRC checked). Also place the upstream engine LICENSE.txt and COPYRIGHT.txt there as `GODOT-LICENSE.txt` and `GODOT-COPYRIGHT.txt`. Run `build_windows.cmd`. The release preset embeds resources and excludes tests, screenshots, and development notes. Output and generated `build.json` are under ignored `builds/windows-desktop-2026.10.19.1`; the manifest records the source commit, dirty state, and executable SHA-256.
