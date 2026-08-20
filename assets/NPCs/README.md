# NPC Walk-Cycle Sprites

Drop a sprite sheet here named after the NPC's **id** (see `scripts/NPCRegistry.gd`):

```
assets/NPCs/<npc_id>.png
```

e.g. `assets/NPCs/doctor_carrington.png`, `assets/NPCs/spider.png`.

That's all the wiring needed — the NPC switches from the procedural drawing to
your art automatically the next time the game runs. NPCs with no sheet here keep
the procedural look, so you can convert the cast one character at a time.

## Sheet layout

A grid of frames: **one row per facing, one column per walk frame.**

```
        col0    col1    col2    col3     <- walk frames
row 0   down    down    down    down
row 1   left    left    left    left
row 2   right   right   right   right
row 3   up      up      up      up
```

Defaults are **32×32 px frames, 4 frames per row**. The walk animation advances
one column about every 0.18 s while the NPC is moving, and rests on column 0
when standing still.

### Fewer rows is fine

- **1 row (down only)** — used for every facing.
- **2 rows (down, left)** — `right` is drawn as a mirrored `left` automatically.

Only add the `up` row if you want a distinct back view.

## Adjusting per NPC

If a character's art isn't 32×32 or 4 frames, set it on that NPC's definition in
`NPCRegistry.gd`:

```gdscript
def.frame_size    = Vector2i(48, 48)   # size of one frame
def.frame_count   = 6                  # columns per row
def.sprite_offset = Vector2(0, -12)    # nudge art so the feet meet the shadow
def.sprite_path   = "res://assets/NPCs/custom_name.png"   # optional override
```

`sprite_offset` shifts the art relative to the NPC's collision point (its feet).
Increase the negative Y if the character floats or sinks into the ground.

## Import settings

For crisp pixel art, select the PNG in Godot and set
**Import → Filter → Off**, then Reimport. (The project already defaults texture
filtering off, so this usually just works.)
