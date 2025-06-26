from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi
from coreapi.models import User

class UpdateUserStatusView(APIView):
    permission_classes = [AllowAny]
    @swagger_auto_schema(
        request_body=openapi.Schema(
            type=openapi.TYPE_OBJECT,
            required=['id', 'status'],
            properties={
                'id': openapi.Schema(type=openapi.TYPE_INTEGER, description='User ID'),
                'status': openapi.Schema(type=openapi.TYPE_STRING, description='New status (active, inactive, deactivated, suspended)'),
            },
        ),
        responses={
            200: openapi.Response('User status updated successfully.'),
            400: openapi.Response('Invalid user id or status.'),
            404: openapi.Response('User not found.'),
        },
        operation_summary="Update User Status",
        operation_description="Update a user's status by user ID."
    )
    def patch(self, request):
        user_id = request.data.get('id')
        new_status = request.data.get('status')
        valid_statuses = ['inactive', 'active', 'deactivated', 'suspended']
        if not user_id or new_status not in valid_statuses:
            return Response({'error': 'Invalid user id or status.'}, status=400)
        try:
            user = User.objects.get(id=user_id)
            user.status = new_status
            user.save()
            return Response({'message': 'User status updated successfully.'}, status=200)
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=404) 