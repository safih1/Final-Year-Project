from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from .models import Officer, Emergency, OfficerActivity

class OfficerRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True, required=True)
    
    class Meta:
        model = Officer
        fields = [
            'badge_number', 'email', 'first_name', 'last_name', 
            'phone_number', 'password', 'password2'
        ]
    
    def validate(self, attrs):
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({"password": "Password fields didn't match."})
        return attrs
    
    def create(self, validated_data):
        validated_data.pop('password2')
        officer = Officer.objects.create_user(
            badge_number=validated_data['badge_number'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ""),
            last_name=validated_data.get('last_name', ""),
            phone_number=validated_data.get('phone_number', "")
        )
        return officer

class OfficerSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()
    
    class Meta:
        model = Officer
        fields = [
            'id', 'badge_number', 'email', 'first_name', 'last_name', 
            'full_name', 'phone_number', 'status', 'current_latitude', 
            'current_longitude', 'profile_image', 'total_incidents_resolved',
            'average_response_time', 'date_joined'
        ]
        read_only_fields = ['total_incidents_resolved', 'average_response_time']
    
    def get_full_name(self, obj):
        return obj.get_full_name()


class OfficerStatusUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Officer
        fields = ['status']


class OfficerLocationUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Officer
        fields = ['current_latitude', 'current_longitude']


class EmergencySerializer(serializers.ModelSerializer):
    assigned_officer_details = OfficerSerializer(source='assigned_officer', read_only=True)
    
    class Meta:
        model = Emergency
        fields = '__all__'
        read_only_fields = ['emergency_id', 'created_at', 'response_time']


class OfficerActivitySerializer(serializers.ModelSerializer):
    officer_name = serializers.CharField(source='officer.get_full_name', read_only=True)
    
    class Meta:
        model = OfficerActivity
        fields = '__all__'