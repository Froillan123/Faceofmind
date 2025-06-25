import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from coreapi.serializers import AdminLoginSerializer
from coreapi.models import User
from django.contrib.auth.hashers import check_password
from rest_framework_simplejwt.tokens import RefreshToken
from drf_yasg.utils import swagger_auto_schema
from rest_framework.permissions import AllowAny

logger = logging.getLogger(__name__)

class AdminLoginView(APIView):
    permission_classes = [AllowAny]

    @swagger_auto_schema(request_body=AdminLoginSerializer)
    def post(self, request):
        serializer = AdminLoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=400)

        email = serializer.validated_data['email']
        password = serializer.validated_data['password']

        error_response = Response(
            {'error': 'Invalid email or password.'}, 
            status=401
        )

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            logger.warning(f"Failed login attempt for non-existent email: {email}")
            return error_response

        if not check_password(password, user.password):
            logger.warning(f"Failed login attempt for user: {email} - incorrect password")
            return error_response

        if user.role != 'admin':
            return Response(
                {'error': 'Access restricted to admin users only.'}, 
                status=403
            )

        refresh = RefreshToken.for_user(user)

        logger.info(f"Admin user logged in: {email}")

        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'message': 'Login successful.'
        }, status=200) 