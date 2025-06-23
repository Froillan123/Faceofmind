import random
from django.core.cache import cache
from django.core.mail import send_mail
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.conf import settings
from .models import User
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth.hashers import make_password
from .serializers import RegisterSerializer, VerifyOTPSerializer
from drf_yasg.utils import swagger_auto_schema



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
        role = serializer.validated_data['role']

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
