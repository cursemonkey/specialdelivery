# NPC Dialogue Portraits

Drop one image per NPC here, named by the NPC's **id** (see `scripts/NPCRegistry.gd`):

```
assets/Portraits/<npc_id>.jpg
```

Example — Mayor Henderson (id `mayor_henderson`):

```
assets/Portraits/mayor_henderson.jpg
```

That's all the wiring needed. `NPCDefinition.portrait_texture()` loads
`res://assets/Portraits/<id>.jpg` by convention, so a new NPC's portrait shows
up the moment you add the file — no code change. An NPC with no file here simply
shows no portrait slot. To point an NPC at a different file, set
`portrait_path` on its definition.

## Slot size

The portrait sits to the right of the dialogue box (no frame/background behind
it) and stands 20% taller than the box. At the game's base 1152×648 viewport
that slot is roughly:

- **~173 × 260 px** (aspect ~2 : 3, i.e. taller than wide)

Author at ~2× for crispness (e.g. **~346 × 520 px**). The image is scaled to fit
and centered (aspect preserved), so any size works — match the ~2:3 slot ratio
to avoid empty padding. There's no background panel, so the whole image is
visible; JPGs are opaque rectangles (no transparency).

## Future: expressions / moods

When we add per-line moods, the convention will extend to
`assets/Portraits/<npc_id>_<mood>.png` (e.g. `mayor_henderson_happy.png`), with
`<npc_id>.png` as the neutral default. So it's safe to author a few Mayor
Henderson pieces now (neutral, happy, stern) — keep the neutral one named
exactly `mayor_henderson.png` and it will be used today.
