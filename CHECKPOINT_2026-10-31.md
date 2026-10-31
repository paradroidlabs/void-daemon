# First Arrival checkpoint / October 31, 2026

Branch: `checkpoint/first-arrival-2026-10-31`.

This checkpoints the existing `desktop-2026.10.29.3` eleven-mission campaign,
its source, documentation, regression fixtures and preserved timing evidence.
No gameplay or executable was changed by the checkpoint operation.

The original EXE/ZIP remain under `builds/` and are not committed as large Git
binaries. `artifacts/checkpoints/desktop-2026.10.29.3.json` records their hashes,
archive size and all source fingerprints from the original export manifest.
That manifest correctly retains its October 19 base commit / dirty-source flag;
it must not be rewritten to pretend the later checkpoint produced that EXE.
Use a new build version for a future export instead of overwriting this original
artifact under the same filename.

The source and four-chassis timing results support roughly twenty minutes of
active simulation, excluding story reading. Human gameplay quality, physical
device support and rendered FPS remain unverified. See CAMPAIGN_PLAYTEST.md,
PLAYTIME_AUDIT.md and CAMPAIGN_COMPLETION_AUDIT.md for precise scope.

Unrelated raw video, screenshots/import sidecars and prior executables are
preserved locally outside this checkpoint. No main/master merge or public
release announcement is part of this source backup.
