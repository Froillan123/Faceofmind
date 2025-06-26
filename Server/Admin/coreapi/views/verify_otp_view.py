from rest_framework.views import APIView
from rest_framework.response import Response
from django.core.cache import cache
from coreapi.serializers import VerifyOTPSerializer
from coreapi.models import User
from rest_framework_simplejwt.tokens import RefreshToken
from drf_yasg.utils import swagger_auto_schema
from rest_framework.permissions import AllowAny

class VerifyOTPView(APIView):
    permission_classes = [AllowAny]
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