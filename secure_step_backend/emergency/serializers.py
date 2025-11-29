from rest_framework import serializers
from .models import EmergencyContact, EmergencyAlert, EmergencySettings
from .models import OfficerLocation
import re

class EmergencyContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = ['id', 'name', 'phone_number', 'relationship', 'is_primary', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def validate_phone_number(self, value):
        # Remove all non-digit characters for validation
        digits_only = re.sub(r'\D', '', value)
        
        # Check if it has at least 10 digits
        if len(digits_only) < 10:
            raise serializers.ValidationError("Phone number must have at least 10 digits.")
        
        # Check if it has too many digits
        if len(digits_only) > 15:
            raise serializers.ValidationError("Phone number is too long.")
        
        return value

    def validate_name(self, value):
        if len(value.strip()) < 2:
            raise serializers.ValidationError("Contact name must be at least 2 characters long.")
        
        return value.strip()

    def validate(self, attrs):
        # Check for duplicate phone numbers for the same user
        user = self.context['request'].user
        phone_number = attrs.get('phone_number')
        
        # For updates, exclude the current instance
        queryset = EmergencyContact.objects.filter(user=user, phone_number=phone_number)
        if self.instance:
            queryset = queryset.exclude(id=self.instance.id)
        
        if queryset.exists():
            raise serializers.ValidationError({
                'phone_number': 'You already have an emergency contact with this phone number.'
            })
        
        return attrs

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)

class EmergencyAlertSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    
    class Meta:
        model = EmergencyAlert
        fields = ['id', 'user_name', 'user_email', 'alert_type', 'status', 
                 'location_latitude', 'location_longitude', 'location_address', 
                 'description', 'created_at', 'resolved_at']
        read_only_fields = ['id', 'user_name', 'user_email', 'created_at']

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)

class EmergencySettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencySettings
        fields = ['video_monitoring', 'motion_detection', 'camera_monitoring', 
                 'auto_call_authorities', 'emergency_message']
        
    def validate_emergency_message(self, value):
        if len(value.strip()) < 10:
            raise serializers.ValidationError("Emergency message must be at least 10 characters long.")
        
        if len(value) > 500:
            raise serializers.ValidationError("Emergency message cannot exceed 500 characters.")
        
        return value.strip()



class OfficerLocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = OfficerLocation
        fields = ['id', 'officer', 'emergency', 'latitude', 'longitude', 'updated_at']
        read_only_fields = ['id', 'updated_at']