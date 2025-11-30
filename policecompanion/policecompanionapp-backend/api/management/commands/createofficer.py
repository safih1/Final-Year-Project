from django.core.management.base import BaseCommand
from django.core.validators import validate_email
from django.core.exceptions import ValidationError
from api.models import Officer
import getpass


class Command(BaseCommand):
    help = 'Create a superuser officer'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Creating superuser officer...'))
        
        # Get badge number
        while True:
            badge_number = input('Badge number (format A-12345): ')
            if badge_number:
                break
            self.stdout.write(self.style.ERROR('Badge number is required'))
        
        # Get email
        while True:
            email = input('Email address: ')
            try:
                validate_email(email)
                break
            except ValidationError:
                self.stdout.write(self.style.ERROR('Invalid email address'))
        
        # Get first name
        first_name = input('First name: ')
        
        # Get last name
        last_name = input('Last name: ')

        user_name = input('Username: ')
        
        # Get phone number
        phone_number = input('Phone number: ')
        
        # Get password
        while True:
            password = getpass.getpass('Password: ')
            password2 = getpass.getpass('Password (again): ')
            if password == password2:
                if len(password) < 3:
                    self.stdout.write(self.style.ERROR('Password too short'))
                    continue
                break
            else:
                self.stdout.write(self.style.ERROR('Passwords do not match'))
        
        # Create superuser
        try:
            officer = Officer.objects.create_superuser(
                badge_number=badge_number,
                email=email,
                password=password,
                first_name=first_name,
                user_name=user_name,
                last_name=last_name,
                phone_number=phone_number
            )
            self.stdout.write(self.style.SUCCESS(f'Superuser officer {badge_number} created successfully!'))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error creating superuser: {str(e)}'))