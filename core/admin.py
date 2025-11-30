from django.contrib import admin
from .models import PoliceOfficer, Alert

@admin.register(PoliceOfficer)
class PoliceOfficerAdmin(admin.ModelAdmin):
    list_display = ('id','name','badge_id','current_lat','current_lng')

@admin.register(Alert)
class AlertAdmin(admin.ModelAdmin):
    list_display = ('id','message','created_at','accepted_by')
