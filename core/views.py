from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import PoliceOfficer, Alert
from .serializers import PoliceOfficerSerializer, AlertSerializer

class PoliceOfficerViewSet(viewsets.ModelViewSet):
    queryset = PoliceOfficer.objects.all()
    serializer_class = PoliceOfficerSerializer

class AlertViewSet(viewsets.ModelViewSet):
    queryset = Alert.objects.all().order_by('-created_at')
    serializer_class = AlertSerializer

    @action(detail=True, methods=['post'])
    def accept(self, request, pk=None):
        alert = self.get_object()
        officer_id = request.data.get('officer_id')
        lat = request.data.get('lat')
        lng = request.data.get('lng')
        eta = request.data.get('eta')

        try:
            officer = PoliceOfficer.objects.get(id=officer_id)
        except PoliceOfficer.DoesNotExist:
            return Response({'error': 'Officer not found'}, status=404)

        alert.accepted_by = officer
        alert.officer_lat = lat
        alert.officer_lng = lng
        alert.eta = eta
        alert.save()

        officer.current_lat = lat
        officer.current_lng = lng
        officer.eta = eta
        officer.save()

        return Response({'message': 'Alert accepted', 'alert_id': alert.id})
