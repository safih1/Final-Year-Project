from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from django.contrib.auth import authenticate
from django.utils import timezone
from django.db.models import Q, Count, Avg
from datetime import timedelta
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from .models import Officer, Emergency, OfficerActivity
from .serializers import (
    OfficerRegistrationSerializer, OfficerSerializer, 
    OfficerStatusUpdateSerializer, OfficerLocationUpdateSerializer,
    EmergencySerializer, OfficerActivitySerializer
)


class CustomAuthToken(ObtainAuthToken):
    """Custom login view using badge number"""
    
    def post(self, request, *args, **kwargs):
        badge_number = request.data.get('badge_number')
        password = request.data.get('password')
        
        try:
            officer = Officer.objects.get(badge_number=badge_number)
            user = authenticate(username=officer.username, password=password)
            
            if user:
                token, created = Token.objects.get_or_create(user=user)
                
                # Log activity
                OfficerActivity.objects.create(
                    officer=officer,
                    activity_type='login',
                    description='Officer logged in'
                )
                
                return Response({
                    'token': token.key,
                    'officer': OfficerSerializer(officer).data
                })
            else:
                return Response(
                    {'error': 'Invalid credentials'},
                    status=status.HTTP_401_UNAUTHORIZED
                )
        except Officer.DoesNotExist:
            return Response(
                {'error': 'Invalid badge number'},
                status=status.HTTP_401_UNAUTHORIZED
            )


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register_officer(request):
    """Register a new officer"""
    serializer = OfficerRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        officer = serializer.save()
        token, created = Token.objects.get_or_create(user=officer)
        return Response({
            'token': token.key,
            'officer': OfficerSerializer(officer).data
        }, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def logout_officer(request):
    """Logout officer and delete token"""
    OfficerActivity.objects.create(
        officer=request.user,
        activity_type='logout',
        description='Officer logged out'
    )
    request.user.auth_token.delete()
    return Response({'message': 'Successfully logged out'})


class OfficerViewSet(viewsets.ModelViewSet):
    """ViewSet for Officer operations"""
    queryset = Officer.objects.all()
    serializer_class = OfficerSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    @action(detail=False, methods=['get'])
    def me(self, request):
        """Get current officer's profile"""
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)
    
    @action(detail=False, methods=['patch'])
    def update_status(self, request):
        """Update officer status"""
        serializer = OfficerStatusUpdateSerializer(
            request.user, 
            data=request.data, 
            partial=True
        )
        if serializer.is_valid():
            serializer.save()
            
            OfficerActivity.objects.create(
                officer=request.user,
                activity_type='status_change',
                description=f"Status changed to {request.data.get('status')}"
            )
            
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['patch'])
    def update_location(self, request):
        """Update officer location"""
        serializer = OfficerLocationUpdateSerializer(
            request.user, 
            data=request.data, 
            partial=True
        )
        if serializer.is_valid():
            serializer.save()
            
            OfficerActivity.objects.create(
                officer=request.user,
                activity_type='location_update',
                description='Location updated'
            )
            
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['get'])
    def statistics(self, request):
        """Get officer statistics"""
        officer = request.user
        today = timezone.now().date()
        
        # Today's statistics
        today_resolved = Emergency.objects.filter(
            assigned_officer=officer,
            status='resolved',
            resolved_at__date=today
        ).count()
        
        active_incidents = Emergency.objects.filter(
            assigned_officer=officer,
            status__in=['assigned', 'responding', 'pending']
        ).count()
        
        # All-time statistics
        total_resolved = Emergency.objects.filter(
            assigned_officer=officer,
            status='resolved'
        ).count()
        
        avg_response = Emergency.objects.filter(
            assigned_officer=officer,
            status='resolved',
            response_time__isnull=False
        ).aggregate(Avg('response_time'))['response_time__avg'] or 0
        
        return Response({
            'today_resolved': today_resolved,
            'active_incidents': active_incidents,
            'total_resolved': total_resolved,
            'average_response_time': round(avg_response, 2)
        })
    
    @action(detail=False, methods=['get'])
    def pending_emergencies(self, request):
        """Get emergencies pending for this officer"""
        emergencies = Emergency.objects.filter(
            status='pending',
            assigned_officer=request.user
        )
        serializer = EmergencySerializer(emergencies, many=True)
        return Response(serializer.data)


class EmergencyViewSet(viewsets.ModelViewSet):
    """ViewSet for Emergency operations"""
    queryset = Emergency.objects.all()
    serializer_class = EmergencySerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Filter emergencies based on user role"""
        queryset = Emergency.objects.all()
        
        # Filter by status
        status_param = self.request.query_params.get('status', None)
        if status_param:
            queryset = queryset.filter(status=status_param)
        
        # Filter by priority
        priority_param = self.request.query_params.get('priority', None)
        if priority_param:
            queryset = queryset.filter(priority=priority_param)
        
        # Filter by assigned officer
        if self.request.query_params.get('my_emergencies', None):
            queryset = queryset.filter(assigned_officer=self.request.user)
        
        return queryset
    
    @action(detail=True, methods=['post'])
    def assign_to_officer(self, request, pk=None):
        """Assign emergency to officer and send WebSocket notification"""
        emergency = self.get_object()
        officer_id = request.data.get('officer_id')
        
        if not officer_id:
            return Response(
                {'error': 'officer_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            officer = Officer.objects.get(id=officer_id)
        except Officer.DoesNotExist:
            return Response(
                {'error': 'Officer not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Check if emergency is already assigned
        if emergency.assigned_officer and emergency.status in ['assigned', 'responding']:
            return Response(
                {'error': 'Emergency already assigned to another officer'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Assign emergency
        emergency.assigned_officer = officer
        emergency.status = 'pending'  # Waiting for officer to accept
        emergency.assigned_at = timezone.now()
        emergency.save()
        
        # Send WebSocket notification to officer
        channel_layer = get_channel_layer()
        try:
            async_to_sync(channel_layer.group_send)(
                f'officer_{officer.badge_number}',
                {
                    'type': 'emergency_notification',
                    'emergency': {
                        'id': emergency.id,
                        'emergency_id': emergency.emergency_id,
                        'emergency_type': emergency.emergency_type,
                        'priority': emergency.priority,
                        'status': emergency.status,
                        'latitude': str(emergency.latitude),
                        'longitude': str(emergency.longitude),
                        'address': emergency.address,
                        'description': emergency.description,
                        'reporter_name': emergency.reporter_name,
                        'reporter_phone': emergency.reporter_phone,
                        'created_at': emergency.created_at.isoformat(),
                    }
                }
            )
            print(f"WebSocket notification sent to officer {officer.badge_number}")
        except Exception as e:
            print(f"Error sending WebSocket notification: {str(e)}")
        
        # Log activity
        OfficerActivity.objects.create(
            officer=officer,
            activity_type='emergency_accepted',
            emergency=emergency,
            description=f"Emergency {emergency.emergency_id} assigned (pending acceptance)"
        )
        
        return Response({
            'message': 'Emergency assigned successfully',
            'emergency': EmergencySerializer(emergency).data
        }, status=status.HTTP_200_OK)
    
    @action(detail=True, methods=['post'])
    def accept_emergency(self, request, pk=None):
        """Officer accepts an emergency"""
        emergency = self.get_object()
        
        # Check if emergency is assigned to this officer
        if emergency.assigned_officer != request.user:
            return Response(
                {'error': 'This emergency is not assigned to you'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Check if emergency is in pending state
        if emergency.status != 'pending':
            return Response(
                {'error': 'Emergency already processed'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Accept emergency
        emergency.status = 'assigned'
        emergency.responded_at = timezone.now()
        emergency.save()
        
        # Update officer status
        request.user.status = 'responding'
        request.user.save()
        
        # Log activity
        OfficerActivity.objects.create(
            officer=request.user,
            activity_type='emergency_accepted',
            emergency=emergency,
            description=f"Accepted emergency {emergency.emergency_id}"
        )
        
        return Response({
            'message': 'Emergency accepted successfully',
            'emergency': EmergencySerializer(emergency).data
        }, status=status.HTTP_200_OK)
    
    @action(detail=True, methods=['post'])
    def decline_emergency(self, request, pk=None):
        """Officer declines an emergency"""
        emergency = self.get_object()
        
        # Check if emergency is assigned to this officer
        if emergency.assigned_officer != request.user:
            return Response(
                {'error': 'This emergency is not assigned to you'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Get decline reason
        reason = request.data.get('reason', 'No reason provided')
        
        # Unassign officer and reset to pending
        emergency.assigned_officer = None
        emergency.status = 'pending'
        emergency.assigned_at = None
        emergency.save()
        
        # Log activity
        OfficerActivity.objects.create(
            officer=request.user,
            activity_type='status_change',
            emergency=emergency,
            description=f"Declined emergency {emergency.emergency_id}: {reason}"
        )
        
        return Response({
            'message': 'Emergency declined successfully',
            'reason': reason
        }, status=status.HTTP_200_OK)
    
    @action(detail=True, methods=['post'])
    def resolve_emergency(self, request, pk=None):
        """Resolve an emergency"""
        emergency = self.get_object()
        
        if emergency.assigned_officer != request.user:
            return Response(
                {'error': 'Not authorized to resolve this emergency'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        if emergency.status not in ['assigned', 'responding']:
            return Response(
                {'error': 'Emergency cannot be resolved in current state'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        emergency.status = 'resolved'
        emergency.resolved_at = timezone.now()
        emergency.resolution_notes = request.data.get('notes', '')
        
        # Calculate response time
        if emergency.assigned_at:
            time_diff = emergency.resolved_at - emergency.assigned_at
            emergency.response_time = time_diff.total_seconds() / 60
        
        emergency.save()
        
        # Update officer statistics
        officer = request.user
        officer.total_incidents_resolved += 1
        
        # Recalculate average response time
        avg_response = Emergency.objects.filter(
            assigned_officer=officer,
            status='resolved',
            response_time__isnull=False
        ).aggregate(Avg('response_time'))['response_time__avg']
        
        officer.average_response_time = avg_response or 0
        officer.status = 'available'
        officer.save()
        
        # Log activity
        OfficerActivity.objects.create(
            officer=request.user,
            activity_type='emergency_resolved',
            emergency=emergency,
            description=f"Resolved emergency {emergency.emergency_id}"
        )
        
        return Response({
            'message': 'Emergency resolved successfully',
            'emergency': EmergencySerializer(emergency).data
        }, status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['get'])
    def nearby(self, request):
        """Get nearby emergencies based on officer location"""
        latitude = request.query_params.get('latitude')
        longitude = request.query_params.get('longitude')
        radius = float(request.query_params.get('radius', 10))  # km
        
        if not latitude or not longitude:
            return Response(
                {'error': 'Latitude and longitude required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Simple distance calculation (for production, use PostGIS)
        # This is a rough calculation for demonstration
        emergencies = Emergency.objects.filter(
            status='pending',
            latitude__range=(float(latitude) - radius/111, float(latitude) + radius/111),
            longitude__range=(float(longitude) - radius/111, float(longitude) + radius/111)
        )
        
        serializer = self.get_serializer(emergencies, many=True)
        return Response(serializer.data)


class OfficerActivityViewSet(viewsets.ReadOnlyModelViewSet):
    """ViewSet for Officer Activity logs"""
    queryset = OfficerActivity.objects.all()
    serializer_class = OfficerActivitySerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get activities for current officer"""
        return OfficerActivity.objects.filter(officer=self.request.user)