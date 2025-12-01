from django.urls import path
from . import views
from . import police_views

urlpatterns = [
    # Emergency Contacts CRUD
    path('contacts/', views.EmergencyContactListView.as_view(), name='emergency_contacts'),
    path('contacts/<int:pk>/', views.EmergencyContactDetailView.as_view(), name='emergency_contact_detail'),
    
    # Emergency Alerts
    path('trigger/', views.trigger_emergency, name='trigger_emergency'),
    path('alerts/', views.EmergencyAlertListView.as_view(), name='emergency_alerts'),
    
    # ⭐ PREDICTION ENDPOINTS - ALL THREE
    path('predict/', views.predict_movement, name='predict_movement'),
    path('predict-audio/', views.predict_audio, name='predict_audio'),
    path('predict-combined/', views.predict_combined, name='predict_combined'),  # ✅ ADDED THIS
    
    # Emergency Settings
    path('settings/', views.EmergencySettingsView.as_view(), name='emergency_settings'),
    
    # Admin Views
    path('admin/alerts/', views.admin_emergency_alerts, name='admin_emergency_alerts'),
    path('admin/contacts/', views.admin_all_contacts, name='admin_all_contacts'),
    path('high-risk-zones/', views.get_high_risk_zones, name='high_risk_zones'),

    # Police API Endpoints
    path('police/register/', police_views.police_register, name='police_register'),
    path('police/login/', police_views.police_login, name='police_login'),
    path('police/officers/available/', police_views.get_available_officers, name='get_available_officers'),
    path('police/officers/location/', police_views.update_officer_location_new, name='update_officer_location'),
    path('police/nearest/<int:emergency_id>/', police_views.get_nearest_officer, name='get_nearest_officer'),
    path('police/dispatch/assign/', police_views.assign_officer, name='assign_officer'),
    path('police/dispatch/tasks/', police_views.get_officer_tasks, name='get_officer_tasks'),
    path('police/dispatch/tasks/<int:pk>/status/', police_views.update_task_status, name='update_task_status'),
]