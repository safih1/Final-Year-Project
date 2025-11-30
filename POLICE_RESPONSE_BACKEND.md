# Police Response System - Backend Implementation Complete

## ✅ Completed Backend Features

### 1. Database Models

#### User Role System
- Added `role` field to User model with choices: `regular_user`, `mobile_officer`, `admin`
- Role-based access control for all endpoints

#### PoliceOfficer Model
```python
- user (OneToOne with User)
- badge_number (unique)
- status (free/assigned/offline)
- current_latitude, current_longitude
- last_location_update
```

#### DispatchTask Model
```python
- officer (ForeignKey to PoliceOfficer)
- emergency (ForeignKey to EmergencyAlert)
- status (pending/accepted/declined/en_route/arrived/resolved)
- assigned_at, accepted_at, arrived_at, resolved_at
- notes
```

### 2. API Endpoints

All endpoints are available at `http://192.168.1.5:8000/api/emergency/`

#### Police Officer Authentication
- `POST /police/login/` - Officer login (checks mobile_officer role)
  - Returns: tokens, user info, officer profile

#### Admin Endpoints (Admin Role Required)
- `GET /police/officers/available/` - Get all free officers with locations
- `GET /police/nearest/<emergency_id>/` - Calculate nearest officer to emergency
  - Uses Haversine formula for distance calculation
  - Returns sorted list of all available officers by distance
- `POST /police/dispatch/assign/` - Assign officer to emergency
  - Creates DispatchTask
  - Updates officer status to 'assigned'
  - Sends WebSocket notification to officer

#### Mobile Officer Endpoints (Mobile Officer Role Required)
- `POST /police/officers/location/` - Update officer's current location
  - Broadcasts location update via WebSocket
- `GET /police/dispatch/tasks/` - Get officer's assigned tasks
- `PUT /police/dispatch/tasks/<task_id>/status/` - Update task status
  - Statuses: accepted, declined, en_route, arrived, resolved
  - Auto-updates officer status when task resolved/declined

### 3. Real-time Features

#### WebSocket Channels
- `police_dashboard` - Admin dashboard receives:
  - Officer location updates
  - Task status updates
  - Emergency alerts

- `officer_{officer_id}` - Individual officer receives:
  - Task assignments with victim location
  - Emergency details

### 4. Distance Calculation

Implemented Haversine formula for accurate distance calculation between:
- Officer current location
- Emergency victim location

Returns distance in kilometers, sorted nearest first.

---

## 📋 API Usage Examples

### 1. Police Officer Login
```bash
POST /api/emergency/police/login/
{
  "email": "officer@police.com",
  "password": "password123"
}
```

### 2. Update Officer Location (from Companion App)
```bash
POST /api/emergency/police/officers/location/
Headers: Authorization: Bearer <token>
{
  "latitude": 34.1688,
  "longitude": 73.2215
}
```

### 3. Get Nearest Officer (Admin Dashboard)
```bash
GET /api/emergency/police/nearest/5/
Headers: Authorization: Bearer <admin_token>

Response:
{
  "nearest_officer": {
    "id": 1,
    "badge_number": "PO-001",
    "name": "Officer John",
    "distance_km": 2.5,
    "location": {...}
  },
  "all_available_officers": [...]
}
```

### 4. Assign Officer to Emergency
```bash
POST /api/emergency/police/dispatch/assign/
Headers: Authorization: Bearer <admin_token>
{
  "officer_id": 1,
  "emergency_id": 5
}
```

### 5. Officer Accepts Task
```bash
PUT /api/emergency/police/dispatch/tasks/1/status/
Headers: Authorization: Bearer <officer_token>
{
  "status": "accepted"
}
```

---

## 🚀 Next Steps

### Admin Dashboard (Web Application)
You need to create a web application with:

1. **Login Page**
   - Email/password authentication
   - Role check (admin only)

2. **Main Dashboard**
   - Real-time map (Google Maps / Leaflet)
   - Officer markers (green=free, red=assigned)
   - Emergency alert popup when threat detected
   - Victim location marker

3. **Dispatch Interface**
   - Click emergency to see nearest officers
   - List of available officers with distances
   - Assign button for each officer
   - Task status tracking

### Companion Mobile App (Flutter)
You need to create a Flutter app with:

1. **Officer Login**
   - Use `/api/emergency/police/login/`
   - Store tokens securely

2. **Background Location Service**
   - Continuous GPS tracking
   - POST to `/api/emergency/police/officers/location/` every 30 seconds
   - Works in background

3. **Task Notifications**
   - Listen to WebSocket for task assignments
   - Show popup with emergency details
   - Display victim location on map
   - Navigation to victim (Google Maps integration)

4. **Task Management**
   - Accept/Decline buttons
   - Status updates (En Route, Arrived, Resolved)
   - PUT to `/api/emergency/police/dispatch/tasks/<id>/status/`

---

## 🔧 Database Migrations

Run these commands to apply the new models:

```bash
cd secure_step_backend
python manage.py makemigrations
python manage.py migrate
```

---

## 👮 Creating Police Officers

You'll need to create police officer accounts:

```python
# In Django shell or admin panel
from accounts.models import User
from emergency.models import PoliceOfficer

# Create officer user
officer_user = User.objects.create_user(
    email='officer1@police.com',
    username='officer1',
    password='password123',
    full_name='Officer John Doe',
    role='mobile_officer'
)

# Create officer profile
PoliceOfficer.objects.create(
    user=officer_user,
    badge_number='PO-001',
    status='offline'
)
```

---

## 🎯 Integration with Threat Detection

When a threat is detected from the movement detection app:

1. **Automatic Flow:**
   - Threat detected → Emergency alert created
   - WebSocket broadcasts to admin dashboard
   - Admin sees popup with victim location
   - Admin clicks "Get Nearest Officer"
   - System calculates and suggests nearest officer
   - Admin clicks "Assign"
   - Officer receives notification on companion app
   - Officer accepts and navigates to victim

2. **Manual Approval:**
   - System suggests nearest officer
   - Admin reviews and confirms assignment
   - Prevents accidental assignments

---

## 📱 Technology Stack Recommendations

### Admin Dashboard
- **React** + Leaflet/Google Maps
- **Vue.js** + Mapbox
- **Plain HTML/JS** + Leaflet (simplest)

### Companion App
- **Flutter** (cross-platform)
- Background location: `geolocator` + `flutter_background_service`
- Maps: `google_maps_flutter`
- WebSocket: `web_socket_channel`

---

## ✨ Features Summary

✅ Role-based authentication (admin/mobile_officer/regular_user)
✅ Officer location tracking
✅ Nearest officer calculation (Haversine distance)
✅ Task assignment system with admin approval
✅ Real-time WebSocket updates
✅ Task status workflow (pending → accepted → en_route → arrived → resolved)
✅ Automatic officer status management
✅ Complete REST API for all operations

**Ready for frontend development!** 🎉
