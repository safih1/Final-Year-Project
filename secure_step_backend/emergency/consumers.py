import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
import logging

logger = logging.getLogger(__name__)


class PoliceConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for police officers
    Each officer connects to: ws://backend/ws/police/{officer_id}/
    """
    
    async def connect(self):
        self.officer_id = self.scope['url_route']['kwargs'].get('officer_id')
        self.officer_group = f'officer_{self.officer_id}'
        
        # Join officer-specific group
        await self.channel_layer.group_add(
            self.officer_group,
            self.channel_name
        )
        
        # Join police dashboard group
        await self.channel_layer.group_add(
            'police_dashboard',
            self.channel_name
        )
        
        await self.accept()
        logger.info(f"✅ Officer {self.officer_id} connected to WebSocket")
    
    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.officer_group,
            self.channel_name
        )
        await self.channel_layer.group_discard(
            'police_dashboard',
            self.channel_name
        )
        logger.info(f"❌ Officer {self.officer_id} disconnected")
    
    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
            message_type = data.get('type')
            
            if message_type == 'location_update':
                await self.handle_location_update(data)
            elif message_type == 'task_accepted':
                await self.handle_task_accepted(data)
            
        except Exception as e:
            logger.error(f"Error in receive: {e}")
    
    async def handle_location_update(self, data):
        pass  # handled via HTTP
    
    async def handle_task_accepted(self, data):
        pass  # handled via HTTP
    
    # Events
    async def new_task(self, event):
        await self.send(text_data=json.dumps({
            'type': 'new_task',
            'task_id': event['task_id'],
            'emergency': event['emergency']
        }))
        logger.info(f"📤 Sent new task to officer {self.officer_id}")
    
    async def emergency_alert(self, event):
        await self.send(text_data=json.dumps({
            'type': 'new_emergency',
            'data': {
                'alert_id': event['alert_id'],
                'user_id': event['user_id'],
                'user_name': event['user_name'],
                'location': event['location'],
                'coordinates': event['coordinates'],
                'timestamp': event['timestamp']
            }
        }))
        logger.info(f"📤 Emergency alert sent to officer {self.officer_id}")
    
    async def task_status_update(self, event):
        await self.send(text_data=json.dumps({
            'type': 'task_status_update',
            'data': {
                'task_id': event['task_id'],
                'emergency_id': event['emergency_id'],
                'status': event['status'],
                'timestamp': event['timestamp']
            }
        }))


class UserConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for emergency app users
    Each user connects to: ws://backend/ws/user/{user_id}/
    """
    
    async def connect(self):
        self.user_id = self.scope['url_route']['kwargs'].get('user_id')
        self.user_group = f'user_{self.user_id}'
        
        await self.channel_layer.group_add(
            self.user_group,
            self.channel_name
        )
        
        await self.accept()
        logger.info(f"✅ User {self.user_id} connected to WebSocket")
    
    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.user_group,
            self.channel_name
        )
        logger.info(f"❌ User {self.user_id} disconnected")
    
    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
            message_type = data.get('type')
            
            if message_type == 'emergency_triggered':
                logger.info(f"🚨 Emergency triggered by user {self.user_id}")
            elif message_type == 'emergency_cancelled':
                logger.info(f"✅ Emergency cancelled by user {self.user_id}")
                
        except Exception as e:
            logger.error(f"Error in receive: {e}")
    
    # Events
    async def officer_location(self, event):
        await self.send(text_data=json.dumps({
            'type': 'officer_location',
            'officer_id': event['officer_id'],
            'officer_name': event['officer_name'],
            'badge_number': event['badge_number'],
            'emergency_id': event['emergency_id'],
            'coordinates': event['coordinates'],
            'eta': event['eta'],
            'timestamp': event['timestamp']
        }))
        logger.info(f"📤 Officer location sent to user {self.user_id}")
    
    async def officer_assigned(self, event):
        await self.send(text_data=json.dumps({
            'type': 'officer_assigned',
            'officer_name': event['officer_name'],
            'badge_number': event['badge_number'],
            'emergency_id': event['emergency_id'],
            'message': event['message']
        }))
        logger.info(f"📤 Officer assignment notification sent to user {self.user_id}")
    
    async def emergency_resolved(self, event):
        await self.send(text_data=json.dumps({
            'type': 'emergency_resolved',
            'emergency_id': event['emergency_id'],
            'message': event['message']
        }))
        logger.info(f"📤 Resolution notification sent to user {self.user_id}")
    
    async def threat_resolved(self, event):
        await self.send(text_data=json.dumps({
            'type': 'threat_resolved',
            'message': 'Your emergency has been marked as resolved'
        }))
