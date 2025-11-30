from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Officer, Emergency, OfficerActivity

@admin.register(Officer)
class OfficerAdmin(UserAdmin):
    list_display = ['badge_number', 'get_full_name', 'email', 'status', 'total_incidents_resolved']
    list_filter = ['status', 'date_joined']
    search_fields = ['badge_number', 'first_name', 'last_name', 'email']
    
    fieldsets = UserAdmin.fieldsets + (
        ('Officer Information', {
            'fields': ('badge_number', 'phone_number', 'status', 'profile_image')
        }),
        ('Location', {
            'fields': ('current_latitude', 'current_longitude')
        }),
        ('Statistics', {
            'fields': ('total_incidents_resolved', 'average_response_time')
        }),
    )
    
    add_fieldsets = UserAdmin.add_fieldsets + (
        ('Officer Information', {
            'fields': ('badge_number', 'phone_number', 'email', 'first_name', 'last_name')
        }),
    )


@admin.register(Emergency)
class EmergencyAdmin(admin.ModelAdmin):
    list_display = ['emergency_id', 'emergency_type', 'priority', 'status', 'assigned_officer', 'created_at']
    list_filter = ['status', 'priority', 'emergency_type', 'created_at']
    search_fields = ['emergency_id', 'description', 'address']
    readonly_fields = ['emergency_id', 'created_at', 'response_time']


@admin.register(OfficerActivity)
class OfficerActivityAdmin(admin.ModelAdmin):
    list_display = ['officer', 'activity_type', 'emergency', 'timestamp']
    list_filter = ['activity_type', 'timestamp']
    search_fields = ['officer__badge_number', 'description']
    readonly_fields = ['timestamp']