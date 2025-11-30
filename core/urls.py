from rest_framework.routers import DefaultRouter
from .views import PoliceOfficerViewSet, AlertViewSet

router = DefaultRouter()
router.register(r'officers', PoliceOfficerViewSet)
router.register(r'alerts', AlertViewSet)

urlpatterns = router.urls
