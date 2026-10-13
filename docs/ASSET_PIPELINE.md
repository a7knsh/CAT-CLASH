# Asset pipeline

Cat Clash ships **no imported art, audio or font files**. Everything is
generated from code and text data when the game starts, so:

- the project runs straight from a fresh clone (`godot --path .`) with no
  editor import step;
- every asset is diff-able, reviewable text;
- art can be swapped later for hand-made sprite sheets without touching
  gameplay code (see "Replacing generated art" below).

## Pixel scale and resolution

| Item | Convention |
|------|------------|
| Base canvas | **480 × 270** (`project.godot`); stretch mode `canvas_items`, nearest filtering |
| World units | 1 unit = 1 art pixel at camera zoom 1.0 |
| Camera zoom | 0.6 – 1.6 (dynamic); arenas are 640 × 360 design units |
| Outlines | 1 px, colour `Pal.OUTLINE` (`#1a1220`); lighter outline for very dark fur |
| Fighter collision | 11 × 17 rectangle, origin at the **feet**; the same for every cat (cosmetic body types never change it) |
| Hurtbox | 12 × 18 standing, 14 × 11 crouching, 18 × 7 knocked down |

## Sprite grids (`scripts/data/sprite_art.gd`)

Weapons, accessories and UI icons are text grids.

- One character is one pixel.
- `.` is transparent.
- Every other character is a key in `SpriteArt.PALETTE`.

```gdscript
"sword": {"grip": Vector2(1, 1.5), "grid": [
    "...y............",
    "bbbygggggggggggw",
    "nnnyssssssssssw.",
    "...y............"]},
```

Rules:
- **Weapons** point to the **right**. `grip` is the pixel held by the paw.
  The factory adds a 1 px outline, so the sprite grows by 2 px.
- **Accessories** declare a `slot`:
  - `head` anchors at the top-centre of the head.
  - `face` anchors at the eye line.
  - `neck` anchors under the chin.
  - `back` anchors at the shoulders; add `"layer": "behind"` to draw it behind the body.
  - `ear` anchors at the front ear.

  `anchor` is the grid pixel that sits on the slot point.
- **Weapon skins** recolour weapons by remapping palette keys
  (`Sprites.WEAPON_SKINS`).

`Sprites.grid_texture()` caches each generated `ImageTexture`.

## Procedural cats (`scripts/core/sprites.gd`, `scripts/gameplay/cat_puppet.gd`)

Cats are not sprite sheets. `Sprites.cat_parts(skin)` paints these parts:
- head (rounded 12 × 10)
- body (15 × 8)
- leg (3 × 4)
- ear (one of 6 grids)
- tail segment colours

Each pixel's colour comes from a pattern function: `fur_color(skin, part, x, y, w, h)`. It handles tabby, spots, tuxedo, calico, Siamese, white paws, chest patch and two-tone patterns, plus shading.

`CatPuppet` then poses and layers the parts every frame. Draw order:
1. tail
2. back accessories
3. back legs
4. body
5. front legs
6. head with ears, face and accessories
7. arm and weapon
8. trail
9. status overlays

Animation states are **pose functions**, not frame lists:

| State | Pose highlights |
|-------|-----------------|
| idle | breathing, tail sway, personality loop (groom / loaf / bounce / stretch / yawn / tail flick) |
| run | 4-leg gallop phase, body bob, ears back, sprint dust |
| air | stretch on the way up, legs spread when falling |
| crouch / block | lowered body, raised guard arc |
| attack | weapon arc: anticipation (startup) → strike (active) → follow-through (recovery) |
| hitstun / tumble / knockdown / getup | lean away from the hit, spinning tumble, lying down, recovery |
| dodge | roll spin with after-images |
| stunned / frozen / bubbled | dizzy stars, ice block, bubble |
| emote | meow / hiss (fur spikes) / lick / loaf |
| victory | bounce / flex / twirl / sit / dance / wave |
| defeat | slumped, ears flat |
| spawning | drop-in, teleport beam, cardboard box, ninja smoke |

Squash and stretch come from a spring (`squash()` impulses on jump, land and hit).

## Arenas (`scripts/data/arena_defs.gd`)

Each arena entry lists:
- `solids` and one-way `platforms`
- `moving` platforms
- `ice` and `conveyor` surfaces
- `hazards`
- at least 4 `spawns` (feet positions)
- `items` drop x-positions and `powerups` points
- `props`
- a `style` for the backdrop and tile painter
- palette colours
- a `music` seed

`ArenaTiles` paints the surfaces. `ArenaBackdrop` generates seeded parallax silhouettes plus atmospheric fog, so backgrounds never look playable.

## Audio (`scripts/autoload/audio_hub.gd`, `scripts/core/music_gen.gd`)

- **Sound effects** are synthesized at startup as 22 kHz 16-bit PCM from tones
  (sine/square/pulse/triangle/saw with glides) and filtered noise. Several
  variants exist per sound, and playback adds random pitch variation. Impacts
  are layered by weapon material (metal, wood, pan, squeak, fish, bread,
  energy, glass, soft).
- **Music** is an 8-bar AABA chiptune loop (lead, bass, arpeggio and drums).
  It is rendered on a worker thread from `{tempo, root, scale, seed}`. Every
  arena has its own seed.

## Naming conventions

- Weapon, arena, mode and cosmetic IDs: lowercase `snake_case`
  (`giant_spoon`).
- Sprite grid keys match their weapon or accessory IDs.
- Data files live in `scripts/data/*_defs.gd`, one catalogue per file.

## Replacing generated art

Generated art is functional placeholder-quality pixel art, not final
hand-drawn work. To use real sprite sheets:
1. Add PNGs under `assets/` (Godot imports them).
2. Change `Sprites.weapon_texture()`, `accessory_texture()` or
   `icon_texture()` to `load()` a PNG when one exists. Keep the grip and
   anchor metadata.
3. For cats, replace `CatPuppet._draw()` part textures with per-part
   sprites. The pose system already moves parts independently, so cut-out
   style art drops straight in.
