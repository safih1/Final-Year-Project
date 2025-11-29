import { useEffect, useRef, useState, useCallback } from 'react';
import { Emergency, Coordinates } from '../types';

const DUMMY_POLICE = [
  { id: 1, name: 'Officer Ali', lat: 34.1688, lng: 73.2215 },
  { id: 2, name: 'Officer Sara', lat: 34.1700, lng: 73.2230 },
  { id: 3, name: 'Officer Ahmed', lat: 34.1650, lng: 73.2200 },
];

export const useWebSocket = () => {
  const ws = useRef<WebSocket | null>(null);
  const [emergencies, setEmergencies] = useState<Emergency[]>([]);
  const locationIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const [selectedOfficer] = useState(DUMMY_POLICE[0]);
  
  // Track already seen emergency IDs to prevent duplicates
  const seenEmergencyIds = useRef<Set<string>>(new Set());

  useEffect(() => {
    ws.current = new WebSocket('ws://172.20.10.5:8080/ws/police/');

    ws.current.onopen = () => console.log('Police WebSocket connected');
    
    ws.current.onmessage = (event) => {
      const message = JSON.parse(event.data);
      console.log('WebSocket received:', message);

      if (message.type === 'new_emergency') {
        const emergencyId = `E-${message.data.alert_id}`;
        
        // Check if we've already processed this emergency
        if (seenEmergencyIds.current.has(emergencyId)) {
          console.log(`Duplicate emergency ${emergencyId} ignored`);
          return;
        }
        
        // Add to seen set
        seenEmergencyIds.current.add(emergencyId);
        
        const newEmergency: Emergency = {
          id: emergencyId,
          location: message.data.location,
          timestamp: new Date(message.data.timestamp).getTime(),
          coordinates: message.data.coordinates,
          userId: message.data.user_id,
          userName: message.data.user_name,
        };
        
        setEmergencies(prev => {
          // Double-check it's not already in the array
          if (prev.some(e => e.id === emergencyId)) {
            return prev;
          }
          return [...prev, newEmergency];
        });
      }
    };

    ws.current.onerror = (error) => console.error('WebSocket error:', error);
    ws.current.onclose = () => {
      console.log('WebSocket closed');
      // Clear seen IDs on disconnect
      seenEmergencyIds.current.clear();
    };

    return () => {
      ws.current?.close();
      if (locationIntervalRef.current) {
        clearInterval(locationIntervalRef.current);
      }
    };
  }, []);

  const acceptEmergency = useCallback((emergency: Emergency, officerLocation: Coordinates) => {
    if (ws.current?.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify({
        type: 'accept_emergency',
        user_id: emergency.userId,
        alert_id: emergency.id,
        police_coordinates: {
          lat: selectedOfficer.lat,
          lng: selectedOfficer.lng,
        },
      }));

      // Clear any existing interval first
      if (locationIntervalRef.current) {
        clearInterval(locationIntervalRef.current);
      }

      // Start new interval
      locationIntervalRef.current = setInterval(() => {
        if (ws.current?.readyState === WebSocket.OPEN) {
          ws.current.send(JSON.stringify({
            type: 'location_update',
            user_id: emergency.userId,
            coordinates: {
              lat: selectedOfficer.lat,
              lng: selectedOfficer.lng,
            },
            eta: 5,
          }));
        }
      }, 5000);
    }
  }, [selectedOfficer]);

  const stopTracking = useCallback(() => {
    if (locationIntervalRef.current) {
      clearInterval(locationIntervalRef.current);
      locationIntervalRef.current = null;
      console.log('Location tracking stopped');
    }
  }, []);
  
  const resolveEmergency = useCallback((userId: number) => {
    // Send resolve message to backend
    if (ws.current?.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify({
        type: 'resolve_emergency',
        user_id: userId,
      }));
      console.log(`Sent resolve_emergency for user ${userId}`);
    }
    
    stopTracking();
  }, [stopTracking]);

  return { emergencies, setEmergencies, acceptEmergency, stopTracking, resolveEmergency };
};