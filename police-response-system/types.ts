
export interface Emergency {
  id: string;
  alertId: number; // added to store backend alert identifier
  location: string;
  timestamp: number;
  coordinates: {
    lat: number;
    lng: number;
  };
  userId?: number;
  userName?: string;
  status?: string;
}

export enum OfficerStatus {
  ON_PATROL = 'On Patrol',
  RESPONDING = 'Responding',
  ON_SCENE = 'On Scene', // Future use
}

export interface Coordinates {
  lat: number;
  lng: number;
}
