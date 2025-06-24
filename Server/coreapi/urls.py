from django.urls import path
from .views import HelloServerView, RegisterUserView, VerifyOTPView, RegisterAdminView, GetAllUsersView, AdminLoginView, UserAnalyticsView

urlpatterns = [
    path('hello/', HelloServerView.as_view(), name='hello-server'),
    path('User_register/', RegisterUserView.as_view(), name='register'),
    path('Admin_register/', RegisterAdminView.as_view(), name='admin-register'),
    path('verify-otp/', VerifyOTPView.as_view(), name='verify-otp'),
    path('Get-All-User', GetAllUsersView.as_view(), name='Get-All-Users'),
    path('admin-login/', AdminLoginView.as_view(), name='admin-login'),
    path('user-analytics/', UserAnalyticsView.as_view(), name='user-analytics'),
]
