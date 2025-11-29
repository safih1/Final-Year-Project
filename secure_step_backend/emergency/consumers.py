import json
from channels.generic.websocket import AsyncWebsocketConsumer

class UserConsumer(AsyncWebsocketConsumer):
    """WebSocket for individual users to receive police location updates"""
    
    async def connect(self):
        self.user_id = self.scope['url_route']['kwargs']['user_id']
        self.user_group = f"user_{self.user_id}"
        
        await self.channel_layer.group_add(self.user_group, self.channel_name)
        await self.accept()
        print(f"User {self.user_id} WebSocket connected")

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.user_group, self.channel_name)
        print(f"User {self.user_id} WebSocket disconnected")

    async def receive(self, text_data):
        data = json.loads(text_data)
        print(f"Received from user {self.user_id}: {data}")
        
        if data['type'] == 'emergency_trigger':
            # Broadcast to police
            await self.channel_layer.group_send(
                "police_dashboard",
                {
                    'type': 'emergency_alert',
                    'alert_id': data['alert_id'],
                    'user_id': data['user_id'],
                    'user_name': data['user_name'],
                    'location': data['location'],
                    'coordinates': data['coordinates'],
                    'timestamp': data['timestamp'],
                }
            )
        
        elif data['type'] == 'no_threat':
            # User says no threat - notify police to stop
            print(f"User {self.user_id} reported no threat")
            await self.channel_layer.group_send(
                "police_dashboard",
                {
                    'type': 'threat_resolved',
                    'user_id': self.user_id,
                    'reason': 'user_cancelled',
                }
            )

    async def police_location(self, event):
        """Send police location to user"""
        await self.send(text_data=json.dumps({
            'type': 'location_update',
            'data': event
        }))
    
    async def emergency_resolved(self, event):
        """Police resolved the emergency"""
        await self.send(text_data=json.dumps({
            'type': 'emergency_resolved',
            'data': event
        }))


class PoliceConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        await self.channel_layer.group_add("police_dashboard", self.channel_name)
        await self.accept()
        print(f"Police WebSocket connected")

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard("police_dashboard", self.channel_name)

    async def receive(self, text_data):
        data = json.loads(text_data)
        print(f"Received from police: {data}")
        
        if data['type'] == 'accept_emergency':
            user_id = data['user_id']
            user_group = f"user_{user_id}"
            
            print(f"Police accepted emergency for user {user_id}")
            
            # Send to user
            await self.channel_layer.group_send(
                user_group,
                {
                    'type': 'police_location',
                    'alert_id': data['alert_id'],
                    'coordinates': data['police_coordinates'],
                    'status': 'responding',
                    'eta': 5,
                }
            )
            
        elif data['type'] == 'location_update':
            user_id = data['user_id']
            user_group = f"user_{user_id}"
            
            # Send to user
            await self.channel_layer.group_send(
                user_group,
                {
                    'type': 'police_location',
                    'coordinates': data['coordinates'],
                    'eta': data.get('eta', 5),
                }
            )
        
        elif data['type'] == 'resolve_emergency':
            user_id = data['user_id']
            user_group = f"user_{user_id}"
            
            print(f"Police resolved emergency for user {user_id}")
            
            # Notify user that emergency is resolved
            await self.channel_layer.group_send(
                user_group,
                {
                    'type': 'emergency_resolved',
                    'reason': 'police_resolved',
                    'message': 'Emergency has been resolved by police',
                }
            )

    async def emergency_alert(self, event):
        await self.send(text_data=json.dumps({
            'type': 'new_emergency',
            'data': event
        }))
    
    async def threat_resolved(self, event):
        """User cancelled the emergency"""
        await self.send(text_data=json.dumps({
            'type': 'threat_resolved',
            'data': event
        }))