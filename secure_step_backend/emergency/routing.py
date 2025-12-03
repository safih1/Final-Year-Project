from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    # Police officer WebSocket - connects with officer_id
    re_path(r'ws/police/(?P<officer_id>\d+)/$', consumers.PoliceConsumer.as_asgi()),
    
    # User WebSocket - connects with user_id
    re_path(r'ws/user/(?P<user_id>\d+)/$', consumers.UserConsumer.as_asgi()),
    
    # Legacy police dashboard (for web dashboard without officer_id)
    re_path(r'ws/police/$', consumers.PoliceConsumer.as_asgi()),
]