from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, AdminUser

@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['email', 'full_name', 'username', 'is_admin', 'emergency_count', 'created_at']
    list_filter = ['is_admin', 'is_active', 'created_at']
    search_fields = ['email', 'full_name', 'username']
    ordering = ['email']
    
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Additional Info', {'fields': ('full_name', 'phone_number', 'profile_picture', 'emergency_count', 'is_admin')}),
    )
    
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Additional Info', {'fields': ('email', 'full_name', 'phone_number')}),
    )

@admin.register(AdminUser)
class AdminUserAdmin(admin.ModelAdmin):
    list_display = ['user', 'admin_level', 'created_at']
    list_filter = ['admin_level', 'created_at']
    search_fields = ['user__full_name', 'user__email']