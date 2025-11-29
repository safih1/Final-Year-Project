import React from "react";
import { Emergency, OfficerStatus } from "../types";

interface OfficerStatusPanelProps {
  status: OfficerStatus;
  emergency: Emergency | null;
  onManualTrigger: () => void;
  onResolveEmergency: () => void;
}

const StatusIndicator: React.FC<{ status: OfficerStatus }> = ({ status }) => {
  const baseClasses = "w-3 h-3 rounded-full";
  const statusConfig = {
    [OfficerStatus.ON_PATROL]: { color: "bg-green-500", label: "On Patrol" },
    [OfficerStatus.RESPONDING]: { color: "bg-yellow-500", label: "Responding" },
    [OfficerStatus.ON_SCENE]: { color: "bg-blue-500", label: "On Scene" },
  };
  const { color, label } = statusConfig[status];

  return (
    <div className="flex items-center space-x-2">
      <span className={`${baseClasses} ${color}`}></span>
      <span className="font-semibold text-gray-300">{label}</span>
    </div>
  );
};

export const OfficerStatusPanel: React.FC<OfficerStatusPanelProps> = ({
  status,
  emergency,
  onManualTrigger,
  onResolveEmergency,
}) => {
  return (
    <div className="bg-[#1a2b44] rounded-lg p-6 h-full border border-blue-900/50 flex flex-col">
      <h2 className="text-lg font-bold text-gray-100 mb-4">Officer Status</h2>
      <div className="mb-6">
        <StatusIndicator status={status} />
      </div>

      {emergency ? (
        <div className="flex-grow flex flex-col">
          <h3 className="text-blue-400 font-semibold mb-2">ACTIVE INCIDENT</h3>
          <div className="bg-blue-900/20 p-4 rounded-md flex-grow">
            <p className="text-sm text-gray-400">ID:</p>
            <p className="font-mono text-gray-200 mb-3">{emergency.id}</p>
            <p className="text-sm text-gray-400">Location:</p>
            <p className="text-gray-200 mb-3">{emergency.location}</p>
            <p className="text-sm text-gray-400">Reported:</p>
            <p className="text-gray-200">
              {new Date(emergency.timestamp).toLocaleTimeString()}
            </p>
          </div>
          <button
            onClick={onResolveEmergency}
            className="w-full mt-4 bg-blue-600 text-white font-bold py-3 px-4 rounded-md hover:bg-blue-500 transition-colors duration-200"
          >
            Mark as Resolved
          </button>
        </div>
      ) : (
        <div className="flex-grow flex flex-col justify-center items-center text-center">
          <div className="text-blue-700/50 mb-8">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              strokeWidth={1.5}
              stroke="currentColor"
              className="w-16 h-16 mx-auto mb-2"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <p className="text-gray-500">
              All clear. Awaiting new assignments.
            </p>
          </div>
          <button
            onClick={onManualTrigger}
            disabled={status === OfficerStatus.RESPONDING}
            className="w-full bg-red-600 text-white font-bold py-3 px-4 rounded-md hover:bg-red-500 transition-colors duration-200 disabled:bg-red-800/50 disabled:cursor-not-allowed disabled:opacity-60 flex items-center justify-center space-x-2"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="currentColor"
              className="w-5 h-5"
            >
              <path
                fillRule="evenodd"
                d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zM12.75 9a.75.75 0 00-1.5 0v5.25a.75.75 0 001.5 0V9z"
                clipRule="evenodd"
              />
              <path d="M12 7.5a1.125 1.125 0 100-2.25 1.125 1.125 0 000 2.25z" />
            </svg>
            <span>Manual Emergency Trigger</span>
          </button>
          <button
            onClick={onManualTrigger}
            disabled={true} // Always disabled
            className="w-full bg-gray-600 text-white font-bold py-3 px-4 rounded-md cursor-not-allowed opacity-60 flex items-center justify-center space-x-2"
          >
            <span>Manual Trigger Disabled</span>
          </button>
        </div>
      )}
    </div>
  );
};
