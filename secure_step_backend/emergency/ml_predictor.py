import os
import pickle
import numpy as np
import tensorflow as tf
import xgboost as xgb
import librosa
from scipy import stats
import pandas as pd
from django.conf import settings

# ============================================================================
# OPTIMIZED FEATURE EXTRACTION
# ============================================================================
class FastAudioFeatureExtractor:
    def __init__(self, sample_rate=22050, duration=5):
        self.sample_rate = sample_rate
        self.duration = duration

    def load_audio(self, file_path):
        """Load audio file with duration limit"""
        try:
            audio, sr = librosa.load(file_path, sr=self.sample_rate, duration=self.duration)
            return audio, sr
        except Exception as e:
            return None, None

    def extract_statistical_features(self, data, prefix=""):
        """Extract statistical features quickly"""
        return {
            f'{prefix}_mean': np.mean(data),
            f'{prefix}_std': np.std(data),
            f'{prefix}_min': np.min(data),
            f'{prefix}_max': np.max(data),
            f'{prefix}_median': np.median(data),
            f'{prefix}_q25': np.percentile(data, 25),
            f'{prefix}_q75': np.percentile(data, 75),
            f'{prefix}_skew': stats.skew(data),
            f'{prefix}_kurtosis': stats.kurtosis(data),
        }

    def extract_all_features(self, file_path):
        """Extract comprehensive audio features - OPTIMIZED"""
        audio, sr = self.load_audio(file_path)
        if audio is None:
            return None

        features = {}

        # 1. BASIC AUDIO STATISTICS
        features.update(self.extract_statistical_features(audio, 'audio'))

        # 2. SPECTRAL FEATURES
        spec_cent = librosa.feature.spectral_centroid(y=audio, sr=sr)[0]
        features.update(self.extract_statistical_features(spec_cent, 'spec_cent'))

        spec_roll = librosa.feature.spectral_rolloff(y=audio, sr=sr)[0]
        features.update(self.extract_statistical_features(spec_roll, 'spec_roll'))

        spec_bw = librosa.feature.spectral_bandwidth(y=audio, sr=sr)[0]
        features.update(self.extract_statistical_features(spec_bw, 'spec_bw'))

        # 3. MFCC FEATURES
        mfccs = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=13)
        for i in range(13):
            features.update(self.extract_statistical_features(mfccs[i], f'mfcc_{i}'))

        # 4. CHROMA FEATURES
        chroma = librosa.feature.chroma_stft(y=audio, sr=sr)
        features['chroma_mean'] = np.mean(chroma)
        features['chroma_std'] = np.std(chroma)
        features['chroma_max'] = np.max(chroma)

        # 5. ZERO CROSSING RATE
        zcr = librosa.feature.zero_crossing_rate(audio)[0]
        features.update(self.extract_statistical_features(zcr, 'zcr'))

        # 6. RMS ENERGY
        rms = librosa.feature.rms(y=audio)[0]
        features.update(self.extract_statistical_features(rms, 'rms'))

        # 7. TEMPO
        try:
            tempo, _ = librosa.beat.beat_track(y=audio, sr=sr)
            if isinstance(tempo, np.ndarray):
                features['tempo'] = float(tempo[0]) if len(tempo) > 0 else 0.0
            else:
                features['tempo'] = float(tempo) if tempo else 0.0
        except:
            features['tempo'] = 0.0

        return features

class MLPredictor:
    _instance = None
    _model = None
    _scaler = None
    _label_encoder = None
    _audio_model = None
    _audio_scaler = None
    _audio_encoder = None
    
    THREAT_LABELS = ['bear hug', 'dragging', 'gutt kick', 'hair pull', 
                     'knee pressure', 'neck grab', 'punch', 'push', 
                     'slap', 'wrist grab']

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def __init__(self):
        self.load_models()

    def load_models(self):
        try:
            base_path = os.path.join(settings.BASE_DIR, 'ml_models')
            
            model_path = os.path.join(base_path, 'bilstm_action_model.h5')
            scaler_path = os.path.join(base_path, 'scaler.pkl')
            encoder_path = os.path.join(base_path, 'label_encoder.pkl')

            if os.path.exists(model_path):
                self._model = tf.keras.models.load_model(model_path)
                print(f"Model loaded from {model_path}")
            
            if os.path.exists(scaler_path):
                with open(scaler_path, 'rb') as f:
                    self._scaler = pickle.load(f)
                print(f"Scaler loaded from {scaler_path}")

            if os.path.exists(encoder_path):
                with open(encoder_path, 'rb') as f:
                    self._label_encoder = pickle.load(f)
                print(f"Label encoder loaded from {encoder_path}")

            # Audio Model Loading
            audio_model_path = os.path.join(base_path, 'xgboost_threat_model.pkl')
            audio_scaler_path = os.path.join(base_path, 'feature_scaler.pkl')

            if os.path.exists(audio_model_path):
                with open(audio_model_path, 'rb') as f:
                    self._audio_model = pickle.load(f)
                print(f"Audio model loaded from {audio_model_path}")
            else:
                print("Audio model not found (skipping)")

            if os.path.exists(audio_scaler_path):
                with open(audio_scaler_path, 'rb') as f:
                    self._audio_scaler = pickle.load(f)
                print(f"Audio scaler loaded from {audio_scaler_path}")
            else:
                print("Audio scaler not found (skipping)")
                
        except Exception as e:
            print(f"Error loading ML models: {e}")

    def predict(self, data):
        if not (self._model and self._scaler and self._label_encoder):
            # Try loading again if not loaded
            self.load_models()
            if not (self._model and self._scaler and self._label_encoder):
                raise Exception("ML models not loaded. Please ensure files are in 'ml_models' directory.")

        # Data shape expected: [50, 12]
        # Normalize
        data_flat = np.array(data).reshape(-1, 12)
        data_scaled = self._scaler.transform(data_flat).reshape(1, 50, 12)
        
        # Predict
        prediction = self._model.predict(data_scaled, verbose=0)
        predicted_class = int(np.argmax(prediction))
        confidence = float(np.max(prediction))
        action = self._label_encoder.inverse_transform([predicted_class])[0]
        is_threat = action in self.THREAT_LABELS
        
        return {
            'action': action,
            'confidence': confidence,
            'is_threat': is_threat,
            'status': 'THREAT' if is_threat else 'SAFE'
        }

    def predict_audio(self, audio_file_path):
        """
        Predict if audio is a threat using XGBoost model.
        Uses FastAudioFeatureExtractor and separate scaler.
        """
        if not (self._audio_model and self._audio_scaler):
            self.load_models()
            if not (self._audio_model and self._audio_scaler):
                return {'error': 'Audio model or scaler not loaded', 'is_threat': False, 'confidence': 0.0}

        try:
            # 1. Extract Features
            extractor = FastAudioFeatureExtractor()
            features = extractor.extract_all_features(audio_file_path)
            
            if features is None:
                raise Exception("Could not extract features from audio file")

            # 2. Prepare for Model
            # Remove label/filename if present (though extract_all_features doesn't add them)
            features_df = pd.DataFrame([features])
            
            # 3. Scale Features
            features_scaled = self._audio_scaler.transform(features_df)
            
            # 4. Predict
            prediction = self._audio_model.predict(features_scaled)[0]
            
            # Try to get probabilities
            try:
                probs = self._audio_model.predict_proba(features_scaled)[0]
                # Assuming class 1 is Threat
                threat_prob = float(probs[1])
                confidence = threat_prob if prediction == 1 else float(probs[0])
            except:
                confidence = 1.0
                threat_prob = 1.0 if prediction == 1 else 0.0
            
            is_threat = int(prediction) == 1
            
            return {
                'is_threat': is_threat,
                'confidence': confidence,
                'threat_probability': threat_prob,
                'status': 'THREAT' if is_threat else 'SAFE'
            }
            
        except Exception as e:
            print(f"Audio prediction error: {e}")
            return {
                'error': str(e),
                'is_threat': False, 
                'confidence': 0.0,
                'status': 'ERROR'
            }
