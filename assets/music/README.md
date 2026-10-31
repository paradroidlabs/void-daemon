# Local soundtrack drop folder

Copy your own `.ogg`, `.mp3`, or `.wav` files here when running the source project.
For the standalone Windows build, use `music` beside `VOID-DAEMON.exe` instead.
No music files were present when this integration was implemented; none are
represented as your supplied compositions.

Files directly in the folder form the shared fallback playlist, in filename
order. Optional subfolders select music by context:

- `hangar/`
- `survival/`
- `lab/`
- `debrief/`
- `race/` (reserved for a future mode; no racing mode is implemented)

A nonempty context playlist overrides the fallback. Otherwise, the fallback
continues across contexts without restarting the same track. If neither exists,
there is no soundtrack playback; procedural ship/combat sounds remain available.
At natural track end, the next file starts; a one-track list repeats. Context
changes crossfade over 1.5 seconds. Files are not edited, resampled offline,
tempo-mapped, rearranged, or uploaded. Runtime decoding is local.

Start/reopen the hangar after copying files, or choose Settings > Reload Local
Music. Settings show the discovered count. MUSIC volume is independent of
EFFECTS and HIVE VOICE. Music ducks beneath hive feeds and plays more quietly
while the run is paused. The existing synthetic void bed drops 12 dB beneath
active music. Master remains the final mute/limiter.

Use ordinary PCM WAV, Ogg Vorbis, or MP3. AAC/M4A, FLAC and stems are not yet
supported. Subfolders are only scanned one level deep. Source-project tracks
must be imported by Godot before they can be embedded in an export; standalone
drop-folder tracks require no import or rebuild. Relative resource paths and
runtime raw-file loading are separate paths, not a seed/replay guarantee.

For a first audition, use one quieter full-length track, then test swarm, beam,
hive speech/subtitles, pause/resume, and a boss. Waveform headroom tests are not
an assessment of the mix with your actual music. Do not commit or redistribute
audio until you deliberately choose the files and intended release treatment.
