from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    CustomAuthToken, register_officer, logout_officer,
    OfficerViewSet, EmergencyViewSet, OfficerActivityViewSet
)

router = DefaultRouter()
router.register(r'officers', OfficerViewSet, basename='officer')
router.register(r'emergencies', EmergencyViewSet, basename='emergency')
router.register(r'activities', OfficerActivityViewSet, basename='activity')

urlpatterns = [
    # Authentication
    path('auth/login/', CustomAuthToken.as_view(), name='login'),
    path('auth/register/', register_officer, name='register'),
    path('auth/logout/', logout_officer, name='logout'),
    
    # Router URLs
    path('', include(router.urls)),
]