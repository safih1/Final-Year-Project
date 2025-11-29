
import React from 'react';
import { Coordinates } from '../types';

interface MapPlaceholderProps {
  officerLocation: Coordinates | null;
  emergencyLocation: Coordinates | null;
}

const PinIcon: React.FC<{color: string}> = ({ color }) => (
    <svg viewBox="0 0 24 24" fill={color} className="w-8 h-8" xmlns="http://www.w3.org/2000/svg">
        <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
    </svg>
);


export const MapPlaceholder: React.FC<MapPlaceholderProps> = ({ officerLocation, emergencyLocation }) => {
  return (
    <div className="relative w-full h-full bg-[#1a2b44] rounded-lg overflow-hidden border border-blue-900/50">
      {/* Map background pattern */}
      <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxwYXRoIGZpbGw9IiMwZDFhMmUiIGQ9Ik0wIDBoNDB2NDBIMHoiLz48cGF0aCBzdHJva2U9IiMxYTJiNDQiIGQ9Ik0yMCAwYzYuOTA2IDAgMTIuNSAzLjMwOCAxMi41IDcuMzkyIDAgMy4yMjgtMi40MjggNS44MzUtNS42MjUgNi44NzJDNDAgMjAuNzI4IDQwIDI2LjM4OCAgNDAgNDBoLjc1Ii8+PHBhdGggc3Ryb2tlPSIjMWEyYjQ0IiBkPSJNMCAyMGwzLjkzOC0uMzc1QzYuOTgzIDE5LjI5MiA4LjczIDE4LjUgMTAuNSAxNy41YzIuMDM0LTEuMTcgMy44NzUtMi41NzMgNi4yNS0yLjU3MyAzLjM3MyAwIDQuNTIxIDIuNDQgNS40MzggMy4yOTJDNjAgMjAgMjAuNzI4IDQwIDI2LjM4OCAgNDAgNDBoLjc1IiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwIDApIHJvdGF0ZSgtOTAgMjAgMjApIi8+PC9nPjwvc3ZnPg==')] opacity-60"></div>

      <div className="absolute inset-0 flex items-center justify-center">
        {!emergencyLocation && (
          <div className="text-center text-blue-800">
            <h3 className="text-lg font-semibold text-gray-500">Awaiting Assignment</h3>
            <p className="text-sm text-gray-600">Map will display active incident location.</p>
          </div>
        )}
      </div>

      {/* Emergency Pin */}
      {emergencyLocation && (
        <div className="absolute top-[30%] left-[60%] -translate-x-1/2 -translate-y-1/2 text-center">
            <PinIcon color="#ef4444" />
            <span className="text-xs font-bold text-red-400 bg-gray-900/60 px-2 py-1 rounded">EMERGENCY</span>
        </div>
      )}
      
      {/* Officer Pin */}
      {officerLocation && emergencyLocation && (
        <div className="absolute bottom-[20%] left-[30%] -translate-x-1/2 -translate-y-1/2 text-center">
            <PinIcon color="#3b82f6" />
            <span className="text-xs font-bold text-blue-400 bg-gray-900/60 px-2 py-1 rounded">UNIT 74-D</span>
        </div>
      )}

      <div className="absolute top-2 left-2 bg-gray-900/70 text-gray-300 text-xs px-2 py-1 rounded">
        CITY GRID: ABBOTTABAD
      </div>
    </div>
  );
};
