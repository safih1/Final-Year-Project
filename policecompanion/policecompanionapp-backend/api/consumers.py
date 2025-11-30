import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from .models import Officer

class OfficerConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.badge_number = self.scope['url_route']['kwargs']['badge_number']
        self.room_group_name = f'officer_{self.badge_number}'
        
        # Verify officer exists
        officer = await self.get_officer(self.badge_number)
        if officer:
            # Join room group
            await self.channel_layer.group_add(
                self.room_group_name,
                self.channel_name
            )
            await self.accept()
            
            # Send connection confirmation
            await self.send(text_data=json.dumps({
                'type': 'connection_established',
                'message': 'Connected to emergency notifications'
            }))
        else:
            await self.close()
    
    async def disconnect(self, close_code):
        # Leave room group
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )
    
    # Receive message from WebSocket
    async def receive(self, text_data):
        data = json.loads(text_data)
        message_type = data.get('type')
        
        if message_type == 'ping':
            await self.send(text_data=json.dumps({
                'type': 'pong',
                'timestamp': data.get('timestamp')
            }))
    
    # Receive emergency notification from channel layer
    async def emergency_notification(self, event):
        # Send emergency to WebSocket
        await self.send(text_data=json.dumps({
            'type': 'emergency_assigned',
            'emergency': event['emergency']
        }))
    
    @database_sync_to_async
    def get_officer(self, badge_number):
        try:
            return Officer.objects.get(badge_number=badge_number)
        except Officer.DoesNotExist:
            return None