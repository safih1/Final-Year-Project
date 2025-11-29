# Manual Backend Execution Guide

To run the SecureStep backend manually, you need to run three separate components. Open **3 separate terminal windows** for this.

## ⚠️ Critical First Step: Firewall Rule
You **MUST** run this command once in a **PowerShell (Administrator)** window to allow the app to connect:
```powershell
netsh advfirewall firewall add rule name="Django Dev Server" dir=in action=allow protocol=TCP localport=8000
```

## Prerequisites
1. **Redis Server**: You must have Redis running.
   - If you have Docker: `docker run -p 6379:6379 -d redis`
   - If installed locally on Windows: Start the `redis-server` service.

## Terminal 1: Django Server
This runs the main API and WebSocket server.
```powershell
cd secure_step_backend
python manage.py runserver 0.0.0.0:8000
```

## Terminal 2: Celery Worker
This processes background tasks (like sending emergency notifications).
**Note for Windows**: We use `-P solo` or `-P threads` because the default `prefork` doesn't work well on Windows.
```powershell
cd secure_step_backend
celery -A secure_step_backend worker -l info -P solo
```

## Terminal 3: Celery Beat (Optional)
Only needed if you have scheduled periodic tasks (e.g., daily cleanup). If you don't have scheduled tasks, you can skip this.
```powershell
cd secure_step_backend
celery -A secure_step_backend beat -l info
```

## Troubleshooting
- **"Address already in use"**: Make sure no other python process is running.
- **Connection Failed**: Ensure you ran the firewall command above!
- **Redis Connection Error**: Ensure Redis is running on `127.0.0.1:6379`.
