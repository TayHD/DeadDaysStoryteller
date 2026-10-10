# Dead Days: Storyteller: changelog

## 0.3.0 (2026-10-10)
- NPCs now look like who they are: named characters get an A-Life body of the right sex from their faction, and the same person always gets the same face. Quest NPCs already in the world with a mismatched body are replaced once.
- New stories pick each main character's gender from what their faction can field in A-Life (some factions only have men or only women).
- Buddies get a matching body too.
- Server-specific features moved out of Storyteller into a separate add-on. Storyteller now has extension hooks for add-on mods: `DDS.Server.addTicker(name, fn)` and `DDS.Server.addAdminOp(op, fn)`.
- Convoy settings have their own sandbox page: "Dead Days - Convoys".

## 0.2.4 (2026-10-10)
- Fixed: A-Life refused to spawn the camp's people once a player had spent time there, because it treated the camp as that player's base. Story NPCs now spawn there, and are re-created in place when you return.
- Project A-Life is now declared as a required mod, and the minimum game version is 42.21.
- New mod poster.

## 0.2.3 (2026-10-10)
- The person you need to talk to walks over when you're within about 30 tiles and starts the conversation when they reach you.
- That person is outlined in gold with a "Talk to ..." label.
- Story NPCs you need can't be killed by accident, and are respawned if their body is lost (camp unloaded, server restart). Characters the story lets you kill still can be.
- Missions wait for the camp's own resident instead of spawning a second copy of the same person.

## 0.2.2 (2026-10-10)
- Fixed: wrapped UI text lost the first letter of continuation lines ("roup" for "group").

## 0.2.1 (2026-10-10)
- The opening radio call plays on its own about 10 seconds after you spawn, and the first story mission starts with it.
- Starting kits by occupation (a police officer gets a pistol and ammo, a doctor gets a medical bag, and so on).
- The mission tracker moved left so it doesn't cover the status icons.
- The HUD button just says "Journal".
- Sentences in the UI start with a capital letter ("The Camp", not "the Camp").

## 0.2.0 (2026-10-10)
- Grounded rewrite of all story writing, with character archetypes (e.g. psychotic or provider warlord, by-the-book or burned-out officer).
- Fully voiced story dialogue (about 1,000 lines, ElevenLabs v4) with radio SFX.
- Missions shared with your in-game faction for co-op.
- Quest givers and camp residents fight alongside you when you're close.

## 0.1.0 (2026-10-09)
- First release: per-world story director with four acts and 34 chapters, branching dialogue, faction standing, procedural missions, daily ops, buddies with loyalty arcs, and convoys. Built on Project A-Life.
