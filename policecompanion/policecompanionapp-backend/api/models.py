from django.db import models
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.core.validators import RegexValidator
from django.utils import timezone


class OfficerManager(BaseUserManager):
    """Custom manager for Officer model"""
    
    def _create_user(self, badge_number, email, password, **extra_fields):
        """Create and save a user with the given badge_number, email, and password."""
        if not badge_number:
            raise ValueError('The Badge Number must be set')
        if not email:
            raise ValueError('The Email must be set')
        
        email = self.normalize_email(email)
        user = self.model(badge_number=badge_number, username=badge_number, email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user
    
    def create_user(self, badge_number, email=None, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', False)
        extra_fields.setdefault('is_superuser', False)
        return self._create_user(badge_number, email, password, **extra_fields)
    
    def create_superuser(self, badge_number, email=None, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        
        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')
        
        return self._create_user(badge_number, email, password, **extra_fields)


class Officer(AbstractUser):
    """Extended User model for Police Officers"""
    
    STATUS_CHOICES = [
        ('available', 'Available'),
        ('on_duty', 'On Duty'),
        ('off_duty', 'Off Duty'),
        ('responding', 'Responding to Emergency'),
    ]
    
    badge_number = models.CharField(
        max_length=20, 
        unique=True,
        validators=[RegexValidator(r'^[A-Z]-\d{5}$', 'Badge format: A-12345')]
    )
    phone_number = models.CharField(max_length=15, blank=True)
    status = models.CharField(
        max_length=20, 
        choices=STATUS_CHOICES, 
        default='off_duty'
    )
    current_latitude = models.DecimalField(
        max_digits=9, 
        decimal_places=6, 
        null=True, 
        blank=True
    )
    current_longitude = models.DecimalField(
        max_digits=9, 
        decimal_places=6, 
        null=True, 
        blank=True
    )
    profile_image = models.ImageField(
        upload_to='officer_profiles/', 
        null=True, 
        blank=True
    )
    
    # Statistics
    total_incidents_resolved = models.IntegerField(default=0)
    average_response_time = models.FloatField(default=0.0)
    
    objects = OfficerManager()
    
    USERNAME_FIELD = 'badge_number'
    REQUIRED_FIELDS = ['email']
    
    class Meta:
        db_table = 'officers'
        ordering = ['-date_joined']
    
    def __str__(self):
        return f"{self.badge_number} - {self.get_full_name()}"


class Emergency(models.Model):
    """Emergency incidents reported in the system"""
    
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
        ('critical', 'Critical'),
    ]
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('assigned', 'Assigned'),
        ('responding', 'Responding'),
        ('resolved', 'Resolved'),
        ('cancelled', 'Cancelled'),
    ]
    
    TYPE_CHOICES = [
        ('medical', 'Medical Emergency'),
        ('fire', 'Fire'),
        ('crime', 'Crime in Progress'),
        ('accident', 'Traffic Accident'),
        ('domestic', 'Domestic Violence'),
        ('theft', 'Theft/Robbery'),
        ('other', 'Other'),
    ]
    
    emergency_id = models.CharField(max_length=20, unique=True, editable=False)
    emergency_type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    address = models.TextField()
    
    description = models.TextField()
    reporter_name = models.CharField(max_length=100, null=True, blank=True)
    reporter_phone = models.CharField(max_length=15, null=True, blank=True)
    
    assigned_officer = models.ForeignKey(
        Officer, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        related_name='assigned_emergencies'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    assigned_at = models.DateTimeField(null=True, blank=True)
    responded_at = models.DateTimeField(null=True, blank=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    
    response_time = models.FloatField(null=True, blank=True)
    resolution_notes = models.TextField(null=True, blank=True)
    
    class Meta:
        db_table = 'emergencies'
        ordering = ['-created_at']
    
    def save(self, *args, **kwargs):
        if not self.emergency_id:
            self.emergency_id = f"EMG-{timezone.now().strftime('%Y%m%d%H%M%S')}"
        super().save(*args, **kwargs)
    
    def __str__(self):
        return f"{self.emergency_id} - {self.get_emergency_type_display()}"


class OfficerActivity(models.Model):
    """Track officer activity logs"""
    
    ACTIVITY_CHOICES = [
        ('login', 'Login'),
        ('logout', 'Logout'),
        ('status_change', 'Status Change'),
        ('emergency_accepted', 'Emergency Accepted'),
        ('emergency_resolved', 'Emergency Resolved'),
        ('location_update', 'Location Update'),
    ]
    
    officer = models.ForeignKey(Officer, on_delete=models.CASCADE, related_name='activities')
    activity_type = models.CharField(max_length=30, choices=ACTIVITY_CHOICES)
    description = models.TextField(null=True, blank=True)
    emergency = models.ForeignKey(
        Emergency, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True
    )
    timestamp = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'officer_activities'
        ordering = ['-timestamp']
        verbose_name_plural = 'Officer Activities'
    
    def __str__(self):
        return f"{self.officer.badge_number} - {self.get_activity_type_display()}"