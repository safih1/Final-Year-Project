from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from emergency.models import PoliceOfficer, EmergencyAlert
from django.utils import timezone

User = get_user_model()

class Command(BaseCommand):
    help = 'Create test data for police response system'

    def handle(self, *args, **kwargs):
        self.stdout.write("🔧 Creating test data...")
        
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
            self.stdout.write(self.style.SUCCESS(f"✅ Created admin user: {admin_user.email}"))
        else:
            self.stdout.write(self.style.WARNING(f"ℹ️  Admin user already exists: {admin_user.email}"))
        
        # Create mobile officers
        officers_data = [
            {
                'email': 'officer1@police.com',
                'username': 'officer1',
                'full_name': 'Officer John Doe',
                'badge': 'PO-001',
                'lat': 34.1688,
                'lng': 73.2215,
            },
            {
                'email': 'officer2@police.com',
                'username': 'officer2',
                'full_name': 'Officer Jane Smith',
                'badge': 'PO-002',
                'lat': 34.1750,
                'lng': 73.2300,
            },
            {
                'email': 'officer3@police.com',
                'username': 'officer3',
                'full_name': 'Officer Mike Johnson',
                'badge': 'PO-003',
                'lat': 34.1600,
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
                self.stdout.write(self.style.SUCCESS(f"✅ Created officer user: {user.email}"))
            
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
                self.stdout.write(self.style.SUCCESS(f"✅ Created officer profile: {officer.badge_number}"))
            else:
                officer.current_latitude = officer_data['lat']
                officer.current_longitude = officer_data['lng']
                officer.status = 'free'
                officer.last_location_update = timezone.now()
                officer.save()
                self.stdout.write(self.style.WARNING(f"ℹ️  Updated officer profile: {officer.badge_number}"))
        
        # Create victim user
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
            self.stdout.write(self.style.SUCCESS(f"✅ Created victim user: {victim_user.email}"))
        
        # Create test emergency
        emergency, created = EmergencyAlert.objects.get_or_create(
            user=victim_user,
            status='active',
            defaults={
                'alert_type': 'automatic',
                'location_latitude': 34.1700,
                'location_longitude': 73.2200,
                'location_address': 'Test Location, Abbottabad',
                'description': 'Test emergency for police response system',
            }
        )
        if created:
            self.stdout.write(self.style.SUCCESS(f"✅ Created test emergency: #{emergency.id}"))
        else:
            self.stdout.write(self.style.WARNING(f"ℹ️  Test emergency exists: #{emergency.id}"))
        
        self.stdout.write("\n" + "="*60)
        self.stdout.write("📊 Test Data Summary:")
        self.stdout.write("="*60)
        self.stdout.write(f"Admin: {admin_user.email} / admin123")
        self.stdout.write(f"Officers: {PoliceOfficer.objects.count()} total")
        for officer in PoliceOfficer.objects.all():
            self.stdout.write(f"  - {officer.user.email} / officer123 ({officer.badge_number}) - {officer.status}")
        self.stdout.write(f"Victim: {victim_user.email} / victim123")
        self.stdout.write(f"Emergency Alert: #{emergency.id}")
        self.stdout.write("="*60)
