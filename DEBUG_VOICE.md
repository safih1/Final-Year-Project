# Voice Detection Not Working - Debugging Checklist

## Issue: Saying "Help" does nothing

### Root Causes Found:

1. **CRITICAL BUG in `background_service.dart` (lines 93-184)**
   - **Lines 94-122**: When threat IS detected (`if (isThreat)`) → Only shows notification
   - **Lines 124-184**: When NO threat detected (`else`) → Triggers emergency
   - **THIS IS BACKWARDS!**

2. **Potential Issues:**
   - Guardian Mode not activated
   - Microphone permission not granted
   - Speech recognition not initialized
   - Background service not running

## Step-by-Step Debugging:

### 1. Check Guardian Mode Activation
Did you click "Activate Guardian Mode" button in the app?
Expected: Green SnackBar "Guardian Mode Activated"

### 2. Check Permissions
Settings → Apps → SecureStep → Permissions
Required: Microphone (ALLOW), Location (ALLOW ALL THE TIME)

### 3. Check Logcat Output
Expected logs when saying "Help":
```
🎤 Background service started
🎤 Starting to listen for "Help"...
🎤 Heard: "help"
🚨 WAKE WORD DETECTED
```

### 4. Test Voice Recognition
Say these wake words (loud and clear):
- "Help"
- "Emergency"
- "Danger"

## Next Steps: Fix background_service.dart

The logic is inverted. Lines 94-184 need to be swapped.
