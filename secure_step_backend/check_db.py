import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'secure_step_backend.settings')
django.setup()

from emergency.models import EmergencyAlert, PoliceOfficer
from accounts.models import User

def check_db():
    print(f"Users count: {User.objects.count()}")
    print(f"Officers count: {PoliceOfficer.objects.count()}")
    print(f"Emergency Alerts count: {EmergencyAlert.objects.count()}")
    
    alerts = EmergencyAlert.objects.all().order_by('-created_at')
    for alert in alerts:
        print(f"Alert ID: {alert.id}, User: {alert.user.email}, Status: {alert.status}, Created: {alert.created_at}")

if __name__ == "__main__":
    check_db()
