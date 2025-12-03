from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth import authenticate
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken
from .models import PoliceOfficer, DispatchTask, EmergencyAlert
from django.contrib.auth import get_user_model
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from math import radians, sin, cos, sqrt, atan2
import logging

logger = logging.getLogger(__name__)
User = get_user_model()

# ============================================
# AUTHENTICATION ENDPOINTS
# ============================================

@api_view(['POST'])
@permission_classes([AllowAny])
def police_register(request):
    """Register a new police officer"""
    try:
        data = request.data
        
        # Create user account
        user = User.objects.create_user(
            username=data['email'],
            email=data['email'],
            password=data['password'],
            full_name=data['full_name'],
            role='police'
        )
        
        # Create police officer profile
        officer = PoliceOfficer.objects.create(
            user=user,
            badge_number=data['badge_number'],
            rank=data.get('rank', 'Officer'),
            station=data.get('station', 'Main Station'),
            status='offline'
        )
        
        # Generate tokens
        refresh = RefreshToken.for_user(user)
        
        logger.info(f"✅ Police officer registered: {user.email}")
        
        return Response({
            'message': 'Officer registered successfully',
            'officer': {
                'id': officer.id,
                'badge_number': officer.badge_number,
                'rank': officer.rank,
                'station': officer.station
            },
            'tokens': {
                'access': str(refresh.access_token),
                'refresh': str(refresh)
            }
        }, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        logger.error(f"Registration error: {e}")
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def police_login(request):
    """Police officer login"""
    try:
        email = request.data.get('email')
        password = request.data.get('password')
        
        user = authenticate(email=email, password=password)
        
        if not user:
            return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)
        
        if user.role != 'police':
            return Response({'error': 'Not authorized as police'}, status=status.HTTP_403_FORBIDDEN)
        
        # Get officer profile
        try:
            officer = PoliceOfficer.objects.get(user=user)
            officer.status = 'available'
            officer.save()
        except PoliceOfficer.DoesNotExist:
            return Response({'error': 'Officer profile not found'}, status=status.HTTP_404_NOT_FOUND)
        
        # Generate tokens
        refresh = RefreshToken.for_user(user)
        
        logger.info(f"✅ Officer logged in: {user.email}")
        
        return Response({
            'message': 'Login successful',
            'officer': {
                'id': officer.id,
                'badge_number': officer.badge_number,
                'rank': officer.rank,
                'station': officer.station,
                'status': officer.status
            },
            'tokens': {
                'access': str(refresh.access_token),
                'refresh': str(refresh)
            }
        })
        
    except Exception as e:
        logger.error(f"Login error: {e}")
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


# ============================================
# LOCATION MANAGEMENT
# ============================================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_officer_location_new(request):
    """
    Officer updates their current location
    This runs every 5-15 seconds from the companion app
    """
    try:
        officer = PoliceOfficer.objects.get(user=request.user)
        
        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')
        
        if not latitude or not longitude:
            return Response({'error': 'Latitude and longitude required'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Update officer location
        officer.current_latitude = latitude
        officer.current_longitude = longitude
        officer.last_location_update = timezone.now()
        officer.save()
        
        logger.info(f"📍 Officer {officer.badge_number} location updated: {latitude}, {longitude}")
        
        # Find active tasks for this officer
        active_tasks = DispatchTask.objects.filter(
            officer=officer,
            status__in=['accepted', 'en_route']
        )
        
        # Broadcast location to each emergency's user channel
        channel_layer = get_channel_layer()
        for task in active_tasks:
            emergency = task.emergency
            user_id = emergency.user.id
            
            # Send to user's WebSocket channel
            async_to_sync(channel_layer.group_send)(
                f"user_{user_id}",
                {
                    'type': 'officer_location',
                    'officer_id': officer.id,
                    'officer_name': f"{officer.rank} {officer.user.full_name}",
                    'badge_number': officer.badge_number,
                    'emergency_id': emergency.id,
                    'coordinates': {
                        'lat': float(latitude),
                        'lng': float(longitude)
                    },
                    'timestamp': timezone.now().isoformat(),
                    'eta': calculate_eta(latitude, longitude, emergency.location_latitude, emergency.location_longitude)
                }
            )
            
            logger.info(f"📡 Location broadcasted to user_{user_id}")
        
        return Response({
            'message': 'Location updated',
            'active_tasks': active_tasks.count()
        })
        
    except PoliceOfficer.DoesNotExist:
        return Response({'error': 'Officer profile not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Location update error: {e}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ============================================
# OFFICER MANAGEMENT
# ============================================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_available_officers(request):
    """Get all available officers with their locations"""
    try:
        officers = PoliceOfficer.objects.filter(
            is_active=True,
            status__in=['available', 'on_patrol']
        ).select_related('user')
        
        data = []
        for officer in officers:
            data.append({
                'id': officer.id,
                'name': officer.user.full_name,
                'badge_number': officer.badge_number,
                'rank': officer.rank,
                'station': officer.station,
                'status': officer.status,
                'location': {
                    'latitude': float(officer.current_latitude) if officer.current_latitude else None,
                    'longitude': float(officer.current_longitude) if officer.current_longitude else None,
                    'last_update': officer.last_location_update.isoformat() if officer.last_location_update else None
                }
            })
        
        return Response(data)
        
    except Exception as e:
        logger.error(f"Error fetching officers: {e}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_nearest_officer(request, emergency_id):
    """Find nearest available officer to an emergency"""
    try:
        emergency = EmergencyAlert.objects.get(id=emergency_id)
        
        if not emergency.location_latitude or not emergency.location_longitude:
            return Response({'error': 'Emergency location not available'}, status=status.HTTP_400_BAD_REQUEST)
        
        available_officers = PoliceOfficer.objects.filter(
            is_active=True,
            status__in=['available', 'on_patrol'],
            current_latitude__isnull=False,
            current_longitude__isnull=False
        )
        
        nearest_officer = None
        min_distance = float('inf')
        
        for officer in available_officers:
            distance = calculate_distance(
                float(emergency.location_latitude),
                float(emergency.location_longitude),
                float(officer.current_latitude),
                float(officer.current_longitude)
            )
            
            if distance < min_distance:
                min_distance = distance
                nearest_officer = officer
        
        if not nearest_officer:
            return Response({'error': 'No available officers found'}, status=status.HTTP_404_NOT_FOUND)
        
        return Response({
            'officer': {
                'id': nearest_officer.id,
                'name': nearest_officer.user.full_name,
                'badge_number': nearest_officer.badge_number,
                'distance_km': round(min_distance, 2),
                'location': {
                    'latitude': float(nearest_officer.current_latitude),
                    'longitude': float(nearest_officer.current_longitude)
                }
            }
        })
        
    except EmergencyAlert.DoesNotExist:
        return Response({'error': 'Emergency not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Error finding nearest officer: {e}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ============================================
# DISPATCH TASK MANAGEMENT
# ============================================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def assign_officer(request):
    """
    Assign an officer to an emergency
    Called by the web dashboard after finding nearest officer
    """
    try:
        officer_id = request.data.get('officer_id')
        emergency_id = request.data.get('emergency_id')
        
        officer = PoliceOfficer.objects.get(id=officer_id)
        emergency = EmergencyAlert.objects.get(id=emergency_id)
        
        # Create dispatch task
        task = DispatchTask.objects.create(
            emergency=emergency,
            officer=officer,
            status='pending'
        )
        
        # Update officer status
        officer.status = 'busy'
        officer.save()
        
        logger.info(f"✅ Officer {officer.badge_number} assigned to emergency {emergency_id}")
        
        # Notify officer via WebSocket
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"officer_{officer.id}",
            {
                'type': 'new_task',
                'task_id': task.id,
                'emergency': {
                    'id': emergency.id,
                    'victim_name': emergency.user.full_name,
                    'location': emergency.location_address,
                    'coordinates': {
                        'lat': float(emergency.location_latitude) if emergency.location_latitude else None,
                        'lng': float(emergency.location_longitude) if emergency.location_longitude else None
                    },
                    'description': emergency.description,
                    'timestamp': emergency.created_at.isoformat()
                }
            }
        )
        
        logger.info(f"📡 Task notification sent to officer_{officer.id}")
        
        return Response({
            'message': 'Officer assigned successfully',
            'task_id': task.id,
            'officer': {
                'id': officer.id,
                'name': officer.user.full_name,
                'badge_number': officer.badge_number
            }
        }, status=status.HTTP_201_CREATED)
        
    except PoliceOfficer.DoesNotExist:
        return Response({'error': 'Officer not found'}, status=status.HTTP_404_NOT_FOUND)
    except EmergencyAlert.DoesNotExist:
        return Response({'error': 'Emergency not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Assignment error: {e}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_officer_tasks(request):
    """Get all tasks for the authenticated officer"""
    try:
        officer = PoliceOfficer.objects.get(user=request.user)
        
        tasks = DispatchTask.objects.filter(
            officer=officer
        ).select_related('emergency', 'emergency__user').order_by('-assigned_at')
        
        data = []
        for task in tasks:
            emergency = task.emergency
            data.append({
                'id': task.id,
                'status': task.status,
                'assigned_at': task.assigned_at.isoformat(),
                'emergency': {
                    'id': emergency.id,
                    'victim_name': emergency.user.full_name,
                    'victim_phone': emergency.user.phone_number if hasattr(emergency.user, 'phone_number') else None,
                    'location': emergency.location_address,
                    'coordinates': {
                        'latitude': float(emergency.location_latitude) if emergency.location_latitude else None,
                        'longitude': float(emergency.location_longitude) if emergency.location_longitude else None
                    },
                    'description': emergency.description,
                    'timestamp': emergency.created_at.isoformat()
                }
            })
        
        return Response(data)
        
    except PoliceOfficer.DoesNotExist:
        return Response({'error': 'Officer profile not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Error fetching tasks: {e}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_task_status(request, pk):
    """Update task status (accept, decline, en_route, arrived, resolved)"""
    try:
        task = DispatchTask.objects.get(id=pk, officer__user=request.user)
        new_status = request.data.get('status')
        
        if new_status not in ['accepted', 'declined', 'en_route', 'arrived', 'resolved']:
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)
        
        old_status = task.status
        task.status = new_status
        
        if new_status == 'accepted':
            task.accepted_at = timezone.now()
            task.officer.status = 'en_route'
        elif new_status == 'arrived':
            task.officer.status = 'on_scene'
        elif new_status == 'resolved':
            task.resolved_at = timezone.now()
            task.officer.status = 'available'
            task.emergency.status = 'resolved'
            task.emergency.resolved_at = timezone.now()
            task.emergency.save()
        elif new_status == 'declined':
            task.officer.status = 'available'
        
        task.officer.save()
        task.save()
        
        logger.info(f"✅ Task {pk} status: {old_status} → {new_status}")
        
        # Notify web dashboard
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            "police_dashboard",
            {
                'type': 'task_status_update',
                'task_id': task.id,
                'emergency_id': task.emergency.id,
                'officer_id': task.officer.id,
                'status': new_status,
                'timestamp': timezone.now().isoformat()
            }
        )
        
        # If accepted, notify the emergency user
        if new_status == 'accepted':
            async_to_sync(channel_layer.group_send)(
                f"user_{task.emergency.user.id}",
                {
                    'type': 'officer_assigned',
                    'officer_name': f"{task.officer.rank} {task.officer.user.full_name}",
                    'badge_number': task.officer.badge_number,
                    'emergency_id': task.emergency.id,
                    'message': 'An officer has been assigned to your emergency'
                }
            )
        
        # If resolved, notify user
        if new_status == 'resolved':
            async_to_sync(channel_layer.group_send)(
                f"user_{task.emergency.user.id}",
                {
                    'type': 'emergency_resolved',
                    'emergency_id': task.emergency.id,
                    'message': 'Your emergency has been resolved'
                }
            )
        
        return Response({
            'message': f'Task status updated to {new_status}',
            'task': {
                'id': task.id,
                'status': task.status
            }
        })
        
    except DispatchTask.DoesNotExist:
        return Response({'error': 'Task not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Status update error: {e}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ============================================
# UTILITY FUNCTIONS
# ============================================

def calculate_distance(lat1, lon1, lat2, lon2):
    """
    Calculate distance between two points using Haversine formula
    Returns distance in kilometers
    """
    R = 6371  # Earth's radius in km
    
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * atan2(sqrt(a), sqrt(1-a))
    
    return R * c


def calculate_eta(officer_lat, officer_lon, emergency_lat, emergency_lon):
    """
    Calculate estimated time of arrival
    Assumes average speed of 60 km/h
    Returns ETA in minutes
    """
    distance = calculate_distance(officer_lat, officer_lon, emergency_lat, emergency_lon)
    speed = 60  # km/h
    eta_hours = distance / speed
    eta_minutes = int(eta_hours * 60)
    return max(1, eta_minutes)  # Minimum 1 minute