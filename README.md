Police Response System - Django Backend (Minimal)

How to run:

1. Create a virtual environment:
   python -m venv venv
   source venv/bin/activate   # or venv\Scripts\activate on Windows

2. Install requirements:
   pip install -r requirements.txt

3. Make migrations and migrate:
   python manage.py makemigrations
   python manage.py migrate

4. Create a superuser (optional, for admin):
   python manage.py createsuperuser

5. Run the server:
   python manage.py runserver

API endpoints (base: http://127.0.0.1:8000/api/):
 - /api/officers/      (GET, POST, PUT, DELETE)
 - /api/alerts/        (GET, POST, PUT, DELETE)
 - /api/alerts/{id}/accept/  (POST)  - body: { officer_id, lat, lng, eta }

Frontend flow:
 - Frontend creates alerts via POST /api/alerts/
 - Officers list alerts via GET /api/alerts/
 - When officer accepts, frontend obtains geolocation and posts to accept endpoint.

This is a minimal scaffold. Add authentication, CORS, and production settings as needed.
