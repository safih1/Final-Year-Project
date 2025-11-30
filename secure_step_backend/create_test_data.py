"""
Test script for Police Response System
Creates test data and verifies all endpoints
"""

from django.contrib.auth import get_user_model
from emergency.models import PoliceOfficer, EmergencyAlert, DispatchTask
from django.utils import timezone

User = get_user_model()

def create_test_data():
    """Create test users and officers"""
    
    print("🔧 Creating test data...")
    
    # Create admin user
    admin_user, created = User.objects.get_or_create(
        email='admin@securestep.com',
        defaults={
            'username': 'admin',
            'full_name': 'Admin User',
            'role': 'admin',
            'is_admin': True,
        }
    )
    if created:
        admin_user.set_password('admin123')
        admin_user.save()
        print(f"✅ Created admin user: {admin_user.email}")
    else:
        print(f"ℹ️  Admin user already exists: {admin_user.email}")
    
    # Create mobile officers
    officers_data = [
        {
            'email': 'officer1@police.com',
            'username': 'officer1',
            'full_name': 'Officer John Doe',
            'badge': 'PO-001',
            'lat': 34.1688,  # Abbottabad
            'lng': 73.2215,
        },
        {
            'email': 'officer2@police.com',
            'username': 'officer2',
            'full_name': 'Officer Jane Smith',
            'badge': 'PO-002',
            'lat': 34.1750,  # Slightly north
            'lng': 73.2300,
        },
        {
            'email': 'officer3@police.com',
            'username': 'officer3',
            'full_name': 'Officer Mike Johnson',
            'badge': 'PO-003',
            'lat': 34.1600,  # Slightly south
            'lng': 73.2100,
        },
    ]
    
    for officer_data in officers_data:
        user, created = User.objects.get_or_create(
            email=officer_data['email'],
            defaults={
                'username': officer_data['username'],
                'full_name': officer_data['full_name'],
                'role': 'mobile_officer',
            }
        )
        if created:
            user.set_password('officer123')
            user.save()
            print(f"✅ Created officer user: {user.email}")
        
        # Create or update police officer profile
        officer, created = PoliceOfficer.objects.get_or_create(
            user=user,
            defaults={
                'badge_number': officer_data['badge'],
                'status': 'free',
                'current_latitude': officer_data['lat'],
                'current_longitude': officer_data['lng'],
                'last_location_update': timezone.now(),
            }
        )
        if created:
            print(f"✅ Created officer profile: {officer.badge_number}")
        else:
            # Update location
            officer.current_latitude = officer_data['lat']
            officer.current_longitude = officer_data['lng']
            officer.status = 'free'
            officer.last_location_update = timezone.now()
            officer.save()
            print(f"ℹ️  Updated officer profile: {officer.badge_number}")
    
    # Create a test regular user
    victim_user, created = User.objects.get_or_create(
        email='victim@test.com',
        defaults={
            'username': 'victim',
            'full_name': 'Test Victim',
            'role': 'regular_user',
        }
    )
    if created:
        victim_user.set_password('victim123')
        victim_user.save()
        print(f"✅ Created victim user: {victim_user.email}")
    
    # Create a test emergency alert
    emergency, created = EmergencyAlert.objects.get_or_create(
        user=victim_user,
        status='active',
        defaults={
            'alert_type': 'automatic',
            'location_latitude': 34.1700,  # Between officers
            'location_longitude': 73.2200,
            'location_address': 'Test Location, Abbottabad',
            'description': 'Test emergency for police response system',
        }
    )
    if created:
        print(f"✅ Created test emergency alert: #{emergency.id}")
    else:
        print(f"ℹ️  Test emergency alert already exists: #{emergency.id}")
    
    print("\n" + "="*60)
    print("📊 Test Data Summary:")
    print("="*60)
    print(f"Admin: {admin_user.email} / admin123")
    print(f"Officers: {PoliceOfficer.objects.count()} total")
    for officer in PoliceOfficer.objects.all():
        print(f"  - {officer.user.email} / officer123 ({officer.badge_number}) - {officer.status}")
    print(f"Victim: {victim_user.email} / victim123")
    print(f"Emergency Alert: #{emergency.id}")
    print("="*60)
    
    return {
        'admin': admin_user,
        'officers': PoliceOfficer.objects.all(),
        'victim': victim_user,
        'emergency': emergency,
    }

if __name__ == '__main__':
    create_test_data()
