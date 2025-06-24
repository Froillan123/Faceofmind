import random
from django.core.cache import cache
from django.core.mail import send_mail
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.conf import settings
from .models import User
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.authentication import JWTAuthentication
from django.contrib.auth.hashers import make_password, check_password
from .serializers import RegisterSerializer, VerifyOTPSerializer, UserSerializer, AdminLoginSerializer
from drf_yasg.utils import swagger_auto_schema
from rest_framework.permissions import IsAdminUser, AllowAny ,IsAuthenticated
from rest_framework.exceptions import AuthenticationFailed
import logging


logger = logging.getLogger(__name__)


class HelloServerView(APIView):
    permission_classes = [AllowAny]
    def get(self, request):
        return Response({"message": "Hello from Server!"})

class RegisterUserView(APIView):
    @swagger_auto_schema(request_body=RegisterSerializer)
    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=400)

        email = serializer.validated_data['email']
        password = serializer.validated_data['password']
        first_name = serializer.validated_data['first_name']
        last_name = serializer.validated_data['last_name']
        role = "user"  # user registration

        if User.objects.filter(email=email).exists():
            return Response({"error": "Email already exists."}, status=400)

        otp = f"{random.randint(100000, 999999)}"
        cache.set(email, otp, timeout=300)

        send_mail(
            subject="Your FaceofMind OTP Code",
            message=f"Your OTP is {otp}. It expires in 5 minutes.",
            from_email=settings.EMAIL_HOST_USER,
            recipient_list=[email],
        )

        User.objects.create(
            email=email,
            password=make_password(password),
            first_name=first_name,
            last_name=last_name,
            role=role,
            status='inactive'
        )

        return Response({"message": "User registered. OTP sent to email."}, status=201)


class GetAllUsersView(APIView):
    permission_classes = [AllowAny]
    @swagger_auto_schema(
        responses={200: UserSerializer(many=True)},
        operation_summary="Get All Users",
        operation_description="Optionally filter by status, role, or email (partial match)"
    )
    def get(self, request):
        users = User.objects.all()

        status_param = request.GET.get('status')
        role_param = request.GET.get('role')
        email_param = request.GET.get('email')

        if status_param:
            users = users.filter(status=status_param)
        if role_param:
            users = users.filter(role=role_param)
        if email_param:
            users = users.filter(email__icontains=email_param)

        serializer = UserSerializer(users, many=True)
        return Response(serializer.data, status=200)

class RegisterAdminView(APIView):
    permission_classes = [AllowAny]
    @swagger_auto_schema(request_body=RegisterSerializer)
    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=400)

        email = serializer.validated_data['email']
        password = serializer.validated_data['password']
        first_name = serializer.validated_data['first_name']
        last_name = serializer.validated_data['last_name']
        role = "admin"  # admin registration

        if User.objects.filter(email=email).exists():
            return Response({"error": "Email already exists."}, status=400)

        User.objects.create(
            email=email,
            password=make_password(password),
            first_name=first_name,
            last_name=last_name,
            role=role,
            status='active'  
        )

        return Response({"message": "Admin registered successfully."}, status=201)


class AdminLoginView(APIView):
    permission_classes = [AllowAny]

    @swagger_auto_schema(request_body=AdminLoginSerializer)
    def post(self, request):
        serializer = AdminLoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=400)

        email = serializer.validated_data['email']
        password = serializer.validated_data['password']

        # Security best practice: Use the same error message for both cases
        error_response = Response(
            {'error': 'Invalid email or password.'}, 
            status=401
        )

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            # Log the failed attempt (for security monitoring)
            logger.warning(f"Failed login attempt for non-existent email: {email}")
            return error_response

        if not check_password(password, user.password):
            # Log the failed attempt (for security monitoring)
            logger.warning(f"Failed login attempt for user: {email} - incorrect password")
            return error_response

        if user.role != 'admin':
            return Response(
                {'error': 'Access restricted to admin users only.'}, 
                status=403
            )

        refresh = RefreshToken.for_user(user)

        # Log successful login
        logger.info(f"Admin user logged in: {email}")

        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'message': 'Login successful.'
        }, status=200)

class VerifyOTPView(APIView):
    @swagger_auto_schema(request_body=VerifyOTPSerializer)
    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=400)

        email = serializer.validated_data['email']
        otp = serializer.validated_data['otp']

        cached_otp = cache.get(email)
        if not cached_otp or otp != cached_otp:
            return Response({"error": "Invalid or expired OTP."}, status=400)

        try:
            user = User.objects.get(email=email)
            user.status = 'active'
            user.save()

            refresh = RefreshToken.for_user(user)
            return Response({
                "message": "Email verified successfully.",
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            })
        except User.DoesNotExist:
            return Response({"error": "User not found."}, status=404)
