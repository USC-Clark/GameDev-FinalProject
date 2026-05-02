# Sound Effects - Quick Setup Guide

## 🚀 3-Step Setup

### Step 1: Add Nodes to player.tscn
```
1. Open scenes/player.tscn
2. Right-click Player node → Add Child Node
3. Search "AudioStreamPlayer2D" → Create
4. Rename to "JumpSound"
5. Repeat for "DashSound"
```

### Step 2: Add Nodes to echo.tscn
```
1. Open scenes/echo.tscn
2. Right-click Echo node → Add Child Node
3. Search "AudioStreamPlayer2D" → Create
4. Rename to "JumpSound"
5. Repeat for "DashSound"
```

### Step 3: Assign Sound Files
```
1. Select JumpSound node
2. In Inspector → Stream → Load your jump.wav file
3. Select DashSound node
4. In Inspector → Stream → Load your dash.wav file
5. Repeat for both player.tscn and echo.tscn
```

## ✅ That's It!

The scripts are already updated. Just add the nodes and assign sounds.

---

## 🎵 Node Names (Must Be Exact)

- `JumpSound` ← Plays on jump
- `DashSound` ← Plays on dash

## 📁 Scene Structure

```
Player/Echo (CharacterBody2D)
├── AnimatedSprite2D
├── CollisionShape2D
├── JumpSound (AudioStreamPlayer2D)  ← Add
└── DashSound (AudioStreamPlayer2D)  ← Add
```

## 🎚️ Recommended Settings

```
JumpSound:
  Volume Db: -5.0
  Pitch Scale: 1.0

DashSound:
  Volume Db: -8.0
  Pitch Scale: 1.1
```

## 🔍 Verify It Works

1. Run the game
2. Press W → Should hear jump sound
3. Press A/D → Should hear dash sound
4. Record an echo → Echo should play same sounds

---

**Full Guide**: See `SOUND_EFFECTS_GUIDE.md` for details
