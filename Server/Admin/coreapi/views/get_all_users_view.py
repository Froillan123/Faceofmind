from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi
from coreapi.models import User
from coreapi.serializers import UserSerializer
from coreapi.utils import get_active_users_from_redis, is_user_active_in_redis
from django.db.models import Q

class GetAllUsersView(APIView):
    permission_classes = [AllowAny]
    @swagger_auto_schema(
        manual_parameters=[
            openapi.Parameter('status', openapi.IN_QUERY, description="Filter by status", type=openapi.TYPE_STRING),
            openapi.Parameter('role', openapi.IN_QUERY, description="Filter by role", type=openapi.TYPE_STRING),
            openapi.Parameter('query', openapi.IN_QUERY, description="Search by name or email (partial match)", type=openapi.TYPE_STRING),
            openapi.Parameter('page', openapi.IN_QUERY, description="Page number", type=openapi.TYPE_INTEGER),
            openapi.Parameter('page_size', openapi.IN_QUERY, description="Page size", type=openapi.TYPE_INTEGER),
        ],
        responses={200: UserSerializer(many=True)},
        operation_summary="Get All Users",
        operation_description="Optionally filter by status, role, or email (partial match). Supports pagination with 'page' and 'page_size'. Includes active user information from Redis."
    )
    def get(self, request):
        users = User.objects.all()

        status_param = request.GET.get('status')
        role_param = request.GET.get('role')
        query_param = request.GET.get('query')
        page = int(request.GET.get('page', 1))
        page_size = int(request.GET.get('page_size', 15))

        if status_param:
            users = users.filter(status=status_param)
        if role_param:
            users = users.filter(role=role_param)
        if query_param:
            users = users.filter(
                Q(first_name__icontains=query_param) |
                Q(last_name__icontains=query_param) |
                Q(email__icontains=query_param)
            )

        total_count = users.count()
        start = (page - 1) * page_size
        end = start + page_size
        users_page = users.order_by('-created_at')[start:end]

        # Get active users from Redis
        active_user_ids = get_active_users_from_redis()
        
        # Serialize users and add active status
        serializer = UserSerializer(users_page, many=True)
        user_data = serializer.data
        
        # Add active status to each user
        for user in user_data:
            user['is_active_in_redis'] = user['id'] in active_user_ids
        
        return Response({
            'results': user_data,
            'total': total_count,
            'page': page,
            'page_size': page_size,
            'active_users_count': len(active_user_ids)
        }, status=200) 