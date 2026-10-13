# Testing checklist

## Automated (run before every commit)

| Check | Command | Expectation |
|-------|---------|-------------|
| Parse check | `godot --headless --path . -- --check` | `checked N scripts`, no `SCRIPT ERROR` |
| Smoke test | `godot --headless --path . --fixed-fps 60 -- --smoke` | all cases `PASS`, exit code 0 |
| One mode only | `... -- --smoke --only=capture` | handy while iterating |
| Debug trace | `CAT_DEBUG=1 godot ... -- --smoke --only=koth` | prints positions, states and goals every 5 s |
| Screenshots | `godot --path . --fixed-fps 60 --resolution 960x540 -- --shots` | PNGs in `user://shots` (Linux: `~/.local/share/CatClash/shots`) |
| LAN, 1 client | `-- --nettest=host` then `-- --nettest=client` | both print `PASS` |
| LAN, 3 clients | `-- --nettest=host --clients=3`, then start 3 clients | host PASS, 3/3 remote cats moved |
| LAN dropout | `-- --nettest=host --clients=1 --expect-leave`, then `-- --nettest=client --leave-after=12` | the left player's cat is taken over by a CPU and the match finishes |
| Benchmark | `godot --path . -- --bench` | average frame time well under 16.6 ms |

The smoke test covers:
- **All 13 modes** (tournament duels run through the FFA/duel and stock
  paths) on all **12 arenas**, with **1, 2, 3 and 4** bot fighters on hard
  difficulty. Each match must finish within 6 simulated minutes.
- **Health checks** every frame: no NaN positions, nobody embedded in level
  geometry for more than 3 s, and no projectile overflow.
- **Save data:** export a backup, list backups, import a backup, and a
  preset create/read/delete round-trip.
- **Input pipeline:** a virtual gamepad drives a human-controlled cat to run,
  jump, attack a dummy (it must take damage), pick up a sword and throw it.

## Manual checklist

### LAN play (2+ real devices)
- [ ] The host appears in the joiner's GAMES ON YOUR NETWORK list within about 2 s
- [ ] Join by IP works when broadcast is blocked
- [ ] Two players on one client device (keyboard halves) plus pads on others, 10 fighters in total
- [ ] The host changes mode or CPUs in the lobby; clients see it live. Clients see "HOST IS SETTING UP" during setup.
- [ ] Mid-match: effects, sounds, hazards, items, boss and HUD all match the host
- [ ] Close a client mid-match: its cat becomes a CPU. Close the host: clients return to the menu.
- [ ] Results: the host chooses REMATCH or BACK TO LOBBY and every device follows
- [ ] Firewall prompt on Windows: allowing private networks fixes discovery

### Players and devices
- [ ] 1 player plus CPUs (keyboard left)
- [ ] 2 players on one keyboard (WASD side + arrows/numpad side) at the same time, with no blocked inputs when both mash
- [ ] 2 gamepads + 2 keyboard halves = 4 players
- [ ] Mixed: 1 keyboard half + 3 pads
- [ ] Join/leave in the lobby (JUMP to join, THROW to leave), add/remove CPUs (HEAVY/TAUNT)
- [ ] Unplug a pad mid-match: the game pauses with "CONTROLLER DISCONNECTED". Test both continuing with a CPU and resuming after reconnecting.
- [ ] Rebind a key, then rebind it to a key used by another action (the bindings swap). Reset a device to defaults.
- [ ] Mouse navigation in menus (hover, click, wheel, left/right click on options)

### Combat feel
- [ ] Light combo (3 hits) chains only when the first hit lands
- [ ] Heavy charge (hold) glows and hits harder; dash heavy while sprinting lunges further
- [ ] Up attack launches, down-air spikes, neutral-air spins
- [ ] Block reduces damage; guard breaks when spammed
- [ ] Parry (tap block just before a hit) stuns melee attackers and reflects projectiles
- [ ] Frying pan swings return projectiles
- [ ] Tech: press block when slammed into the floor or a wall
- [ ] Hit-stop, screen shake (can be turned off), damage numbers (toggle), hit sparks
- [ ] Knockback grows as HP drops; a strong hit at low HP rings the target out
- [ ] Repeated jabs can't lock a target forever (hitstun decays over a combo)
- [ ] Spawn protection blinks (or stays steady with reduce-flashing on)

### Weapons and items
- [ ] Pick up, throw (up/forward/down), drop (down + throw on the ground)
- [ ] A thrown weapon damages and bounces; the plate shatters
- [ ] Ammo counts down; empty guns are tossed away
- [ ] Boomerang returns; rocket splash includes self-damage; freeze, bubble, burn and slow effects
- [ ] Gravity gun pull and push; lightning chains; void orb pulls items and cats
- [ ] Tiger potion makes the cat bigger and stronger for 8 s
- [ ] Rubber chicken: every 5th hit is a MEGA SQUEAK
- [ ] Crates break into weapons or power-ups; props (pipe, plate, torch, broom) break
- [ ] Power-ups: all 11 apply; they can be disabled in setup

### Modes
- [ ] FFA, Teams, Duel: rounds-to-win, draw on simultaneous KO, round banners
- [ ] Stock, Timed (sudden death on a tie), Roulette swaps, Chaos modifiers
- [ ] KotH: the zone moves; contested zones score nothing
- [ ] Capture the Fish: pick up, carry (slower), throw to a teammate, score at your basket; the fish returns if left alone
- [ ] Survival co-op and compete; Boss Battle phase 2, minions, win and lose
- [ ] Training: weapon racks restock, dummy behaviours, spawn weapon, reset positions, frame data, milestones
- [ ] Tournament with 4 and 8 entrants: watch or simulate CPU matches, champion screen

### Arenas
- [ ] Every arena: spawns are safe for 4 players and the camera keeps everyone visible (off-screen bubbles)
- [ ] Hazards are telegraphed: lava warning plus banner, trapdoor "!", laser dashes, crusher shake, icicle shake, cannon "!", haunted circle
- [ ] Hazards off means none of them run
- [ ] Ice is slippery, the conveyor carries you, low gravity in space, moving platforms carry cats

### Progression and saves
- [ ] Yarn is earned after matches; shop purchases unlock cosmetics
- [ ] Achievements trigger toasts and unlock their cosmetic rewards
- [ ] Daily challenges reset with the date
- [ ] Profiles: create, rename, delete; stats update after matches
- [ ] Backup, restore and reset (requires confirming three times)
- [ ] Corrupt `save.json` by hand: the game restores from `save.json.bak` and the title screen says so

### Accessibility and settings
- [ ] Colour-blind palette changes player and team colours; shapes stay
- [ ] Reduce flashing, simplified effects, HUD size, damage numbers
- [ ] Volume sliders, fullscreen (F11 / Alt+Enter), window scale, VSync

### Platforms
- [ ] Linux build (export preset "Linux")
- [ ] Windows build (export preset "Windows")
