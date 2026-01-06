from django.urls import path
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from emergency.consumers import UserConsumer, PoliceConsumer, EmergencyConsumer

websocket_urlpatterns = [
    path('ws/user/<int:user_id>/', UserConsumer.as_asgi()),
    path('ws/police/', PoliceConsumer.as_asgi()),
    path('ws/police/<int:officer_id>/', PoliceConsumer.as_asgi()),
    path('ws/emergency/<int:emergency_id>/', EmergencyConsumer.as_asgi()),

]