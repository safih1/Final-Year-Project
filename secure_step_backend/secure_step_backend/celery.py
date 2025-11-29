import os
from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "secure_step_backend.settings")

app = Celery("secure_step_backend")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
    