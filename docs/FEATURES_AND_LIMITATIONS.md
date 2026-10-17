# Implemented features & known limitations

Status: **playable vertical slice (v0.9)**. The core loop, all game modes,
all 12 arenas, customization, progression and menus work end to end. The
automated smoke test passes on Linux. What's left is mostly content polish
and final art and audio quality (see "Limitations").

## Implemented

### Core combat
- Movement:
  - Run, auto-sprint, variable-height jump, coyote time, jump buffering, one air jump, wall cling, wall jump and fast-fall.
  - Drop-through platforms; moving-platform carry; ice and conveyor surfaces.
- Attacks:
  - Light 3-hit combos that chain only on hit; chargeable heavies (up to +60% damage); dash heavies.
  - Up launchers and low sweeps; air attacks (neutral spin, up, down spike, forward heavy).
  - Landing lag on air attacks.
- Defence:
  - Directional block with a guard meter and guard break.
  - Parry in a 0.16 s window. It stuns melee attackers and reflects projectiles.
  - Rolls, spot dodges and air dodges with invulnerability frames.
  - Teching on floor and wall impact; get-up options; spawn protection.
- Hit model:
  - HP-based KOs plus ring-outs through blast zones.
  - Knockback scales with missing HP.
  - Directional influence; tumble with floor and wall bounces that dampen and are capped (no infinite bouncing).
  - Hitstun decays over a combo (anti hit-lock).
  - Hit-stop on both fighters, victim shake, camera shake, hit sparks, damage numbers.
  - Line-of-sight checks so attacks can't hit through walls.
- Disarming: strong hits knock weapons out of paws. Weapons can be thrown (up, forward, down) or dropped. Thrown items deal weight-based damage.
- Status effects: burn, slow, paint, freeze (hitting a frozen cat shatters the ice for bonus knockback), bubble trap, shock stun.

### Weapons (40)
- **Melee (15):** sword, katana, dagger, axe, war hammer, spear, lance, scythe (heavy pulls), bat, frying pan (reflects shots), stick, boxing gloves, steel claws (multi-hit), chain whip (tip bonus), giant mallet.
- **Ranged (8):** bow (charged piercing shot), crossbow, slingshot, blaster, energy pistol (3-shot burst), snowball launcher, paintball gun, magic wand (homing).
- **Special (9):** boomerang (returns), rocket launcher (splash damage that can hit yourself), freeze ray, gravity gun (pull/push), lightning staff (chain and sky strike), fire wand, bubble cannon, void orb (black hole), tiger potion (transformation).
- **Funny (6):** giant fish, baguette, rubber chicken (MEGA SQUEAK), foam sword, giant spoon, fish hammer.
- **Arena props (4)** that break after use: pipe, plate, torch, broom.
- **Data per weapon:** damage, knockback, speed, reach, weight (slows movement, strengthens throws), material-based impact sound, rarity, ammo, fire rate, effects. Movesets come from the archetype.
- **Spawning:** weapons drop from the sky, from crates with parachutes, and as arena props.
- **Match rules:** weapon sets (all, melee, ranged, funny, classic, none) and start-weapon rules.

### Network multiplayer (LAN)
- **Up to 10 players across any number of devices** on the same LAN or Wi-Fi. Several players can share one device. **LAN games are players-only: no CPU fighters** (Survival and Boss still have their enemy waves and boss).
- **Host-authoritative:** the host simulates everything.
  - Clients stream input every frame.
  - The host streams compressed ~30 Hz snapshots (about 0.8 KB for 10 fighters) plus reliable event batches (effects, sounds, hit reactions, late-spawned fighters).
  - Clients dead-reckon between snapshots for smooth motion.
- **Discovery:** UDP broadcast beacons; joining by IP also works. Version check on join.
- **Shared lobby:** the host controls mode and match setup. Everyone picks a cat and team and readies up from their own device.
- **Robustness:**
  - A client that leaves mid-match has its cats removed from the fight (marked LEFT); the match carries on with the remaining players.
  - If the host leaves, everyone returns to the menu with a message.
  - Late joiners spectate the current match and can play in the next one.
- **Stats and rewards:** each device records only its own players' stats and rewards.

### Local multiplayer
- **Devices:** up to 10 fighters on one device from 2 keyboard halves, any number of gamepads, or a mix. CPUs fill seats.
- **Lobby:** join, leave and ready up per device; cat, team and profile choice per slot; HEAVY/TAUNT add or remove CPUs.
- **In match:**
  - Shared dynamic camera with smooth zoom, a HUD margin, a stage anchor, and off-screen indicator bubbles.
  - Player colours plus shapes (▲●■◆), team colours plus dashed or solid team rings, and staggered name tags.
  - Pause from any player; the pause menu has a restart option.
- **Disconnects:** a controller disconnect pauses the game; you can continue with a CPU or reconnect (in LAN games the host can continue without that player instead).
- **CPU AI** at 4 difficulty levels:
  - Navigation: gap jumping, platform climbing, drop-through, recovery after being launched, hazard avoidance.
  - Combat: item pickup, ranged spacing, combos, blocking, parrying, dodging, throwing.
  - Mode objectives for the hill, the fish, baskets and the boss.

### Game modes (13)
| Mode | How it plays |
|------|--------------|
| Free-for-All | Rounds; last cat standing wins each round |
| 2v2 Teams | Rounds; last team standing |
| 1v1 Duel | Rounds; both cats start with the same weapon |
| Stock | Lives; respawn until you run out |
| Timed | +1 per KO, −1 per self-destruct; sudden death on a tie |
| Weapon Roulette | Stock rules; everyone gets a new random weapon every few seconds |
| King of the Hill | The zone moves; score only while you hold it uncontested |
| Capture the Fish | Carry or throw the golden fish to your team's basket |
| Survival | Waves of Mecha-Mice and Alley Cats with mini-bosses; co-op or compete for KOs |
| Boss Battle | MECHA-MOUSER 9000 with stomp shockwaves, charge, homing missiles, eye laser, minions and two phases |
| Chaos | Stock rules plus a random modifier every few seconds: low gravity, giant weapons, slippery floors, bouncy bullets, swaps, item rain, zoomies, giant cats, power-up party |
| Training | Dummies (stand, walk, jump, block, fight back), restocking weapon racks, frame data, combo counter, weapon spawner, position reset |
| Tournament | 4- or 8-entrant knockout bracket; CPU matches can be watched or simulated; champion screen |

Modes are `BaseMode` subclasses with hooks for respawn, scoring, end
conditions, HUD, AI objectives, world drawing and camera points.

### Arenas (12)
| Arena | Features |
|-------|----------|
| Rooftop Rumble | Gap, lift, updraft vents |
| Sushi Restaurant | Conveyor, stove flames, plate props |
| Neon Dojo | Floating competitive layout, elevators |
| Pirate Ship | Cannon sweeps |
| Frozen Lake | Ice, falling icicles |
| Volcano Arena | Rising lava with warning |
| Cat Castle | Trapdoor over the moat, towers, torches |
| Arcade Arena | Laser sweep, elevator |
| Junkyard | Hydraulic crusher, crane platform, pipes |
| Haunted Mansion | Floating books, thrown vases, brooms |
| Space Station | Low gravity, orbiting platform |
| Garden Dojo | No hazards |

Each arena has its own layered parallax backdrop, ambient particles and seeded music.

### Customization
- **Cat Creator:** live animated preview with tabs for coat, face, gear, style and presets.
- **Coat:**
  - 24 fur colours for the main, second and patch slots.
  - 9 patterns: solid, tabby, spots, tuxedo, calico, Siamese, white paws, chest patch, two-tone.
  - 3 cosmetic body types; 5 tails; 6 idle personalities.
- **Face:** 10 eye colours, 5 eye shapes, 5 ear types, 4 whisker styles, 4 expressions, 4 taunts.
- **Gear:** 33 accessories across head, face, neck, back and ear slots.
- **Style:** 8 weapon skins, 7 attack trails, 6 victory poses, 4 entrances, 5 KO effects, 6 nameplates, 8 profile icons.
- **Presets:** save, save-as, rename (on-screen keyboard or typing), duplicate, delete. The 12 built-in roster cats are read-only and are copied when edited.
- **Fairness:** locked cosmetics can be previewed but not saved. Cosmetics never change hitboxes or stats.

### Progression and saves
- **Profiles:** multiple local profiles with full stats (matches, wins and losses, KOs, falls, ring-outs, damage, parries, throws, best combo, play time, favourite weapon, top mode).
- **Achievements:** 25, plus 5 training milestones. Yarn rewards and cosmetic unlocks.
- **Daily challenges:** 3 per day, seeded by the date.
- **Cat mastery:** levels from Rookie to Mythic.
- **Collection:** weapon encyclopedia with stat bars, trophy cabinet, shop, challenges page.
- **Saves:** JSON written atomically with an automatic `.bak` fallback, manual export/restore of backups, a triple-confirm reset, and an "open save folder" option.

### Presentation
- Every screen is code-drawn pixel UI:
  - title, main menu, mode select, lobby, setup with an arena preview
  - results with podium, awards and rewards
  - cat creator, collection, stats, settings, controls, credits
  - tournament bracket, pause menu
  - toasts and an FPS counter
- **Pixel font:** a 5×7 font with integer scaling and an all-caps arcade look.
- **Audio:**
  - 50+ synthesized sound effects with variants and pitch randomization, layered by impact material.
  - Cat meows, hisses, purrs and yowls.
  - Procedural chiptune per arena plus the menu theme.
  - Music ducking on KOs and slow motion on round-deciding KOs.

### Accessibility and settings
- Remappable controls for each keyboard half and for gamepads: a primary and an alternate binding per action, clear a slot, bindings swap on conflict (also across the two keyboard halves), reset one device or all. Gamepad triggers (LT/RT) can be bound. Stick deadzone and sensitivity, rumble toggle.
- Screen shake slider, reduce flashing, simplified effects, colour-blind palette (Okabe-Ito) with shapes always shown, large HUD, damage-number toggle.
- Default bot difficulty; adjustable lives, time, rounds, HP, items, power-ups, hazards and friendly fire.
- Volume sliders for master, music and SFX.
- Display: windowed, borderless window, fullscreen or exclusive fullscreen (F11 / Alt+Enter toggles); window resolution from 960x540 to 3840x2160 plus your monitor's size; smooth or pixel-perfect (integer) scaling; VSync; FPS limit (30-240 or unlimited); FPS counter.

## Known limitations

1. **Art is generated in code, not hand-drawn final art.** It is consistent,
   readable pixel art but simpler than commercial sprite work. Cats are posed
   cut-out style rather than frame-by-frame animated.
   `docs/ASSET_PIPELINE.md` explains how to drop in real sprites.
2. **Audio is synthesized.** Sound effects and music are functional and
   varied, but they're chiptune-simple. There are no recorded cat vocals.
3. **Gamepads were tested only through the virtual-input path.** The
   development environment has no physical controllers. Button mapping
   follows Godot's SDL layout (Xbox-style names). Gamepads still need a
   hands-on check.
4. **Windows was not run during development.** It uses the same engine and
   code paths, and the export preset is included. The Linux build was
   tested.
5. **LAN only.** There's no internet matchmaking or NAT traversal. Playing over
   the internet needs a VPN that puts players on one virtual LAN (for example
   ZeroTier or Tailscale) plus direct IP. Training and Tournament are local-only
   modes. Clients see their actions with one host round-trip of delay. That's
   negligible on a LAN, but there's no client-side prediction.
6. **Networking was tested on one machine over localhost.** The automated
   tests covered:
   - a host with 1–3 clients;
   - 10-fighter matches;
   - a client leaving mid-match.

   Real multi-device Wi-Fi sessions still need a hands-on check.
7. **Split-screen is not implemented.** The design uses a shared camera on
   purpose, as the brief preferred.
8. **CPU skill is decent, not perfect.** CPUs sometimes miss tricky jumps
   (for example the Pirate Ship crow's nest) or fall into pits under pressure.
9. **No leaderboards or cloud saves.**
10. **Content still to add (the architecture supports it):**
   - More arenas: the design targets 20; 12 are done.
   - More boss types.
   - A dedicated slope or ledge-grab system. Platforms are flat; edges use wall-cling and wall-jump instead.
   - Per-weapon unique animations beyond archetype arcs.
   - More seasonal cosmetics.
11. **The UI is a fixed 480×270 canvas** scaled to the window. Text size is
   readable at 720p and above. Only the HUD has a large-size option.

## Roadmap

1. **Art pass:** replace generated sprites with hand-drawn sheets per breed;
   per-weapon swing frames; arena tilesets.
2. **Audio pass:** recorded meows and impacts; composed arena tracks.
3. **Content:** 8 more arenas toward 20, new bosses, seasonal events, more
   accessories.
4. **Gamepad UX:** button-prompt glyphs per controller type, rumble tuning.
5. **Balance:** collect telemetry from the smoke test (KOs per weapon) and
   tune outliers.
6. **Platform QA:** Windows build verification; Steam Deck layout check.
