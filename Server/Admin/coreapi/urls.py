from django.urls import path
from .views import HelloServerView, VerifyOTPView, RegisterAdminView, GetAllUsersView, AdminLoginView, AdminLogoutView, UserAnalyticsView, UpdateUserStatusView, AllUserAnalyticsView, FeedbackListView

urlpatterns = [
    path('hello/', HelloServerView.as_view(), name='hello-server'),
    path('Admin_register/', RegisterAdminView.as_view(), name='admin-register'),
    path('verify-otp/', VerifyOTPView.as_view(), name='verify-otp'),
    path('Get-All-User', GetAllUsersView.as_view(), name='Get-All-Users'),
    path('admin-login/', AdminLoginView.as_view(), name='admin-login'),
    path('admin-logout/', AdminLogoutView.as_view(), name='admin-logout'),
    path('user-analytics/', UserAnalyticsView.as_view(), name='user-analytics'),
    path('all-user-analytics/', AllUserAnalyticsView.as_view(), name='all-user-analytics'),
    path('api/user-status/', UpdateUserStatusView.as_view(), name='user-status'),
    path('feedback-list/', FeedbackListView.as_view(), name='feedback-list'),
]
