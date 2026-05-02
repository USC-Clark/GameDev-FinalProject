# Dungeon Door Exit System

A procedurally-generated dungeon door with magical aura animation for level exits and teleportation.

## 🚪 Quick Start

```gdscript
[node name="ExitPortal" parent="." instance=ExtResource("door")]
position = Vector2(1128, 644)
portal_type = "Exit"
door_width = 64.0
door_height = 96.0
aura_color = Color(0.95, 0.88, 0.2, 1)  # Golden
```

## 📚 Documentation

- **DUNGEON_DOOR_GUIDE.md** - Complete guide with customization options
- **DOOR_QUICK_REFERENCE.md** - Quick setup and color presets

## ✨ Features

- 🎨 Procedurally generated (no textures needed)
- 🌟 Animated magical aura with floating particles
- 🚪 Three modes: Exit, Teleporter, Decoration
- 🎯 Fully customizable colors and sizes
- ⚡ Performance optimized (60 FPS)
- ✅ Works with tutorial levels 01-10

## 🎨 Door Types

### Exit Door (Default)
Triggers level completion when player enters.

### Teleporter Door
Teleports player/echoes to another door.

### Decoration Door
Visual only, no gameplay effect.

## 🔧 Key Parameters

```gdscript
door_width: float = 64.0
door_height: float = 96.0
aura_intensity: float = 1.0
aura_speed: float = 2.0
door_color: Color = Color(0.3, 0.25, 0.2, 1)
aura_color: Color = Color(0.95, 0.88, 0.2, 1)
portal_type: String = "Exit"
```

## 📦 Files

- `portal.gd` - Main door script
- `portal.tscn` - Door scene (ready to instance)
- `DUNGEON_DOOR_GUIDE.md` - Full documentation
- `DOOR_QUICK_REFERENCE.md` - Quick reference

## 🎯 Usage in Tutorial Levels

1. Instance `portal.tscn`
2. Rename to **"ExitPortal"**
3. Set `portal_type = "Exit"`
4. Position where you want the exit
5. Done!

See guides for detailed instructions and customization options.
