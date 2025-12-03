import { useEffect, useRef, useState, useCallback } from 'react';
import { Emergency, Coordinates } from '../types';

// Get backend IP from environment or use default
const BACKEND_IP = import.meta.env.VITE_BACKEND_IP || '192.168.1.8:8000';

export const useWebSocket = () => {
  const ws = useRef<WebSocket | null>(null);
  const [emergencies, setEmergencies] = useState<Emergency[]>([]);
  const locationIntervalRef = useRef<NodeJS.Timeout | null>(null);

  // Track which emergencies have officers assigned
  const assignedOfficers = useRef<Map<string, any>>(new Map());

  useEffect(() => {
    // Connect to police WebSocket
    const wsUrl = `ws://${BACKEND_IP}/ws/police/`;
    console.log('🔌 Connecting to WebSocket:', wsUrl);
    
    ws.current = new WebSocket(wsUrl);

    ws.current.onopen = () => {
      console.log('✅ Police WebSocket connected');
    };

    ws.current.onmessage = (event) => {
      const message = JSON.parse(event.data);
      console.log('📩 WebSocket received:', message);

      if (message.type === 'new_emergency') {
        handleNewEmergency(message.data);
      }

      // Handle officer location updates
      if (message.type === 'officer_location_update') {
        console.log('📍 Officer location update:', message.data);
      }

      // Handle task status updates
      if (message.type === 'task_status_update') {
        console.log('✅ Task status update:', message.data);
        handleTaskStatusUpdate(message.data);
      }

      // Handle threat resolved from user
      if (message.type === 'threat_resolved') {
        console.log('✅ Threat resolved by user:', message.data);
        removeEmergency(message.data.user_id);
      }
    };

    ws.current.onerror = (error) => {
      console.error('❌ WebSocket error:', error);
    };

    ws.current.onclose = () => {
      console.log('❌ WebSocket closed');
      // Attempt to reconnect after 3 seconds
      setTimeout(() => {
        console.log('🔄 Attempting to reconnect...');
        // Trigger re-render to reconnect
      }, 3000);
    };

    return () => {
      ws.current?.close();
      if (locationIntervalRef.current) {
        clearInterval(locationIntervalRef.current);
      }
    };
  }, []);

  const handleNewEmergency = async (data: any) => {
    const emergencyId = `E-${data.alert_id}`;

    const newEmergency: Emergency = {
      id: emergencyId,
      alertId: data.alert_id,
      location: data.location,
      timestamp: new Date(data.timestamp).getTime(),
      coordinates: data.coordinates,
      userId: data.user_id,
      userName: data.user_name,
      status: 'pending'
    };

    setEmergencies(prev => {
      // Avoid duplicates
      if (prev.some(e => e.id === emergencyId)) {
        return prev;
      }
      return [...prev, newEmergency];
    });

    console.log('🚨 New emergency added:', emergencyId);

    // Auto-assign nearest officer
    await autoAssignNearestOfficer(newEmergency);
  };

  const autoAssignNearestOfficer = async (emergency: Emergency) => {
    try {
      console.log('🔍 Finding nearest officer for emergency:', emergency.id);

      // Fetch available officers from backend
      const response = await fetch(`http://${BACKEND_IP}/api/emergency/police/officers/available/`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('access_token') || ''}`
        }
      });

      if (!response.ok) {
        console.error('❌ Failed to fetch officers:', response.status);
        return;
      }

      const officers = await response.json();
      console.log(`📋 Found ${officers.length} available officers`);

      if (officers.length === 0) {
        console.warn('⚠️ No available officers');
        // Show alert to user
        alert('No available officers at the moment. Emergency queued.');
        return;
      }

      // Calculate nearest officer
      const nearestOfficer = findNearestOfficer(officers, emergency.coordinates);

      if (nearestOfficer) {
        console.log(`✅ Nearest officer: ${nearestOfficer.name} (${nearestOfficer.distance_km} km away)`);
        
        // Assign officer via backend
        await assignOfficer(nearestOfficer.id, emergency.alertId);
      } else {
        console.warn('⚠️ Could not find nearest officer');
      }
    } catch (error) {
      console.error('❌ Error auto-assigning officer:', error);
    }
  };

  const findNearestOfficer = (officers: any[], emergencyCoords: Coordinates) => {
    let nearest = null;
    let minDistance = Infinity;

    officers.forEach(officer => {
      // Check if officer has location data
      if (officer.location && 
          officer.location.latitude !== null && 
          officer.location.longitude !== null) {
        
        const distance = calculateDistance(
          emergencyCoords.lat,
          emergencyCoords.lng,
          officer.location.latitude,
          officer.location.longitude
        );

        console.log(`📏 ${officer.name}: ${distance.toFixed(2)} km`);

        if (distance < minDistance) {
          minDistance = distance;
          nearest = { ...officer, distance_km: distance };
        }
      } else {
        console.warn(`⚠️ Officer ${officer.name} has no location data`);
      }
    });

    return nearest;
  };

  const calculateDistance = (lat1: number, lon1: number, lat2: number, lon2: number): number => {
    // Haversine formula
    const R = 6371; // Radius of Earth in km
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const distance = R * c;
    
    return distance;
  };

  const toRad = (degrees: number): number => {
    return degrees * (Math.PI / 180);
  };

  const assignOfficer = async (officerId: number, emergencyId: number) => {
    try {
      console.log(`📤 Assigning officer ${officerId} to emergency ${emergencyId}`);

      const response = await fetch(`http://${BACKEND_IP}/api/emergency/police/dispatch/assign/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('access_token') || ''}`
        },
        body: JSON.stringify({
          officer_id: officerId,
          emergency_id: emergencyId
        })
      });

      if (response.ok) {
        const data = await response.json();
        console.log('✅ Officer assigned successfully:', data);

        // Update local state
        assignedOfficers.current.set(`E-${emergencyId}`, data.officer);

        // Update emergency status
        setEmergencies(prev => prev.map(emergency => {
          if (emergency.alertId === emergencyId) {
            return { ...emergency, status: 'assigned' };
          }
          return emergency;
        }));

        // Show success notification
        showNotification('Officer Assigned', `${data.officer.name} has been assigned to emergency E-${emergencyId}`);
      } else {
        const error = await response.json();
        console.error('❌ Assignment failed:', error);
      }
    } catch (error) {
      console.error('❌ Error assigning officer:', error);
    }
  };

  const handleTaskStatusUpdate = (data: any) => {
    console.log('📊 Task status update:', data);

    setEmergencies(prev => prev.map(emergency => {
      if (emergency.alertId === data.emergency_id) {
        return { ...emergency, status: data.status };
      }
      return emergency;
    }));

    // Remove from list if resolved
    if (data.status === 'resolved') {
      setTimeout(() => {
        removeEmergency(data.emergency_id);
      }, 3000);
    }
  };

  const removeEmergency = (identifier: string | number) => {
    setEmergencies(prev => prev.filter(e =>
      e.id !== `E-${identifier}` &&
      e.alertId !== identifier &&
      e.userId !== identifier
    ));
  };

  const showNotification = (title: string, message: string) => {
    // Show browser notification if supported
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(title, {
        body: message,
        icon: '/police-badge.png'
      });
    }
    console.log(`🔔 ${title}: ${message}`);
  };

  const acceptEmergency = useCallback((emergency: Emergency, officerLocation: Coordinates) => {
    if (ws.current?.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify({
        type: 'accept_emergency',
        user_id: emergency.userId,
        alert_id: emergency.id,
        police_coordinates: {
          lat: officerLocation.lat,
          lng: officerLocation.lng,
        },
      }));

      // Start location updates
      if (locationIntervalRef.current) {
        clearInterval(locationIntervalRef.current);
      }

      locationIntervalRef.current = setInterval(() => {
        if (ws.current?.readyState === WebSocket.OPEN) {
          ws.current.send(JSON.stringify({
            type: 'location_update',
            user_id: emergency.userId,
            coordinates: {
              lat: officerLocation.lat,
              lng: officerLocation.lng,
            },
            eta: 5,
          }));
        }
      }, 5000);
    }
  }, []);

  const stopTracking = useCallback(() => {
    if (locationIntervalRef.current) {
      clearInterval(locationIntervalRef.current);
      locationIntervalRef.current = null;
      console.log('⏹️ Location tracking stopped');
    }
  }, []);

  const resolveEmergency = useCallback((userId: number) => {
    if (ws.current?.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify({
        type: 'resolve_emergency',
        user_id: userId,
      }));
      console.log(`✅ Sent resolve_emergency for user ${userId}`);
    }

    stopTracking();
  }, [stopTracking]);

  return {
    emergencies,
    setEmergencies,
    acceptEmergency,
    stopTracking,
    resolveEmergency,
    assignedOfficers: assignedOfficers.current
  };
};