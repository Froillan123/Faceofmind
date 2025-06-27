import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from coreapi.serializers import AdminLoginSerializer
from coreapi.models import User
from django.contrib.auth.hashers import check_password
from rest_framework_simplejwt.tokens import RefreshToken
from drf_yasg.utils import swagger_auto_schema
from rest_framework.permissions import AllowAny, IsAuthenticated
from coreapi.utils import get_redis
from rest_framework_simplejwt.authentication import JWTAuthentication

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
        access_token = str(refresh.access_token)

        # Store JWT in Redis
        key = f"jwt:admin:{user.id}:{access_token}"
        redis_client = get_redis()
        redis_client.set(key, 1, ex=1800)
        print("SET JWT KEY:", key)

        logger.info(f"Admin user logged in: {email}")

        return Response({
            'access': access_token,
            'refresh': str(refresh),
            'message': 'Login successful.'
        }, status=200)

class AdminLogoutView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def post(self, request):
        user = request.user
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')
        if not auth_header.startswith('Bearer '):
            return Response({'error': 'No token provided.'}, status=400)
        token = auth_header.split(' ')[1]
        redis_client = get_redis()
        key = f"jwt:admin:{user.id}:{token}"
        redis_client.delete(key)
        print("DELETE JWT KEY:", key)
        return Response({'message': 'Successfully logged out.'}, status=200) 