# SecureStep - Setup & Testing Guide

## Quick Start

### Backend Setup

1. **Navigate to backend directory**
   ```bash
   cd secure_step_backend
   ```

2. **Install dependencies** (if not already installed)
   ```bash
   pip install -r requirements.txt
   ```

3. **Run migrations**
   ```bash
   python manage.py migrate
   ```

4. **Start Django server**
   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```

5. **Verify ML models loaded** - Check console output for:
   ```
   Model loaded from ...ml_models/bilstm_action_model.h5
   Scaler loaded from ...ml_models/scaler.pkl
   Label encoder loaded from ...ml_models/label_encoder.pkl
   Audio model loaded from ...ml_models/xgboost_threat_model.pkl
   Audio scaler loaded from ...ml_models/feature_scaler.pkl
   ```

### Flutter App Setup

1. **Navigate to Flutter directory**
   ```bash
   cd secure_step
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Update API URL** (if needed)
   - Edit `lib/services/movement_service.dart` line 24
   - Edit `lib/services/audio_service.dart` line 17
   - Replace `192.168.1.4` with your computer's IP address

4. **Run the app**
   ```bash
   flutter run
   ```

## Testing Procedures

### Backend Tests

#### Test Movement Prediction
```bash
cd secure_step_backend
python test_movement.py
```

**Expected Output:**
```
TESTING MOVEMENT PREDICTION
✓ Created 50 frames
✓ MLPredictor initialized
✓ Prediction successful!

RESULTS:
- Action: [action name]
- Confidence: XX%
- Is Threat: true/false
- Status: THREAT/SAFE
```

#### Test Audio Prediction
```bash
python test_audio.py
```

**Expected Output:**
```
✓ Prediction Result:
- Is Threat: true/false
- Confidence: X.XX
- Status: THREAT/SAFE
```

### Flutter App Tests

#### Manual Movement + Audio Test

1. Open the app
2. Navigate to "Guardian Mode" (Detection Screen)
3. Click "Record 10s Manually (Movement + Audio)"
4. Move the phone around during recording
5. Wait for predictions to appear (~10 seconds)

**Expected Results:**
- Movement prediction shows action, confidence, threat status
- Audio prediction shows threat status
- If threat detected, alert dialog appears

#### Background Service Test

1. Enable "Background Guardian" toggle
2. Check notification appears: "Listening for 'Help' trigger..."
3. Say "Help" clearly
4. Verify recording starts automatically
5. Wait for predictions
6. Check threat alerts

## Troubleshooting

### Backend Issues

**Models not loading:**
- Verify all 5 files exist in `ml_models/` directory
- Check file permissions
- Review console error messages

**Prediction errors:**
- Check data format matches expected shape
- Verify TensorFlow and XGBoost versions
- Check librosa can read audio file format

### Flutter App Issues

**Network errors:**
- Verify Django server is running
- Check IP address in service files
- Ensure phone and computer on same network
- Check firewall settings

**Permission errors:**
- Grant all requested permissions
- Check AndroidManifest.xml has all permissions
- Restart app after granting permissions

**Background service not working:**
- Check battery optimization settings
- Verify foreground service permission granted
- Check notification permission granted
- Review logcat for errors

**Voice detection not working:**
- Grant microphone permission
- Speak clearly and loudly
- Check speech_to_text initialization
- Review background service logs

## Network Configuration

### Finding Your IP Address

**Windows:**
```bash
ipconfig
```
Look for "IPv4 Address" under your active network adapter

**Mac/Linux:**
```bash
ifconfig
```
Look for "inet" address

### Updating API URLs

Update these files with your IP:
- `secure_step/lib/services/movement_service.dart` (line 24)
- `secure_step/lib/services/audio_service.dart` (line 17)

Format: `http://YOUR_IP:8000/api/emergency/predict/`

## System Requirements

### Backend
- Python 3.8+
- 4GB RAM minimum
- TensorFlow 2.15+
- XGBoost 2.0+

### Flutter App
- Android 8.0+ (API level 26+)
- Microphone
- Accelerometer & Gyroscope sensors
- Internet connection
