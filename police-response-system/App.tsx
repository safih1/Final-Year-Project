import React, { useState, useEffect, useCallback } from 'react';
import { Dashboard } from './components/Dashboard';
import { Header } from './components/Header';
import { EmergencyNotification } from './components/EmergencyNotification';
import { Emergency, OfficerStatus } from './types';
import { useGeolocation } from './hooks/useGeolocation';
import { useWebSocket } from './hooks/useWebSocket';

const App: React.FC = () => {
  const [acceptedEmergency, setAcceptedEmergency] = useState<Emergency | null>(null);
  const [officerStatus, setOfficerStatus] = useState<OfficerStatus>(OfficerStatus.ON_PATROL);
  const { location: officerLocation, getLocation, error: locationError } = useGeolocation();
  
  const { emergencies, setEmergencies, acceptEmergency, stopTracking, resolveEmergency } = useWebSocket();

  const handleAcceptEmergency = useCallback((emergencyId: string) => {
    const emergency = emergencies.find(e => e.id === emergencyId);
    if (emergency) {
      console.log(`Accepting emergency: ${emergencyId}`);
      getLocation();
      setAcceptedEmergency(emergency);
      setEmergencies(prev => prev.filter(e => e.id !== emergencyId));
      setOfficerStatus(OfficerStatus.RESPONDING);
    }
  }, [emergencies, getLocation, setEmergencies]);

  useEffect(() => {
    if (officerLocation && officerStatus === OfficerStatus.RESPONDING && acceptedEmergency) {
      console.log('Officer location obtained:', officerLocation);
      acceptEmergency(acceptedEmergency, officerLocation);
    }
    if (locationError) {
      console.error("Geolocation error:", locationError);
      alert(`Could not get location: ${locationError}`);
    }
  }, [officerLocation, officerStatus, locationError, acceptedEmergency, acceptEmergency]);

  const handleDeclineEmergency = useCallback((emergencyId: string) => {
    console.log(`Declining emergency: ${emergencyId}`);
    setEmergencies(prev => prev.filter(e => e.id !== emergencyId));
  }, [setEmergencies]);

  const handleResolveEmergency = useCallback(() => {
    if (acceptedEmergency?.userId) {
      console.log(`Resolving emergency: ${acceptedEmergency.id} for user ${acceptedEmergency.userId}`);
      resolveEmergency(acceptedEmergency.userId);
    }
    setAcceptedEmergency(null);
    setOfficerStatus(OfficerStatus.ON_PATROL);
  }, [acceptedEmergency, resolveEmergency]);

  return (
    <div className="min-h-screen bg-[#0d1a2e] text-gray-200 font-sans flex flex-col">
      <Header />
      <main className="flex-grow p-4 lg:p-6">
        <Dashboard
          officerStatus={officerStatus}
          acceptedEmergency={acceptedEmergency}
          officerLocation={officerLocation}
          onManualTrigger={() => {}} // Disabled
          onResolveEmergency={handleResolveEmergency}
          acceptEmergency={acceptEmergency}
        />
      </main>
      
      <div className="fixed top-20 right-4 space-y-4 z-50">
        {emergencies.map(emergency => (
          <EmergencyNotification
            key={emergency.id}
            emergency={emergency}
            onAccept={handleAcceptEmergency}
            onDecline={handleDeclineEmergency}
          />
        ))}
      </div>
    </div>
  );
};

export default App;