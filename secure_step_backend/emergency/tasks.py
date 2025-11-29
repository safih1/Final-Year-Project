from celery import shared_task
from django.core.mail import send_mail
from django.conf import settings
from .models import EmergencyAlert
import logging

logger = logging.getLogger(__name__)

@shared_task(bind=True, max_retries=3)
def send_emergency_notifications(self, alert_id):
    """Send emergency notifications to contacts and authorities"""
    try:
        alert = EmergencyAlert.objects.get(id=alert_id)
        user = alert.user

        # Get emergency contacts
        contacts = user.emergency_contacts.all()

        # Location details
        location_info = alert.location_address or f"Lat: {alert.location_latitude}, Lng: {alert.location_longitude}"

        # Main emergency message
        message = f"""
        🚨 EMERGENCY ALERT 🚨
        
        {user.full_name} has triggered an emergency alert.
        
        Location: {location_info}
        Time: {alert.created_at}
        Type: {alert.get_alert_type_display()}
        
        Please check on them immediately or contact emergency services.
        """

        # 1. Send confirmation email to user
        if user.email:
            try:
                send_mail(
                    subject=f'EMERGENCY ALERT CONFIRMATION - {user.full_name}',
                    message=f"Your emergency alert has been triggered at {location_info}. Emergency contacts have been notified.",
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[user.email],
                    fail_silently=False,
                )
                logger.info(f"Confirmation email sent to user {user.email}")
            except Exception as e:
                logger.error(f"Failed to send confirmation email: {e}")
                self.retry(exc=e, countdown=10)

        # 2. Notify all emergency contacts
        for contact in contacts:
            if contact.phone_number:
                # TODO: Implement SMS sending here (Twilio or similar)
                logger.info(f"Would send SMS to {contact.name} ({contact.phone_number})")

            if contact.email:
                try:
                    send_mail(
                        subject=f'EMERGENCY ALERT - {user.full_name}',
                        message=message,
                        from_email=settings.DEFAULT_FROM_EMAIL,
                        recipient_list=[contact.email],
                        fail_silently=False,
                    )
                    logger.info(f"Alert email sent to contact {contact.email}")
                except Exception as e:
                    logger.error(f"Failed to send email to {contact.email}: {e}")

        # 3. Notify authorities if enabled
        if alert.auto_call_authorities:
            # TODO: Implement authority notification (e.g., Twilio voice call, API to local services)
            logger.info("Would notify local authorities automatically.")

        logger.info(f"Emergency notifications processed for alert {alert_id}")

    except EmergencyAlert.DoesNotExist:
        logger.error(f"Emergency alert {alert_id} not found")
    except Exception as e:
        logger.error(f"Failed to send emergency notifications: {str(e)}")
        self.retry(exc=e, countdown=30)
