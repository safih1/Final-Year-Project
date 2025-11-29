import React, { useState } from "react";
import { Emergency, OfficerStatus, Coordinates } from "../types";
import { OfficerStatusPanel } from "./OfficerStatusPanel";
import { MapPlaceholder } from "./MapPlaceholder";

interface DashboardProps {
  officerStatus: OfficerStatus;
  acceptedEmergency: Emergency | null;
  officerLocation: Coordinates | null;
  onManualTrigger: () => void;
  onResolveEmergency: () => void;
  acceptEmergency: (emergency: Emergency, officerLocation: Coordinates) => void;
}

export const Dashboard: React.FC<DashboardProps> = ({
  officerStatus,
  acceptedEmergency,
  officerLocation,
  onManualTrigger,
  onResolveEmergency,
  acceptEmergency,
}) => {
  const [officers, setOfficers] = useState([
    { id: 1, name: "Officer Ali", lat: 34.2, lng: 73.24, assigned: false },
    { id: 2, name: "Officer Ahmed", lat: 34.205, lng: 73.242, assigned: false },
    { id: 3, name: "Officer Sara", lat: 34.202, lng: 73.245, assigned: false },
  ]);

  const toggleAssignOfficer = (id: number) => {
    setOfficers((prev) =>
      prev.map((o) => (o.id === id ? { ...o, assigned: !o.assigned } : { ...o, assigned: false }))
    );
  };

  const handleStartTracking = () => {
    const assignedOfficer = officers.find(o => o.assigned);
    
    if (!assignedOfficer || !acceptedEmergency) {
      alert("Please select an officer first!");
      return;
    }

    console.log(`Assigning ${assignedOfficer.name} to emergency ${acceptedEmergency.id}`);
    
    // Call the WebSocket acceptEmergency function
    acceptEmergency(acceptedEmergency, {
      lat: assignedOfficer.lat,
      lng: assignedOfficer.lng,
    });

    alert(`${assignedOfficer.name} assigned! Location updates started.`);
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 h-full">
      <div className="lg:col-span-1">
        <OfficerStatusPanel
          status={officerStatus}
          emergency={acceptedEmergency}
          onManualTrigger={onManualTrigger}
          onResolveEmergency={onResolveEmergency}
        />

        {acceptedEmergency && (
          <div className="mt-4 p-3 bg-gray-800 rounded-lg">
            <h3 className="text-white font-semibold mb-2">
              Assign Officer for Emergency {acceptedEmergency.id}
            </h3>
            {officers.map((officer) => (
              <div key={officer.id} className="flex items-center space-x-2 mb-2">
                <input
                  type="radio"
                  name="officer"
                  checked={officer.assigned}
                  onChange={() => toggleAssignOfficer(officer.id)}
                />
                <span className="text-gray-300">{officer.name}</span>
              </div>
            ))}
            <button
              onClick={handleStartTracking}
              className="mt-3 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-500 w-full"
            >
              Assign & Start Tracking
            </button>
          </div>
        )}
      </div>

      <div className="lg:col-span-2 min-h-[400px] lg:min-h-0">
        <MapPlaceholder
          officerLocation={officerLocation}
          emergencyLocation={acceptedEmergency?.coordinates ?? null}
        />
      </div>
    </div>
  );
};