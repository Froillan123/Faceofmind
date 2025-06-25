import random
from django.core.cache import cache
from django.core.mail import send_mail
from rest_framework.views import APIView
from rest_framework.response import Response
from django.conf import settings
from coreapi.serializers import RegisterSerializer
from coreapi.models import User
from django.contrib.auth.hashers import make_password
from drf_yasg.utils import swagger_auto_schema
from rest_framework.permissions import AllowAny

class RegisterUserView(APIView):
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