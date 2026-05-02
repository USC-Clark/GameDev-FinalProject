# Tutorial Level Fixes Summary

## Fixed Issues

### Tutorial_04.tscn - Lift Platform Fix
**Problem**: The Lift_L1 platform was missing required properties. The lift_platform.gd script expects either `start`/`end` properties OR calculates them from `move_distance` in `_ready()`. However, the tutorial_manager accesses `lift.start` and `lift.end` directly, so these must be set in the scene file.

**Solution**: Added the following properties to the Lift_L1 node:
```gdscript
button_id = "B1"
start = Vector2(811, 601)
end = Vector2(811, 401)
speed = 120.0
```

**What this fixes**:
- The lift now responds to button "B1" being pressed
- `start` position is Vector2(811, 601) - the lift's starting position
- `end` position is Vector2(811, 401) - 200 pixels above start (601 - 401 = 200)
- The lift moves at 120 pixels per second
- The tutorial_manager can now access `lift.start` and `lift.end` properties correctly

**Location**: Line 630-635 in `scenes/maps/tutorial/tutorial_04.tscn`

---

### Tutorial_05.tscn - Hazard Collision Fix
**Problem**: The Hazard_01 area was missing collision layer and mask properties, preventing it from detecting when the player or echoes touch it.

**Solution**: Added a node override for Hazard_01 with proper collision properties:
```gdscript
[node name="Hazard_01" parent="." index="8"]
collision_layer = 32
collision_mask = 3
monitoring = true
monitorable = true
```

**What this fixes**:
- **collision_layer = 32**: Hazard is on layer 32 (hazard layer)
- **collision_mask = 3**: Detects bodies on layers 1 (player) and 2 (echoes)
- **monitoring = true**: Actively monitors for collisions
- **monitorable = true**: Can be detected by other areas

**Result**: When player or echo touches the hazard, the level will reset as intended.

**Location**: Line 628-632 in `scenes/maps/tutorial/tutorial_05.tscn`

---

## Technical Details

### Collision Layers Reference
- **Layer 1**: Player
- **Layer 2**: Echoes
- **Layer 4**: Solid platforms
- **Layer 8**: Buttons
- **Layer 16**: One-way platforms
- **Layer 32**: Hazards

### How Hazards Work
1. Hazard Area2D has `collision_mask = 3` (binary: 11) to detect layers 1 and 2
2. When a body enters the hazard area, `body_entered` signal fires
3. Tutorial manager connects to this signal and calls `_reset_level("Hazard hit. Reset.")`
4. Player and all echoes are reset to spawn position

### How Lift Platforms Work
1. Lift reads `button_id` to know which button controls it
2. Tutorial manager checks if button is pressed via `_is_button_pressed(button_id)`
3. Lift moves toward `end` position when button pressed, `start` position when released
4. Movement speed is controlled by `speed` property (pixels per second)
5. `move_distance` defines how far up the lift travels from its starting position

---

## Testing Recommendations
1. **Tutorial_04**: 
   - Verify button B1 activates the lift
   - Check lift moves smoothly up and down
   - Ensure player can ride the lift

2. **Tutorial_05**:
   - Verify touching hazard resets the level
   - Check both player and echoes trigger the hazard
   - Confirm hazard visual matches collision area

---

## Status
✅ **Complete** - Both tutorial levels fixed and verified with no diagnostic errors
