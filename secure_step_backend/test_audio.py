import os
import sys
import django
import numpy as np
import scipy.io.wavfile as wav

# Setup Django environment
sys.path.append(os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'secure_step_backend.settings')
django.setup()

from emergency.ml_predictor import MLPredictor

def create_dummy_audio(filename='test_audio.wav'):
    sample_rate = 22050
    duration = 2 # seconds
    # Generate random noise
    data = np.random.uniform(-1, 1, sample_rate * duration)
    wav.write(filename, sample_rate, data.astype(np.float32))
    return filename

def test():
    print("1. Creating dummy audio file...")
    audio_file = create_dummy_audio()
    
    print("2. Initializing MLPredictor...")
    try:
        predictor = MLPredictor.get_instance()
        print("   Success: MLPredictor initialized")
    except Exception as e:
        print(f"   Failed: {e}")
        return

    print("3. Testing predict_audio...")
    try:
        result = predictor.predict_audio(audio_file)
        print("   Prediction Result:")
        print(f"   - Is Threat: {result['is_threat']}")
        print(f"   - Confidence: {result['confidence']}")
        print(f"   - Status: {result['status']}")
        
        if 'error' in result:
            print(f"   - Error: {result['error']}")
            
    except Exception as e:
        print(f"   Failed during prediction: {e}")
    finally:
        if os.path.exists(audio_file):
            os.remove(audio_file)

if __name__ == "__main__":
    test()
