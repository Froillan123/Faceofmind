from django.urls import path
from .views import RegisterUserView, VerifyOTPView  # Removed TestView

urlpatterns = [
    path('register/', RegisterUserView.as_view(), name='register'),
    path('verify-otp/', VerifyOTPView.as_view(), name='verify-otp'),
]
