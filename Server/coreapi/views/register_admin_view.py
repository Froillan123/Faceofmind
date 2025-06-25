from rest_framework.views import APIView
from rest_framework.response import Response
from django.contrib.auth.hashers import make_password
from coreapi.serializers import RegisterSerializer
from coreapi.models import User
from drf_yasg.utils import swagger_auto_schema
from rest_framework.permissions import AllowAny

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