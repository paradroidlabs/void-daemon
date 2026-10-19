# Courier experiment — unobstructed playfield

October 19, 2026. This worktree is a separate combat experiment, preserved on `codex/courier-ui-checkpoint`. It is not the newer Graviton/Bastion/Scrapper/Redline kit checkpoint.

The active module diagram is removed from combat. Full inspection, including the ship schematic, remains in the four-tab paused dashboard. A slim 82px status rail replaces the large terminal header; a 64px lower dock holds logs and zoom controls. Combat renders in a separate clipped viewport: passive HUD elements cannot hide enemies or shots. Intentional combat feedback and optional touch controls remain gameplay overlays, not passive diagnostic panels.

Camera default is wider at 82%. Mouse wheel, `+`/`−` and dock buttons adjust 65–125% zoom. Mouse/world aiming transforms account for offset and zoom. Spawn positions account for the visible world region. Zoom-button clicks cannot start M1 precision charging. Current controls are preserved: auto DRIVER + ARC, additive M1 charge/release, M2/Space guard, Shift vent/boost.

Verification: `tests/combat_review.gd` covers the existing combat and pause contract. `tests/playfield_layout_test.gd` covers active schematic suppression, pause tabs retained, isolated view, dock non-overlap and zoom/aim transforms. The rendered fixture is `artifacts/courier_docked_ui.png`. Physical controller/phone and human full-run balance remain open gates. This fix requires restarting the old process; editing source does not live-patch an already running exported/debug game.
