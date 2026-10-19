# VOID//DAEMON — desktop experience checkpoint

Four playable chassis: Graviton gather/salvo + Phase Skip; Bastion sustained beam + Breach Step; Scrapper clamp/collapse + Tow Step; Redline close plasma + position-only Backtrace. Shared automatic DRIVER/ARC remain.

New inertial flight, counter-thrust, bounded gravity wells, flight instruments, boot hangar, live gameplay-driven hive PiP/subtitles with optional system speech, and a first procedural audio/mix pass. Boss health bars stay upright. Per-source/kit/flight scorecard remains wide and non-scrolling on desktop.

Combat renders separately from the HUD: a slim top rail and lower instrument/hive dock cannot hide enemies. Default view is wider (82%); wheel, +/- keys and dock buttons adjust 65–125% zoom. Zoom-aware aiming and spawning are tested.

Extract the ZIP and open VOID-DAEMON.exe. No Godot/editor/account/network is required to play. Select a ship, then Deploy or Combat Lab. Play Combat Lab.cmd opens the Graviton lab directly. Shift and Space are aliases for the selected maneuver; shield is passive. Included checklists explain every kit and remaining playtest gates. This is an unsigned Windows x64 prototype, not an installer.

Source tests pass for boss bar, flight, chassis cadence/resources/cancellation, final-hit accounting, scorecard, HUD separation/zoom, mouse/touch routing and audio waveform/voice bounds. Rendered desktop fixtures and standalone mouse selection/attack/pause/menu flows were checked. The 180-enemy-plus-boss stress fixture passes bounded simulation checks; this is not stable-60-FPS certification.

Still human gates: normal full survival on each ship, fun/balance, actual listening/voice preference, physical controller, real phone and device frame pacing. Procedural/system speech is a first pass, not finished acted audio. Headless audio shutdown can report engine playback references; rendered teardown has not reproduced the warning.

The older Courier/Guard/Boost experiment is preserved separately on codex/courier-ui-checkpoint, including its matching panel/zoom fix. Its controls intentionally differ; it is not the downloadable four-kit build. Master is unchanged.
