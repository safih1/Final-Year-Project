from django.contrib import admin
from .models import EmergencyContact, EmergencyAlert, EmergencySettings

@admin.register(EmergencyContact)
class EmergencyContactAdmin(admin.ModelAdmin):
    list_display = ['name', 'phone_number', 'user', 'relationship', 'is_primary', 'created_at', 'updated_at']
    list_filter = ['is_primary', 'relationship', 'created_at', 'updated_at']
    search_fields = ['name', 'phone_number', 'user__full_name', 'user__email']
    list_per_page = 25
    ordering = ['-created_at']
    
    def get_readonly_fields(self, request, obj=None):
        if obj:  # Editing an existing object
            return ['user', 'created_at', 'updated_at']
        return ['created_at', 'updated_at']

    fieldsets = (
        ('Contact Information', {
            'fields': ('user', 'name', 'phone_number', 'relationship')
        }),
        ('Settings', {
            'fields': ('is_primary',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )

@admin.register(EmergencyAlert)
class EmergencyAlertAdmin(admin.ModelAdmin):
    list_display = ['user', 'alert_type', 'status', 'location_address', 'created_at', 'resolved_at']
    list_filter = ['alert_type', 'status', 'created_at']
    search_fields = ['user__full_name', 'user__email', 'location_address', 'description']
    readonly_fields = ['created_at']
    list_per_page = 25
    ordering = ['-created_at']
    
    fieldsets = (
        ('Alert Information', {
            'fields': ('user', 'alert_type', 'status', 'description')
        }),
        ('Location', {
            'fields': ('location_latitude', 'location_longitude', 'location_address')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'resolved_at')
        }),
    )

@admin.register(EmergencySettings)
class EmergencySettingsAdmin(admin.ModelAdmin):
    list_display = ['user', 'video_monitoring', 'motion_detection', 'camera_monitoring', 'auto_call_authorities']
    search_fields = ['user__full_name', 'user__email']
    list_filter = ['video_monitoring', 'motion_detection', 'camera_monitoring', 'auto_call_authorities']
    
    fieldsets = (
        ('User', {
            'fields': ('user',)
        }),
        ('Monitoring Settings', {
            'fields': ('video_monitoring', 'motion_detection', 'camera_monitoring')
        }),
        ('Emergency Settings', {
            'fields': ('auto_call_authorities', 'emergency_message')
        }),
    )