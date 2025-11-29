import os
import sys
import django
import numpy as np
import json

# Setup Django environment
sys.path.append(os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'secure_step_backend.settings')
django.setup()

from emergency.ml_predictor import MLPredictor

def create_dummy_movement_data():
    """Create dummy movement data: 50 frames x 12 features"""
    # Features: gyroX, gyroY, gyroZ, accelX, accelY, accelZ, pitch, roll, age, height, weight, bmi
    data = []
    for i in range(50):
        frame = [
            np.random.uniform(-2, 2),  # gyroX
            np.random.uniform(-2, 2),  # gyroY
            np.random.uniform(-2, 2),  # gyroZ
            np.random.uniform(-10, 10),  # accelX
            np.random.uniform(-10, 10),  # accelY
            np.random.uniform(-10, 10),  # accelZ
            np.random.uniform(-90, 90),  # pitch
            np.random.uniform(-180, 180),  # roll
            25.0,  # age
            170.0,  # height
            70.0,  # weight
            24.2  # bmi
        ]
        data.append(frame)
    return data

def test():
    print("=" * 60)
    print("TESTING MOVEMENT PREDICTION")
    print("=" * 60)
    
    print("\n1. Creating dummy movement data (50 frames x 12 features)...")
    movement_data = create_dummy_movement_data()
    print(f"   ✓ Created {len(movement_data)} frames")
    
    print("\n2. Initializing MLPredictor...")
    try:
        predictor = MLPredictor.get_instance()
        print("   ✓ MLPredictor initialized")
    except Exception as e:
        print(f"   ✗ Failed: {e}")
        return

    print("\n3. Testing predict() method...")
    try:
        result = predictor.predict(movement_data)
        print("   ✓ Prediction successful!")
        print(f"\n   RESULTS:")
        print(f"   - Action: {result['action']}")
        print(f"   - Confidence: {result['confidence']:.2%}")
        print(f"   - Is Threat: {result['is_threat']}")
        print(f"   - Status: {result['status']}")
        
    except Exception as e:
        print(f"   ✗ Failed during prediction: {e}")
        import traceback
        traceback.print_exc()

    print("\n" + "=" * 60)
    print("TEST COMPLETE")
    print("=" * 60)

if __name__ == "__main__":
    test()
