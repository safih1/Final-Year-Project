from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    path('register/', views.RegisterView.as_view(), name='register'),
    path('login/', views.login_view, name='login'),
    path('admin-login/', views.admin_login_view, name='admin_login'),
    path('profile/', views.ProfileView.as_view(), name='profile'),
    path('users/', views.get_all_users, name='all_users'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]