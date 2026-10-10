# Dead Days: Storyteller

A dynamic, branching story campaign for Project Zomboid (Build 42), built on
[Project A-Life](https://steamcommunity.com/sharedfiles/filedetails/?id=3803984183).

Every world gets its own story, generated from scratch when the first player joins:
its own cast, its own factions, its own betrayals. Branching dialogue, faction
standing, buddies with loyalty arcs, voiced radio calls, shared co-op missions and
convoys on the roads.

- **Steam Workshop:** https://steamcommunity.com/sharedfiles/filedetails/?id=3816904815
- **Mod ID:** `DeadDaysStoryteller`
- **Requires:** Project Zomboid 42.21+ and Project A-Life (`ProjectALifeNPCs`)

## Credit: Project A-Life

Every NPC in Dead Days is Project A-Life's work: the people, the factions, how they
fight, talk and remember you. Dead Days doesn't include, copy, fork or replace any
of A-Life's code. It uses A-Life's NPCs, factions and reputation through its public
Lua tables and adds a story on top. All A-Life access is in one file,
`server/DeadDaysStory/DDS_ALife.lua`. Please support the
[Project A-Life team](https://steamcommunity.com/sharedfiles/filedetails/?id=3803984183).

## Repository layout

```
mod/DeadDaysStoryteller/     the mod, Build 42 layout (42/ + common/)
  42/media/lua/shared/       core: RNG, templating, networking, voice manifest
  42/media/lua/server/       story engine, run by the server (or the game in SP)
    DeadDaysStory/Story/     the content: acts 1-4, side missions, loyalty arcs
  42/media/lua/client/       UI (journal, HUD, dialogue), audio, chat bridge
  common/media/sound/        radio SFX; voice files go in dds_voice/ (not in git)
tools/                       voice-pack generator, radio SFX synth, setup helper
branding/                    Workshop poster and description
```

## Installing from source

Copy `mod/DeadDaysStoryteller` into `%UserProfile%\Zomboid\mods\` (for a client or
single player) or into a dedicated server's mods folder, then enable Project A-Life
first and Dead Days: Storyteller after it.

**Voice audio isn't in this repository.** The voice lines (about 1,000 small `.ogg`
files) aren't committed. Without them the dialogue still works; it's just silent.
To get voices, either:

- subscribe on the Workshop, where the full voice pack is included, or
- generate your own with `tools/Generate-Voices.ps1` (needs an ElevenLabs account).

## Writing content

Story content is plain Lua data in `server/DeadDaysStory/Story/`. Chapters are
registered with `K.chapter(...)`, missions are built from objective builders in
`DDS_Quests.lua` (`B.reach`, `B.talk`, `B.lock`, `B.handin`, ...), and dialogue
trees with `D.register(...)`.

Two rules keep the voice pack workable:

- **Spoken lines contain no generated names or places.** Names live in speaker
  headers, player choices and mission text, so every line can be recorded once and
  shipped.
- Emotion tags like `[nervous]` steer the voice generator and are stripped from
  subtitles.

## Tools

The tools expect to sit in `<dedicated server folder>\tools` (server started with
`-cachedir=data`), next to `data\mods\DeadDaysStoryteller`.

- **`Generate-Voices.ps1`** builds the voice pack with the ElevenLabs API and ffmpeg
  (put `ffmpeg.exe` in `tools\ffmpeg\`). The server exports the line list on startup
  to `data\Lua\DeadDaysStory_voicelines.txt`. Useful switches: `-Plan` estimates cost,
  `-Generate` makes the missing files, `-Prune` removes stale ones. Your API key is
  read from the `ELEVENLABS_API_KEY` environment variable and is never stored.
  Casting lives in `voices.json`.
- **`Make-RadioSfx.ps1` + `DdsAudio.cs`** synthesize the radio click, static and
  call tones.
- **`Storyteller-Setup.ps1`** copies the mod to your client, prepares the Workshop
  upload folder, or enables the mod in a server ini.

## Notes for Kahlua (Project Zomboid's Lua)

- There's no `next()`; use `DDS.isEmpty`.
- An empty pattern capture comes back as `nil`, and in `string.gsub` it can drop the
  matched character. Avoid optional captures.
- `getFileWriter` refuses some extensions, such as `.tsv`; use `.txt`.

## Extending it

Add-on mods can hook into the story server without editing this mod:

- `DDS.Server.addTicker(name, fn)` runs `fn()` once a second on the server.
- `DDS.Server.addAdminOp(op, fn)` handles an admin command `op` with `fn(player, args)`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Status

Early release, in active development. Bug reports and pull requests are welcome.

## License

[MIT](LICENSE). Project A-Life is a separate mod with its own terms and isn't
covered by this license.
