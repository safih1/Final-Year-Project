from django.db import models
from django.conf import settings
from django.core.validators import RegexValidator

class EmergencyContact(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, 
                           related_name='emergency_contacts')
    name = models.CharField(max_length=100)
    phone_number = models.CharField(
        max_length=20,
        validators=[
            RegexValidator(
                regex=r'^[\+]?[1-9][\d\-\(\)\s]{9,20}$',
                message="Phone number must be valid format"
            )
        ]
    )
    relationship = models.CharField(max_length=50, blank=True, default='Contact')
    is_primary = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ['user', 'phone_number']
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name} - {self.phone_number} (Contact for {self.user.full_name})"

    def save(self, *args, **kwargs):
        # Ensure only one primary contact per user
        if self.is_primary:
            EmergencyContact.objects.filter(user=self.user, is_primary=True).update(is_primary=False)
        super().save(*args, **kwargs)

class EmergencyAlert(models.Model):
    ALERT_STATUS = [
        ('active', 'Active'),
        ('resolved', 'Resolved'),
        ('false_alarm', 'False Alarm'),
    ]
    
    ALERT_TYPE = [
        ('manual', 'Manual Trigger'),
        ('automatic', 'Automatic Detection'),
        ('panic', 'Panic Button'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, 
                           related_name='emergency_alerts')
    alert_type = models.CharField(max_length=20, choices=ALERT_TYPE, default='manual')
    status = models.CharField(max_length=20, choices=ALERT_STATUS, default='active')
    location_latitude = models.DecimalField(max_digits=10, decimal_places=8, null=True, blank=True)
    location_longitude = models.DecimalField(max_digits=11, decimal_places=8, null=True, blank=True)
    location_address = models.TextField(blank=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Emergency Alert - {self.user.full_name} ({self.created_at})"

class EmergencySettings(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                              related_name='emergency_settings')
    video_monitoring = models.BooleanField(default=True)
    motion_detection = models.BooleanField(default=True)
    camera_monitoring = models.BooleanField(default=False)
    auto_call_authorities = models.BooleanField(default=False)
    emergency_message = models.TextField(default="I need help! This is an emergency.")
    
    def __str__(self):
        return f"Settings for {self.user.full_name}"

class OfficerLocation(models.Model):
    officer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    emergency = models.ForeignKey(EmergencyAlert, on_delete=models.CASCADE)
    latitude = models.FloatField()
    longitude = models.FloatField()
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('officer', 'emergency')

    def __str__(self):
        return f"{self.officer.email} -> {self.emergency.id}"

class HighRiskZone(models.Model):
    RISK_LEVELS = [
        ('low', 'Low Risk'),
        ('medium', 'Medium Risk'),
        ('high', 'High Risk'),
        ('extreme', 'Extreme Risk'),
    ]
    
    name = models.CharField(max_length=200)
    description = models.TextField()
    latitude = models.DecimalField(max_digits=10, decimal_places=8)
    longitude = models.DecimalField(max_digits=11, decimal_places=8)
    radius_meters = models.FloatField()
    risk_level = models.CharField(max_length=20, choices=RISK_LEVELS, default='medium')
    image_url = models.URLField(blank=True, null=True)
    last_incident = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)
    
    def __str__(self):
        return f"{self.name} ({self.risk_level})"
    
    class Meta:
        ordering = ['-risk_level', '-last_incident']

class PoliceOfficer(models.Model):
    STATUS_CHOICES = [
        ('available', 'Available'),
        ('busy', 'Busy'),
        ('offline', 'Offline'),
        ('en_route', 'En Route'),
        ('on_scene', 'On Scene'),
    ]

    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='officer_profile')
    badge_number = models.CharField(max_length=20, unique=True)
    rank = models.CharField(max_length=50, default='Officer')
    station = models.CharField(max_length=100, default='Main Station')
    is_active = models.BooleanField(default=True)
    current_latitude = models.DecimalField(max_digits=10, decimal_places=8, null=True, blank=True)
    current_longitude = models.DecimalField(max_digits=11, decimal_places=8, null=True, blank=True)
    last_location_update = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='offline')
    
    def __str__(self):
        return f"{self.rank} {self.user.full_name} ({self.badge_number})"

class DispatchTask(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('declined', 'Declined'),
        ('en_route', 'En Route'),
        ('arrived', 'Arrived'),
        ('resolved', 'Resolved'),
    ]

    emergency = models.ForeignKey(EmergencyAlert, on_delete=models.CASCADE, related_name='dispatch_tasks')
    officer = models.ForeignKey(PoliceOfficer, on_delete=models.CASCADE, related_name='tasks')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    assigned_at = models.DateTimeField(auto_now_add=True)
    accepted_at = models.DateTimeField(null=True, blank=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-assigned_at']

    def __str__(self):
        return f"Task: {self.officer.badge_number} -> {self.emergency.id} ({self.status})"