# Sound Effects System - Implementation Guide

## ✅ Overview

Sound effects have been integrated into both the player and echo systems. The game now plays audio feedback for jumps and dashes.

## 🎵 Sound Nodes Required

Both `player.tscn` and `echo.tscn` need these AudioStreamPlayer2D nodes:

### Required Nodes
1. **JumpSound** - Plays when character jumps
2. **DashSound** - Plays when character dashes left/right

## 📁 Scene Structure

### player.tscn
```
Player (CharacterBody2D)
├── Original (AnimatedSprite2D)
├── CollisionShape2D
├── JumpSound (AudioStreamPlayer2D)  ← Add this
└── DashSound (AudioStreamPlayer2D)  ← Add this
```

### echo.tscn
```
Echo (CharacterBody2D)
├── Pastself (AnimatedSprite2D)
├── CollisionShape2D
├── JumpSound (AudioStreamPlayer2D)  ← Add this
└── DashSound (AudioStreamPlayer2D)  ← Add this
```

## 🔧 How to Set Up

### Step 1: Add Audio Nodes to player.tscn

1. Open `scenes/player.tscn`
2. Select the root Player node
3. Add child node → AudioStreamPlayer2D
4. Rename it to **"JumpSound"** (exact name)
5. In Inspector, assign your jump sound file to `Stream`
6. Repeat for **"DashSound"**

### Step 2: Add Audio Nodes to echo.tscn

1. Open `scenes/echo.tscn`
2. Select the root Echo node
3. Add child node → AudioStreamPlayer2D
4. Rename it to **"JumpSound"** (exact name)
5. In Inspector, assign your jump sound file to `Stream`
6. Repeat for **"DashSound"**

### Step 3: Configure Audio Settings (Optional)

For each AudioStreamPlayer2D:
```
Volume Db: 0.0 (adjust to taste, -10 to 10)
Pitch Scale: 1.0 (can vary for variety)
Max Distance: 2000.0 (how far sound travels)
Attenuation: 1.0 (how sound fades with distance)
```

## 🎮 How It Works

### Player (player.gd)

**Jump Sound**:
- Plays when player presses jump (W key)
- Only plays if on the ground
- Triggered in `_apply_motion()` function

**Dash Sound**:
- Plays when player presses left (A) or right (D)
- Triggered in `_process_move_press()` function
- Won't overlap if already playing

### Echo (echo.gd)

**Jump Sound**:
- Plays when echo's recorded velocity shows upward movement
- Detects transition from ground to air
- Triggered in `_apply_frame()` function

**Dash Sound**:
- Plays when echo starts dashing
- Detects transition from not dashing to dashing
- Triggered in `_apply_frame()` function

## 🎵 Sound File Recommendations

### Jump Sound
- **Type**: Short, punchy sound
- **Duration**: 0.1 - 0.3 seconds
- **Format**: .wav or .ogg
- **Examples**: 
  - "whoosh" sound
  - "boing" sound
  - Light "thump"

### Dash Sound
- **Type**: Quick movement sound
- **Duration**: 0.1 - 0.2 seconds
- **Format**: .wav or .ogg
- **Examples**:
  - "swish" sound
  - Quick "step" sound
  - "dash" whoosh

## 📂 Suggested File Structure

```
sounds/
├── player/
│   ├── jump.wav
│   └── dash.wav
└── echo/
    ├── jump.wav  (can be same or slightly different)
    └── dash.wav  (can be same or slightly different)
```

## 🎚️ Volume Balancing

### Recommended Settings

**Jump Sound**:
```gdscript
Volume Db: -5.0  # Slightly quieter
Pitch Scale: 1.0
```

**Dash Sound**:
```gdscript
Volume Db: -8.0  # Quieter than jump
Pitch Scale: 1.1  # Slightly higher pitch
```

**Echo Sounds** (optional variation):
```gdscript
Volume Db: -10.0  # Quieter than player
Pitch Scale: 0.9   # Slightly lower pitch (ghostly effect)
```

## 🔍 Code Implementation Details

### player.gd Changes

**Added @onready references**:
```gdscript
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var dash_sound: AudioStreamPlayer2D = $DashSound
```

**Added sound functions**:
```gdscript
func _play_jump_sound() -> void:
	if jump_sound != null and not jump_sound.playing:
		jump_sound.play()

func _play_dash_sound() -> void:
	if dash_sound != null and not dash_sound.playing:
		dash_sound.play()
```

**Integrated into gameplay**:
- Jump: Called when `jump_pressed` and `is_on_floor()`
- Dash: Called when left/right movement starts

### echo.gd Changes

**Added @onready references**:
```gdscript
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var dash_sound: AudioStreamPlayer2D = $DashSound
```

**Added tracking variables**:
```gdscript
var _last_was_dashing: bool = false
var _was_on_ground: bool = true
```

**Added detection logic**:
- Detects dash start (transition from not dashing to dashing)
- Detects jump (negative Y velocity while on ground)
- Plays sounds at appropriate times during playback

**Added sound functions**:
```gdscript
func _play_jump_sound() -> void:
	if jump_sound != null and not jump_sound.playing:
		jump_sound.play()

func _play_dash_sound() -> void:
	if dash_sound != null and not dash_sound.playing:
		dash_sound.play()
```

## ✅ Testing Checklist

### Player Sounds
- [ ] Jump sound plays when pressing W (on ground)
- [ ] Jump sound doesn't play when already in air
- [ ] Dash sound plays when pressing A (left)
- [ ] Dash sound plays when pressing D (right)
- [ ] Sounds don't overlap/stack

### Echo Sounds
- [ ] Echo plays jump sound at same time as original recording
- [ ] Echo plays dash sound at same time as original recording
- [ ] Echo sounds are synchronized with movements
- [ ] Multiple echoes can play sounds simultaneously

## 🐛 Troubleshooting

### No sound plays

**Check:**
1. AudioStreamPlayer2D nodes are named exactly "JumpSound" and "DashSound"
2. Sound files are assigned to the `Stream` property
3. Volume Db is not set too low (try 0.0)
4. Audio bus is not muted in Audio settings

### Sound plays but is too quiet

**Solution:**
- Increase `Volume Db` (try 0.0 to 5.0)
- Check master volume in Project Settings
- Verify sound file isn't too quiet

### Sound plays multiple times rapidly

**This is prevented by:**
```gdscript
if jump_sound != null and not jump_sound.playing:
```
The `not jump_sound.playing` check prevents overlapping.

### Echo sounds don't match player timing

**Check:**
- Echo `playback_speed` setting (default: 1.35)
- Recording captured all frames correctly
- Sound detection thresholds in `_apply_frame()`

### Sounds are delayed

**Solution:**
- Use .wav files instead of .ogg (lower latency)
- Reduce sound file size
- Check `Max Polyphony` setting (increase if needed)

## 🎨 Advanced Customization

### Pitch Variation for Variety

Add random pitch variation:
```gdscript
func _play_jump_sound() -> void:
	if jump_sound != null and not jump_sound.playing:
		jump_sound.pitch_scale = randf_range(0.9, 1.1)
		jump_sound.play()
```

### Different Sounds for Echo

Make echo sound more "ghostly":
```gdscript
# In echo.tscn, set:
Volume Db: -12.0
Pitch Scale: 0.85
# Add reverb effect via Audio Bus
```

### Footstep Sounds

Add continuous footstep sounds:
```gdscript
# In player.gd
@onready var footstep_sound: AudioStreamPlayer2D = $FootstepSound

func _physics_process(delta: float) -> void:
	# ... existing code ...
	if _is_stepping and is_on_floor():
		_play_footstep_sound()

func _play_footstep_sound() -> void:
	if footstep_sound != null and not footstep_sound.playing:
		footstep_sound.play()
```

## 📊 Performance Notes

### Impact
- **CPU**: Negligible (< 0.1% per sound)
- **Memory**: ~50KB per sound file
- **Polyphony**: Up to 32 sounds simultaneously (Godot default)

### Optimization
- Use .wav for short sounds (lower latency)
- Use .ogg for longer sounds (smaller file size)
- Keep sound files under 1 second for SFX
- Use mono instead of stereo for point sources

## 🎉 Summary

✅ **Player sounds** - Jump and dash audio feedback
✅ **Echo sounds** - Synchronized playback of recorded actions
✅ **Null-safe** - Won't crash if sound nodes missing
✅ **No overlap** - Prevents sound stacking
✅ **Easy to customize** - Adjust volume, pitch, and effects
✅ **Performance optimized** - Minimal CPU/memory impact

The sound system enhances gameplay feedback and makes the time-manipulation mechanic more satisfying!
