# Police Response System APIs

from rest_framework import status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
import logging
from math import radians, cos, sin, asin, sqrt

from .models import PoliceOfficer, EmergencyAlert, DispatchTask

logger = logging.getLogger(__name__)

def haversine(lon1, lat1, lon2, lat2):
    """
    Calculate the great circle distance between two points 
    on the earth (specified in decimal degrees)
    Returns distance in kilometers
    """
    # convert decimal degrees to radians 
    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
    
    # haversine formula 
    dlon = lon2 - lon1 
    dlat = lat2 - lat1 
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a)) 
    km = 6371 * c
    return km


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def police_login(request):
    """
    Police officer login - checks role is mobile_officer
    """
    from django.contrib.auth import authenticate
    from rest_framework_simplejwt.tokens import RefreshToken
    
    email = request.data.get('email')
    password = request.data.get('password')
    
    if not email or not password:
        return Response({'error': 'Email and password required'}, status=status.HTTP_400_BAD_REQUEST)
    
    user = authenticate(email=email, password=password)
    
    if not user:
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)
    
    # Check if user is a mobile officer
    if user.role != 'mobile_officer':
        return Response({'error': 'Access denied. Mobile officer role required.'}, status=status.HTTP_403_FORBIDDEN)
    
    # Get or create police officer profile
    try:
        officer = PoliceOfficer.objects.get(user=user)
    except PoliceOfficer.DoesNotExist:
        return Response({'error': 'Officer profile not found'}, status=status.HTTP_404_NOT_FOUND)
    
    # Generate tokens
    refresh = RefreshToken.for_user(user)
    
    return Response({
        'tokens': {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        },
        'user': {
            'id': user.id,
            'email': user.email,
            'full_name': user.full_name,
            'role': user.role,
        },
        'officer': {
            'id': officer.id,
            'badge_number': officer.badge_number,
            'rank': officer.rank,
            'station': officer.station,
            'status': officer.status,
        }
    })

@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def police_register(request):
    """
    Register a new police officer
    """
    from django.contrib.auth import get_user_model
    from rest_framework_simplejwt.tokens import RefreshToken
    
    User = get_user_model()
    
    email = request.data.get('email')
    password = request.data.get('password')
    full_name = request.data.get('full_name')
    badge_number = request.data.get('badge_number')
    rank = request.data.get('rank', 'Officer')
    station = request.data.get('station', 'Main Station')
    
    if not all([email, password, full_name, badge_number]):
        return Response(
            {'error': 'Email, password, full name, and badge number are required'}, 
            status=status.HTTP_400_BAD_REQUEST
        )
        
    if User.objects.filter(email=email).exists():
        return Response({'error': 'Email already registered'}, status=status.HTTP_400_BAD_REQUEST)
        
    if PoliceOfficer.objects.filter(badge_number=badge_number).exists():
        return Response({'error': 'Badge number already registered'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        # Create User
        user = User.objects.create_user(
            username=email,
            email=email,
            password=password,
            full_name=full_name,
            role='mobile_officer'
        )
        
        # Create Officer Profile
        officer = PoliceOfficer.objects.create(
            user=user,
            badge_number=badge_number,
            rank=rank,
            station=station,
            status='offline'
        )
        
        # Generate tokens
        refresh = RefreshToken.for_user(user)
        
        return Response({
            'message': 'Registration successful',
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            },
            'user': {
                'id': user.id,
                'email': user.email,
                'full_name': user.full_name,
                'role': user.role,
            },
            'officer': {
                'id': officer.id,
                'badge_number': officer.badge_number,
                'rank': officer.rank,
                'station': officer.station,
                'status': officer.status,
            }
        }, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_available_officers(request):
    """
    Get all free officers with their locations
    Admin only
    """
    if request.user.role != 'admin':
        return Response({'error': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
    
    officers = PoliceOfficer.objects.filter(status='free')
    
    data = []
    for officer in officers:
        data.append({
            'id': officer.id,
            'badge_number': officer.badge_number,
            'name': officer.user.full_name,
            'status': officer.status,
            'location': {
                'latitude': float(officer.current_latitude) if officer.current_latitude else None,
                'longitude': float(officer.current_longitude) if officer.current_longitude else None,
            },
            'last_update': officer.last_location_update.isoformat() if officer.last_location_update else None,
        })
    
    return Response(data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_officer_location_new(request):
    """
    Update officer's current location
    Mobile officer only
    """
    if request.user.role != 'mobile_officer':
        return Response({'error': 'Mobile officer access required'}, status=status.HTTP_403_FORBIDDEN)
    
    try:
        officer = PoliceOfficer.objects.get(user=request.user)
    except PoliceOfficer.DoesNotExist:
        return Response({'error': 'Officer profile not found'}, status=status.HTTP_404_NOT_FOUND)
    
    latitude = request.data.get('latitude')
    longitude = request.data.get('longitude')
    
    if latitude is None or longitude is None:
        return Response({'error': 'Latitude and longitude required'}, status=status.HTTP_400_BAD_REQUEST)
    
    officer.current_latitude = latitude
    officer.current_longitude = longitude
    officer.last_location_update = timezone.now()
    officer.save()
    
    # Broadcast location update via WebSocket
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            "police_dashboard",
            {
                'type': 'officer_location_update',
                'officer_id': officer.id,
                'badge_number': officer.badge_number,
                'name': officer.user.full_name,
                'status': officer.status,
                'coordinates': {
                    'lat': float(latitude),
                    'lng': float(longitude),
                },
                'timestamp': officer.last_location_update.isoformat(),
            }
        )
    except Exception as e:
        logger.error(f"WebSocket broadcast failed: {e}")
    
    return Response({'message': 'Location updated successfully'})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_nearest_officer(request, emergency_id):
    """
    Calculate and return the nearest available officer to an emergency
    Admin only
    """
    if request.user.role != 'admin':
        return Response({'error': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
    
    try:
        emergency = EmergencyAlert.objects.get(id=emergency_id)
    except EmergencyAlert.DoesNotExist:
        return Response({'error': 'Emergency not found'}, status=status.HTTP_404_NOT_FOUND)
    
    if not emergency.location_latitude or not emergency.location_longitude:
        return Response({'error': 'Emergency location not available'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Get all free officers with location data
    officers = PoliceOfficer.objects.filter(
        status='free',
        current_latitude__isnull=False,
        current_longitude__isnull=False
    )
    
    if not officers.exists():
        return Response({'error': 'No available officers'}, status=status.HTTP_404_NOT_FOUND)
    
    # Calculate distances
    nearest_officer = None
    min_distance = float('inf')
    
    emergency_lat = float(emergency.location_latitude)
    emergency_lon = float(emergency.location_longitude)
    
    officers_with_distance = []
    
    for officer in officers:
        officer_lat = float(officer.current_latitude)
        officer_lon = float(officer.current_longitude)
        
        distance = haversine(emergency_lon, emergency_lat, officer_lon, officer_lat)
        
        officers_with_distance.append({
            'officer': officer,
            'distance': distance
        })
        
        if distance < min_distance:
            min_distance = distance
            nearest_officer = officer
    
    # Sort by distance
    officers_with_distance.sort(key=lambda x: x['distance'])
    
    return Response({
        'nearest_officer': {
            'id': nearest_officer.id,
            'badge_number': nearest_officer.badge_number,
            'name': nearest_officer.user.full_name,
            'distance_km': round(min_distance, 2),
            'location': {
                'latitude': float(nearest_officer.current_latitude),
                'longitude': float(nearest_officer.current_longitude),
            }
        },
        'all_available_officers': [
            {
                'id': item['officer'].id,
                'badge_number': item['officer'].badge_number,
                'name': item['officer'].user.full_name,
                'distance_km': round(item['distance'], 2),
                'location': {
                    'latitude': float(item['officer'].current_latitude),
                    'longitude': float(item['officer'].current_longitude),
                }
            }
            for item in officers_with_distance
        ]
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def assign_officer(request):
    """
    Assign an officer to an emergency
    Admin only
    """
    if request.user.role != 'admin':
        return Response({'error': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
    
    officer_id = request.data.get('officer_id')
    emergency_id = request.data.get('emergency_id')
    
    if not officer_id or not emergency_id:
        return Response({'error': 'Officer ID and Emergency ID required'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        officer = PoliceOfficer.objects.get(id=officer_id)
        emergency = EmergencyAlert.objects.get(id=emergency_id)
    except PoliceOfficer.DoesNotExist:
        return Response({'error': 'Officer not found'}, status=status.HTTP_404_NOT_FOUND)
    except EmergencyAlert.DoesNotExist:
        return Response({'error': 'Emergency not found'}, status=status.HTTP_404_NOT_FOUND)
    
    if officer.status != 'free':
        return Response({'error': 'Officer is not available'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Create dispatch task
    task = DispatchTask.objects.create(
        officer=officer,
        emergency=emergency,
        status='pending'
    )
    
    # Update officer status
    officer.status = 'assigned'
    officer.save()
    
    # Send notification to officer via WebSocket
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"officer_{officer.id}",
            {
                'type': 'task_assigned',
                'task_id': task.id,
                'emergency_id': emergency.id,
                'victim_name': emergency.user.full_name,
                'location': {
                    'latitude': float(emergency.location_latitude) if emergency.location_latitude else None,
                    'longitude': float(emergency.location_longitude) if emergency.location_longitude else None,
                    'address': emergency.location_address,
                },
                'description': emergency.description,
                'timestamp': task.assigned_at.isoformat(),
            }
        )
    except Exception as e:
        logger.error(f"WebSocket notification failed: {e}")
    
    return Response({
        'message': 'Officer assigned successfully',
        'task_id': task.id,
        'officer': {
            'id': officer.id,
            'badge_number': officer.badge_number,
            'name': officer.user.full_name,
        }
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_officer_tasks(request):
    """
    Get tasks assigned to the logged-in officer
    Mobile officer only
    """
    if request.user.role != 'mobile_officer':
        return Response({'error': 'Mobile officer access required'}, status=status.HTTP_403_FORBIDDEN)
    
    try:
        officer = PoliceOfficer.objects.get(user=request.user)
    except PoliceOfficer.DoesNotExist:
        return Response({'error': 'Officer profile not found'}, status=status.HTTP_404_NOT_FOUND)
    
    tasks = DispatchTask.objects.filter(officer=officer).exclude(status='resolved')
    
    data = []
    for task in tasks:
        data.append({
            'id': task.id,
            'status': task.status,
            'emergency': {
                'id': task.emergency.id,
                'victim_name': task.emergency.user.full_name,
                'location': {
                    'latitude': float(task.emergency.location_latitude) if task.emergency.location_latitude else None,
                    'longitude': float(task.emergency.location_longitude) if task.emergency.location_longitude else None,
                    'address': task.emergency.location_address,
                },
                'description': task.emergency.description,
            },
            'assigned_at': task.assigned_at.isoformat(),
            'accepted_at': task.accepted_at.isoformat() if task.accepted_at else None,
        })
    
    return Response(data)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_task_status(request, task_id):
    """
    Update task status (accept, decline, en_route, arrived, resolved)
    Mobile officer only
    """
    if request.user.role != 'mobile_officer':
        return Response({'error': 'Mobile officer access required'}, status=status.HTTP_403_FORBIDDEN)
    
    try:
        officer = PoliceOfficer.objects.get(user=request.user)
        task = DispatchTask.objects.get(id=task_id, officer=officer)
    except PoliceOfficer.DoesNotExist:
        return Response({'error': 'Officer profile not found'}, status=status.HTTP_404_NOT_FOUND)
    except DispatchTask.DoesNotExist:
        return Response({'error': 'Task not found'}, status=status.HTTP_404_NOT_FOUND)
    
    new_status = request.data.get('status')
    
    if new_status not in ['accepted', 'declined', 'en_route', 'arrived', 'resolved']:
        return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)
    
    task.status = new_status
    
    if new_status == 'accepted':
        task.accepted_at = timezone.now()
    elif new_status == 'arrived':
        task.arrived_at = timezone.now()
    elif new_status == 'resolved':
        task.resolved_at = timezone.now()
        officer.status = 'free'
        officer.save()
    elif new_status == 'declined':
        officer.status = 'free'
        officer.save()
    
    task.save()
    
    # Broadcast status update
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            "police_dashboard",
            {
                'type': 'task_status_update',
                'task_id': task.id,
                'officer_id': officer.id,
                'emergency_id': task.emergency.id,
                'status': new_status,
                'timestamp': timezone.now().isoformat(),
            }
        )
    except Exception as e:
        logger.error(f"WebSocket broadcast failed: {e}")
    
    return Response({'message': f'Task status updated to {new_status}'})
