import React from 'react';
import { Emergency } from '../types';

interface EmergencyNotificationProps {
  emergency: Emergency;
  onAccept: (id: string) => void;
  onDecline: (id: string) => void;
}

export const EmergencyNotification: React.FC<EmergencyNotificationProps> = ({
  emergency,
  onAccept,
  onDecline,
}) => {
  const formatTime = (timestamp: number) => {
    const date = new Date(timestamp);
    return date.toLocaleTimeString('en-US', { 
      hour: '2-digit', 
      minute: '2-digit',
      second: '2-digit'
    });
  };

  return (
    <div className="bg-red-900 border-2 border-red-500 rounded-lg p-4 shadow-2xl animate-pulse min-w-[320px] max-w-[400px]">
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center space-x-2">
          <div className="bg-red-500 rounded-full p-2">
            <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <div>
            <h3 className="font-bold text-white text-lg"> EMERGENCY ALERT</h3>
            <p className="text-red-200 text-sm">{formatTime(emergency.timestamp)}</p>
          </div>
        </div>
      </div>

      <div className="space-y-2 mb-4">
        <div className="bg-black bg-opacity-30 rounded p-2">
          <p className="text-white text-sm">
            <strong>ID:</strong> {emergency.id}
          </p>
          {emergency.userName && (
            <p className="text-white text-sm">
              <strong>User:</strong> {emergency.userName}
            </p>
          )}
          <p className="text-white text-sm">
            <strong>Location:</strong> {emergency.location}
          </p>
          <p className="text-white text-sm">
            <strong>Coordinates:</strong> {emergency.coordinates.lat.toFixed(4)}, {emergency.coordinates.lng.toFixed(4)}
          </p>
        </div>
      </div>

      <div className="flex space-x-2">
        <button
          onClick={() => onAccept(emergency.id)}
          className="flex-1 bg-green-600 hover:bg-green-700 text-white font-bold py-2 px-4 rounded-md transition-colors duration-200 flex items-center justify-center space-x-2"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
          </svg>
          <span>Accept</span>
        </button>
        <button
          onClick={() => onDecline(emergency.id)}
          className="flex-1 bg-gray-600 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded-md transition-colors duration-200 flex items-center justify-center space-x-2"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
          <span>Decline</span>
        </button>
      </div>
    </div>
  );
};