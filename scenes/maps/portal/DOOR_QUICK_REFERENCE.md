# Dungeon Door - Quick Reference

## 🚪 What Changed

**Before**: Circular portal with swirling rings
**After**: Dungeon door with magical aura

## ⚡ Quick Setup

```gdscript
[node name="ExitPortal" parent="." instance=ExtResource("door_scene")]
position = Vector2(1128, 644)
portal_type = "Exit"
door_width = 64.0
door_height = 96.0
aura_color = Color(0.95, 0.88, 0.2, 1)  # Golden
```

## 🎨 Color Presets

### Golden (Default)
```gdscript
aura_color = Color(0.95, 0.88, 0.2, 1)
```

### Blue
```gdscript
aura_color = Color(0.3, 0.7, 1, 1)
```

### Green
```gdscript
aura_color = Color(0.5, 1, 0.3, 1)
```

### Red
```gdscript
aura_color = Color(1, 0.3, 0.2, 1)
```

### Purple
```gdscript
aura_color = Color(0.8, 0.3, 1, 1)
```

## 📐 Size Presets

### Small (Hidden)
```gdscript
door_width = 48.0
door_height = 72.0
```

### Normal (Default)
```gdscript
door_width = 64.0
door_height = 96.0
```

### Large (Boss)
```gdscript
door_width = 96.0
door_height = 128.0
```

## ✨ Intensity Presets

### Subtle
```gdscript
aura_intensity = 0.5
```

### Normal
```gdscript
aura_intensity = 1.0
```

### Bright
```gdscript
aura_intensity = 1.5
```

### Intense
```gdscript
aura_intensity = 2.0
```

## 🎯 Door Components

```
┌─────────────────┐
│  Stone Frame    │  ← frame_color
│  ┌───────────┐  │
│  │ Wood Door │  │  ← door_color
│  │  ═══════  │  │  ← Metal bands
│  │     ○     │  │  ← Door handle
│  │  ═══════  │  │
│  └───────────┘  │
└─────────────────┘
	✨ Aura ✨       ← aura_color + particles
```

## 🔧 All Parameters

```gdscript
# Size
door_width: float = 64.0
door_height: float = 96.0

# Animation
aura_intensity: float = 1.0
aura_speed: float = 2.0
glow_pulses: int = 3

# Colors
door_color: Color = Color(0.3, 0.25, 0.2, 1)      # Dark wood
frame_color: Color = Color(0.5, 0.45, 0.35, 1)    # Stone
aura_color: Color = Color(0.95, 0.88, 0.2, 1)     # Golden
glow_color: Color = Color(1, 0.9, 0.3, 0.3)       # Glow

# Behavior (same as portal)
portal_type: String = "Exit"
destination_portal: NodePath = NodePath()
teleport_cooldown: float = 0.5
```

## ✅ Checklist

- [ ] Node named "ExitPortal"
- [ ] `portal_type = "Exit"`
- [ ] Position set correctly
- [ ] Colors match your theme
- [ ] Size appropriate for level
- [ ] Test: Walk into door → Level completes

## 🎨 Theme Examples

### Tutorial Level
```gdscript
aura_color = Color(0.95, 0.88, 0.2, 1)  # Friendly golden
aura_intensity = 1.2
```

### Ice Level
```gdscript
door_color = Color(0.25, 0.3, 0.35, 1)
aura_color = Color(0.5, 0.8, 1, 1)
aura_intensity = 1.5
```

### Fire Level
```gdscript
door_color = Color(0.35, 0.2, 0.15, 1)
aura_color = Color(1, 0.5, 0.2, 1)
aura_intensity = 1.8
```

### Shadow Level
```gdscript
door_color = Color(0.15, 0.15, 0.2, 1)
aura_color = Color(0.6, 0.3, 0.8, 1)
aura_intensity = 1.0
```

---

**Full Guide**: See `DUNGEON_DOOR_GUIDE.md`
