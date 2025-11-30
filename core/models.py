from django.db import models

class PoliceOfficer(models.Model):
    name = models.CharField(max_length=100)
    badge_id = models.CharField(max_length=50, unique=True)
    current_lat = models.FloatField(null=True, blank=True)
    current_lng = models.FloatField(null=True, blank=True)
    eta = models.CharField(max_length=50, null=True, blank=True)

    def __str__(self):
        return f"{self.name} ({self.badge_id})"

class Alert(models.Model):
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    accepted_by = models.ForeignKey(
        PoliceOfficer, null=True, blank=True, on_delete=models.SET_NULL
    )
    officer_lat = models.FloatField(null=True, blank=True)
    officer_lng = models.FloatField(null=True, blank=True)
    eta = models.CharField(max_length=50, null=True, blank=True)

    def __str__(self):
        return f"Alert #{self.id} - {self.message[:20]}"
