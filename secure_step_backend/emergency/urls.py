from django.urls import path
from . import views

urlpatterns = [
    # Emergency Contacts CRUD
    path('contacts/', views.EmergencyContactListView.as_view(), name='emergency_contacts'),
    path('contacts/<int:pk>/', views.EmergencyContactDetailView.as_view(), name='emergency_contact_detail'),
    
    # Emergency Alerts
    path('trigger/', views.trigger_emergency, name='trigger_emergency'),
    path('alerts/', views.EmergencyAlertListView.as_view(), name='emergency_alerts'),
    path('predict/', views.predict_movement, name='predict_movement'),
    path('predict-audio/', views.predict_audio, name='predict_audio'),
    
    # Emergency Settings
    path('settings/', views.EmergencySettingsView.as_view(), name='emergency_settings'),
    
    # Admin Views
    path('admin/alerts/', views.admin_emergency_alerts, name='admin_emergency_alerts'),
    path('admin/contacts/', views.admin_all_contacts, name='admin_all_contacts'),
    path("api/officer/update-location/", views.update_officer_location, name="update_officer_location"),
    path('high-risk-zones/', views.get_high_risk_zones, name='high_risk_zones'),
]