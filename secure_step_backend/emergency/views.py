import os
from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from .models import EmergencyContact, EmergencyAlert, EmergencySettings
from .models import OfficerLocation
from .serializers import OfficerLocationSerializer
from .serializers import (
    EmergencyContactSerializer, 
    EmergencyAlertSerializer, 
    EmergencySettingsSerializer
)
from .tasks import send_emergency_notifications
import logging
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from django.utils import timezone
import time, threading
from .ml_predictor import MLPredictor

logger = logging.getLogger(__name__)

class EmergencyContactListView(generics.ListCreateAPIView):
    """
    GET: List all emergency contacts for authenticated user
    POST: Create a new emergency contact
    """
    serializer_class = EmergencyContactSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return EmergencyContact.objects.filter(user=self.request.user).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
        logger.info(f"Emergency contact created for user {self.request.user.email}")

class EmergencyContactDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve specific emergency contact
    PUT/PATCH: Update emergency contact
    DELETE: Delete emergency contact
    """
    serializer_class = EmergencyContactSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return EmergencyContact.objects.filter(user=self.request.user)

    def get_object(self):
        contact_id = self.kwargs.get('pk')
        return get_object_or_404(EmergencyContact, id=contact_id, user=self.request.user)

    def perform_update(self, serializer):
        serializer.save()
        logger.info(f"Emergency contact {serializer.instance.id} updated for user {self.request.user.email}")

    def perform_destroy(self, instance):
        contact_name = instance.name
        instance.delete()
        logger.info(f"Emergency contact '{contact_name}' deleted for user {self.request.user.email}")

    def delete(self, request, *args, **kwargs):
        contact = self.get_object()
        contact_name = contact.name
        self.perform_destroy(contact)
        return Response({
            'message': f'Emergency contact "{contact_name}" deleted successfully'
        }, status=status.HTTP_204_NO_CONTENT)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def trigger_emergency(request):
    """Trigger an emergency alert with WebSocket broadcast"""
    logger.info(f"Emergency trigger request from user {request.user.email}")
    data = request.data.copy()
    
    # Create emergency alert
    serializer = EmergencyAlertSerializer(data=data, context={'request': request})
    
    if serializer.is_valid():
        alert = serializer.save()
        
        # Update user's emergency count
        user = request.user
        user.emergency_count += 1
        user.save()
        
        # BROADCAST VIA WEBSOCKET TO POLICE DASHBOARD
        try:
            channel_layer = get_channel_layer()
            async_to_sync(channel_layer.group_send)(
                "police_dashboard",
                {
                    'type': 'emergency_alert',
                    'alert_id': alert.id,
                    'user_id': user.id,
                    'user_name': user.full_name,
                    'location': alert.location_address or 'Unknown',
                    'coordinates': {
                        'lat': float(alert.location_latitude) if alert.location_latitude else 34.1688,
                        'lng': float(alert.location_longitude) if alert.location_longitude else 73.2215,
                    },
                    'timestamp': alert.created_at.isoformat(),
                }
            )
            logger.info(f"Emergency alert {alert.id} broadcasted via WebSocket")
        except Exception as e:
            logger.error(f"WebSocket broadcast failed: {e}")
        
        # Send SMS notifications asynchronously (with error handling)
        try:
            send_emergency_notifications.delay(alert.id)
            logger.info(f"Emergency notifications queued for alert {alert.id}")
        except Exception as e:
            logger.warning(f"Could not queue emergency notifications: {e}")
        
        return Response({
            'message': 'Emergency alert triggered successfully',
            'alert': serializer.data
        }, status=status.HTTP_201_CREATED)
    
    logger.error(f"Emergency trigger failed: {serializer.errors}")
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class EmergencyAlertListView(generics.ListAPIView):
    serializer_class = EmergencyAlertSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return EmergencyAlert.objects.filter(user=self.request.user).order_by('-created_at')

class EmergencySettingsView(generics.RetrieveUpdateAPIView):
    serializer_class = EmergencySettingsSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        settings, created = EmergencySettings.objects.get_or_create(
            user=self.request.user,
            defaults={
                'video_monitoring': True,
                'motion_detection': True,
                'camera_monitoring': False,
                'auto_call_authorities': False,
                'emergency_message': "I need help! This is an emergency."
            }
        )
        return settings

# Admin views
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_emergency_alerts(request):
    """Admin view for all emergency alerts"""
    from accounts.models import AdminUser
    
    try:
        AdminUser.objects.get(user=request.user)
    except AdminUser.DoesNotExist:
        return Response({'error': 'Admin access required'}, 
                       status=status.HTTP_403_FORBIDDEN)
    
    alerts = EmergencyAlert.objects.all().order_by('-created_at')
    serializer = EmergencyAlertSerializer(alerts, many=True)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_officer_location(request):
    """
    Officers send their live location every few seconds.
    """
    data = request.data
    emergency_id = data.get("emergencyId")
    lat = data.get("lat")
    lng = data.get("lng")

    if not emergency_id or not lat or not lng:
        return Response({"error": "Missing data"}, status=status.HTTP_400_BAD_REQUEST)

    # create or update officer location
    location, created = OfficerLocation.objects.update_or_create(
        officer=request.user,
        emergency_id=emergency_id,
        defaults={
            "latitude": lat,
            "longitude": lng,
        }
    )

    # Optional: broadcast to WebSocket so dashboards update live
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            "police_dashboard",
            {
                'type': 'officer_location',
                'officer_id': request.user.id,
                'officer_name': request.user.full_name,
                'emergency_id': emergency_id,
                'coordinates': {'lat': float(lat), 'lng': float(lng)},
                'timestamp': location.updated_at.isoformat(),
            }
        )
    except Exception as e:
        logger.error(f"WebSocket officer location broadcast failed: {e}")

    serializer = OfficerLocationSerializer(location)
    return Response(serializer.data, status=status.HTTP_200_OK)




assigned_officers = {}  # store officer_id -> alert_id mapping

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def assign_police_to_alert(request):
    """
    Assign a police officer to an emergency alert
    and start broadcasting officer location every 5s
    """
    officer_id = request.data.get("officer_id")
    alert_id = request.data.get("alert_id")

    if not officer_id or not alert_id:
        return Response({"error": "officer_id and alert_id required"}, status=400)

    assigned_officers[officer_id] = alert_id

    # Start broadcasting in a background thread
    def broadcast_location():
        from random import uniform
        channel_layer = get_channel_layer()
        while officer_id in assigned_officers:
            # Example random coords near Abbottabad
            lat = 34.1688 + uniform(-0.001, 0.001)
            lng = 73.2215 + uniform(-0.001, 0.001)

            async_to_sync(channel_layer.group_send)(
                f"alert_{alert_id}",  # group based on alert
                {
                    "type": "police.location",
                    "coordinates": {"lat": lat, "lng": lng},
                    "eta": 5,
                    "officer_id": officer_id,
                    "timestamp": timezone.now().isoformat(),
                }
            )
            time.sleep(5)  # broadcast every 5 seconds

    threading.Thread(target=broadcast_location, daemon=True).start()

    return Response({"message": "Police assigned & tracking started."})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_all_contacts(request):
    """Admin view for all emergency contacts"""
    from accounts.models import AdminUser
    
    try:
        AdminUser.objects.get(user=request.user)
    except AdminUser.DoesNotExist:
        return Response({'error': 'Admin access required'}, 
                       status=status.HTTP_403_FORBIDDEN)
    
    contacts = EmergencyContact.objects.all().select_related('user').order_by('-created_at')
    
    # Custom serialization to include user info for admin
    data = []
    for contact in contacts:
        data.append({
            'id': contact.id,
            'name': contact.name,
            'phone_number': contact.phone_number,
            'relationship': contact.relationship,
            'is_primary': contact.is_primary,
            'created_at': contact.created_at,
            'updated_at': contact.updated_at,
            'user': {
                'id': contact.user.id,
                'full_name': contact.user.full_name,
                'email': contact.user.email,
            }
        })
    
    return Response(data)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def predict_movement(request):
    """
    Predict movement action from sensor data
    """
    try:
        data = request.data.get('data')
        if not data:
            return Response({'error': 'No data provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        predictor = MLPredictor.get_instance()
        result = predictor.predict(data)
        return Response(result)
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def predict_audio(request):
    """
    Predict threat from audio file upload
    """
    try:
        if 'file' not in request.FILES:
            return Response({'error': 'No audio file provided'}, status=status.HTTP_400_BAD_REQUEST)
            
        audio_file = request.FILES['file']
        
        # Save temp file
        import tempfile
        import shutil
        
        # Create a temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.m4a') as tmp:
            for chunk in audio_file.chunks():
                tmp.write(chunk)
            tmp_path = tmp.name
            
        try:
            predictor = MLPredictor.get_instance()
            result = predictor.predict_audio(tmp_path)
            return Response(result)
        finally:
            # Clean up temp file
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
                
    except Exception as e:
        logger.error(f"Audio prediction error: {e}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def predict_combined(request):
    """
    Predict threat from both movement and audio data
    Returns combined threat assessment
    
    Logic:
    - Non-threat actions: jogging, jumping, falling, dancing, walking, running
    - Any other action = THREAT
    - Audio threat OR Movement threat = OVERALL THREAT
    """
    try:
        import json
        
        # Get movement data (JSON string)
        movement_data_str = request.data.get('movement_data')
        if movement_data_str:
            movement_data = json.loads(movement_data_str) if isinstance(movement_data_str, str) else movement_data_str
        else:
            movement_data = None
        
        # Get audio file
        audio_file = request.FILES.get('audio_file')
        
        if not movement_data:
            return Response({'error': 'No movement data provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        predictor = MLPredictor.get_instance()
        
        # ============================================
        # 1. PREDICT MOVEMENT
        # ============================================
        movement_result = predictor.predict(movement_data)
        
        # Define non-threat actions
        NON_THREAT_ACTIONS = [
            'jogging', 'jumping', 'falling', 
            'dancing', 'walking', 'running'
        ]
        
        # Check if action is a threat (case-insensitive)
        detected_action = movement_result['action'].lower()
        movement_is_threat = detected_action not in NON_THREAT_ACTIONS
        
        # Update movement result with correct threat status
        movement_result['is_threat'] = movement_is_threat
        movement_result['status'] = 'THREAT' if movement_is_threat else 'SAFE'
        
        logger.info(f"Movement detected: {detected_action} - Threat: {movement_is_threat}")
        
        # ============================================
        # 2. PREDICT AUDIO (if provided)
        # ============================================
        audio_result = {'is_threat': False, 'confidence': 0.0, 'status': 'NO_AUDIO'}
        
        if audio_file:
            import tempfile
            import os
            
            with tempfile.NamedTemporaryFile(delete=False, suffix='.m4a') as tmp:
                for chunk in audio_file.chunks():
                    tmp.write(chunk)
                tmp_path = tmp.name
                
            try:
                audio_result = predictor.predict_audio(tmp_path)
                logger.info(f"Audio prediction: Threat={audio_result['is_threat']}, Confidence={audio_result.get('confidence', 0)}")
            finally:
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)
        
        # ============================================
        # 3. COMBINED THREAT ASSESSMENT
        # ============================================
        # Threat if EITHER movement OR audio detects threat
        is_threat = movement_result['is_threat'] or audio_result['is_threat']
        
        # Calculate combined confidence
        if movement_result['is_threat'] and audio_result['is_threat']:
            # Both detect threat - average confidence
            combined_confidence = (movement_result['confidence'] + audio_result.get('confidence', 0)) / 2
        else:
            # Only one detects threat - use maximum confidence
            combined_confidence = max(movement_result['confidence'], audio_result.get('confidence', 0))
        
        logger.info(f"COMBINED RESULT - Threat: {is_threat}, Confidence: {combined_confidence}")
        
        return Response({
            'is_threat': is_threat,
            'combined_confidence': combined_confidence,
            'movement_result': movement_result,
            'audio_result': audio_result,
            'status': 'THREAT DETECTED' if is_threat else 'SAFE',
            'detected_action': detected_action,
            'threat_reason': 'movement' if movement_result['is_threat'] else ('audio' if audio_result['is_threat'] else 'none')
        })
        
    except Exception as e:
        logger.error(f"Combined prediction error: {e}")
        import traceback
        traceback.print_exc()
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def get_high_risk_zones(request):
    """Get all active high-risk zones"""
    from .models import HighRiskZone
    
    zones = HighRiskZone.objects.filter(is_active=True)
    data = []
    
    for zone in zones:
        data.append({
            'id': zone.id,
            'name': zone.name,
            'description': zone.description,
            'latitude': float(zone.latitude),
            'longitude': float(zone.longitude),
            'radius_meters': zone.radius_meters,
            'risk_level': zone.risk_level,
            'image_url': zone.image_url,
            'last_incident': zone.last_incident.isoformat() if zone.last_incident else None,
        })
    
    return Response(data)