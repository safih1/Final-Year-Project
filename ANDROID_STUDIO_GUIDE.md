   - Click "Open" and navigate to:
     ```
     c:\Users\safii\StudioProjects\SecureStep\secure_step
     ```

2. **Wait for Gradle Sync**
   - Android Studio will automatically sync Gradle
   - Wait for "Gradle build finished" message
   - This may take a few minutes on first run

3. **Select Device**
   - In the toolbar, select your device: **vivo 1933**
   - It should appear in the device dropdown

4. **Run the App**
   - Click the green "Run" button (▶️) or press `Shift + F10`
   - Android Studio will build and install the app
   - The app will launch automatically on your phone

5. **Grant Permissions**
   - When the app launches, grant all requested permissions:
     - Microphone
     - Location
     - Storage
     - Notifications

## Testing the App

### Manual Test
1. Navigate to "Guardian Mode" screen
2. Click "Record 10s Manually (Movement + Audio)"
3. Move your phone around
4. Wait ~10 seconds for predictions

### Background Service Test
1. Enable "Background Guardian" toggle
2. Say "Help" clearly
3. Verify recording starts automatically
4. Check for threat alerts

## Troubleshooting

**If build fails in Android Studio:**
- Check the "Build" tab at the bottom for detailed errors
- Try: Build → Clean Project, then Build → Rebuild Project

**If app can't connect to backend:**
- Verify backend is running: `http://192.168.1.18:8000`
- Ensure phone and computer are on same network
- Check firewall isn't blocking port 8000

**If permissions are denied:**
- Go to phone Settings → Apps → secure_step → Permissions
- Enable all permissions manually

## Backend Endpoints
- Movement: `http://192.168.1.18:8000/api/emergency/predict/`
- Audio: `http://192.168.1.18:8000/api/emergency/predict-audio/`

## What to Expect
- Movement predictions: Shows action type, confidence, threat status
- Audio predictions: Shows threat/safe status
- Combined results displayed on Detection Screen
- Alert dialogs appear for detected threats
