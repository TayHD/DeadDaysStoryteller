DEAD DAYS: STORYTELLER  (v0.1.0, Build 42)
==========================================

A story director built on Project A-Life NPCs. Replaces QuestSystem.
Press J in game for the journal.

WHAT IT DOES
------------
THE SAGA (main story, ~30 hours)
  Every world rolls its own story when the first survivor arrives:
  - Factions cast from A-Life's 147: a community that needs you, a military
    faction with an agenda, a warlord's crew, and a wildcard group.
  - A cast with names and secrets: the community leader, their abducted kin,
    a doctor, an officer, the warlord, his lieutenant, an informant.
  - Twists rolled in secret: a mole (informant or doctor) or the leader's
    bargain; the military's Operation (burn the settlement) or the Lab
    (they want the abducted kin's blood); sometimes the warlord is the
    kin's parent.
  - 4 acts, 28 story chapters, run Days Gone-style as parallel storylines.
    Act III forks three ways (settlement / soldiers / warlord), each with
    its own 4-chapter path and its own Act IV enemy and boss. Optional
    chapters are rolled per playthrough. 4 endings. When a saga ends,
    a new one starts two days later and inherits its consequences.
  - Missions happen in real buildings found on the map (malls, hospitals,
    police stations, schools...), chosen near the player each time.

MISSION TYPES (mix and match per mission)
  reach, eliminate (A-Life squads), free a captive, lockpicking (pick /
  pry / key), search, retrieve, hand-in (in person or radio drop), hold the
  line (waves), talk (in person or radio), kill quotas, infected clearing,
  wait (long-running arcs), sabotage A-Life outpost radios, allies who fight
  beside you.

SIDE CONTENT (+20 hours)
  Rescues (some captives are bait, some join you), supply runs, bounties,
  distress calls with hidden outcomes, recon, courier jobs (read the
  letter?), missing patrols, horde nests, trades, faction disputes you
  judge, vault heists, multi-day "long haul" chains, settlement projects.
  Daily ops every morning at 6:00 with streak bonuses.

CHOICES THAT MATTER
  Standing (-100..100) per faction is written straight into A-Life's own
  reputation: factions you've wronged shoot on sight, and ones you've helped
  hold fire. Faction power shifts with your choices; a strong warlord means
  raids on the roads.

BUDDIES (The Last of Us style)
  Companions follow you and fight with A-Life's combat AI. They ride along
  when you drive, banter (time, weather, story), react to your choices
  ("{name} didn't like that"), give perk gifts when the bond is strong,
  and can leave if loyalty collapses. Each has a 3-mission loyalty arc
  (4 backstories). Some missions require a partner.


CONVOYS
  Military supply convoys, raider war parties and trade caravans travel
  town to town off-screen. Resting convoys near a player become real
  vehicles with an armed escort; kill the escort and the trucks are yours.
  You hear moving convoys rather than see them (the engine can't make an
  NPC drive a car).

AUDIO
  Radio SFX (synthesised, tools/Make-RadioSfx.ps1): incoming-call chirp,
  key-up squelch, static bed under radio conversations, key-down.
  Voice pack: every spoken story line is pre-generated with ElevenLabs
  (Eleven v4) and shipped in common/media/sound/dds_voice as small Ogg files.
  Spoken lines never contain world-specific names or places, so one pack
  serves every playthrough. Each character role has a voice per archetype
  and gender. Emotion is directed with inline audio tags ([nervous],
  [sighs]...) that are stripped from on-screen subtitles.
  Regenerate after writing changes:
    1. Start any server with the mod once (it exports
       Zomboid/Lua/DeadDaysStory_voicelines.txt).
    2. tools\Generate-Voices.ps1 -Plan       (counts, free)
    3. tools\Generate-Voices.ps1 -Generate   (only missing lines; uses credits)
  Casting lives in tools\voices.json. Delete a line's .ogg to redo it.

SETUP
-----
1. Game version: A-Life 1.3.15+ needs Build 42.21. Update the dedicated
   server first (see the note at the bottom).
2. Your own client: Storyteller-Setup.ps1 -ClientCopy (already done once).
3. Players: publish from the game's main menu > Workshop (folder prepared by
   Storyteller-Setup.ps1 -PrepareWorkshop). Note the Workshop ID.
4. Server: stop Dead Days, then
     .\Storyteller-Setup.ps1 -EnableOnServer -WorkshopId <id>
   That removes QuestSystem and adds this mod after ProjectALifeNPCs.

SETTINGS (Sandbox > "Dead Days - Story" and "Dead Days - Convoys")
  Buddies can die, daily ops per day, open side leads, incident rate,
  lock the A-Life Creator (default ON: the story does all spawning),
  convoys.

EXTENDING
  Add-on mods can hook the server without editing this one:
    DDS.Server.addTicker(name, fn)   runs fn() once a second
    DDS.Server.addAdminOp(op, fn)    handles an admin command

ADMIN TOOLS
  Journal > Log tab (admins only): New lead, Unlock act chapters,
  Advance act, Give buddy, Show secrets, New saga.

FILES
  server/DeadDaysStory/        engine (state, quests, dialogue, saga,
                               director, buddies, convoys, settlement)
  server/DeadDaysStory/Story/  content (acts 1-4, side, loyalty)
  client/DeadDaysStory/        journal, dialogue, HUD, audio, markers
  DDS_ALife.lua                the only file that touches A-Life internals;
                               check it first when A-Life updates.
  Story state is saved in world ModData and mirrored to
  Zomboid/Lua/DeadDaysStory_<world>.txt on every save.

STATUS
------
Verified: every file loads on a real B42 (42.20.4) dedicated server with no
errors; 64 mission templates and 34 chapter definitions register; story
state initialises; runs in fallback mode without A-Life.
Not yet verified in live play (needs a 42.21 server + a connected client):
A-Life squad spawning, buddy following in multiplayer, convoy vehicles,
and the UI's look in game.
