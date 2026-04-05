# 🚲 Cozy Delivery Co. — Godot 4 Project

A cozy top-down delivery game built in **Godot 4.3**.

## How to Open

1. Download and install **Godot 4.3** (standard version) from https://godotengine.org
2. Open Godot, click **Import**
3. Navigate to this folder and select `project.godot`
4. Click **Import & Edit**, then press **F5** (or the ▶ Play button) to run

## Project Structure

```
cozy_delivery/
├── project.godot          ← Godot project config + input map
├── scenes/
│   ├── Main.tscn          ← Root scene (entry point)
│   ├── Player.tscn        ← Kid character (foot + bike)
│   ├── WorldGenerator.tscn← Town map + buildings + pickups
│   ├── Building.tscn      ← Individual building node
│   ├── Pickup.tscn        ← Speed boost / trap collectible
│   ├── ThrownPackage.tscn ← Package projectile arc
│   ├── HUD.tscn           ← On-screen UI
│   └── TitleScreen.tscn   ← Start screen
└── scripts/
    ├── GameManager.gd     ← Autoload singleton (cash, packages, day)
    ├── Main.gd            ← Scene orchestrator + day cycle
    ├── Player.gd          ← Movement, bike physics, throwing
    ├── FootSprite.gd      ← Procedural on-foot character drawing
    ├── BikeSprite.gd      ← Procedural bicycle + rider drawing
    ├── Building.gd        ← Building draw + delivery logic
    ├── Pickup.gd          ← Pickup collision + effect trigger
    ├── PickupSprite.gd    ← Pickup visual (pulsing square/circle)
    ├── ThrownPackage.gd   ← Arcing package projectile
    ├── WorldGenerator.gd  ← Procedural town generation
    ├── HUD.gd             ← UI wiring to GameManager signals
    └── TitleScreen.gd     ← Title screen logic
```

## Controls

| Key | Action |
|-----|--------|
| `W A S D` or Arrow Keys | Move / Steer |
| `F` | Mount / Dismount bicycle |
| `SPACE` | Toss package at nearest target |

### On Foot
- WASD moves in 8 directions

### On Bicycle
- `↑ / W` — Accelerate forward
- `↓ / S` — Brake (then reverse once stopped)
- `← / →` or `A / D` — Steer left/right
- Speed-scaled turning (tighter at lower speed)

## Gameplay

Each day, **5 random buildings** are marked with a pulsing orange arrow.
Get close to a target and press `SPACE` to toss your package — it arcs
through the air and lands at the door. Collect **blue squares** for a
speed boost and dodge **red circles** to avoid being slowed. Complete
all deliveries to start the next day and earn more cash!

## Extending the Game

- **Add sprites**: Replace `FootSprite.gd` / `BikeSprite.gd` draw calls with real `Sprite2D` nodes + spritesheets
- **Add sound**: Hook `AudioStreamPlayer` nodes to GameManager signals
- **Add a timer**: Add a countdown in HUD.gd per day
- **More pickups**: Extend `Pickup.Kind` enum and add new effects in `Player.gd`
- **NPC pedestrians**: Add `CharacterBody2D` nodes with simple patrol paths in WorldGenerator
