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
from django.db.models import Count, Q
from django.utils.timezone import now
from datetime import timedelta
from django.utils.dateparse import parse_date
from dateutil.relativedelta import relativedelta  # Add this import
from rest_framework.pagination import PageNumberPagination
from drf_yasg import openapi


logger = logging.getLogger(__name__)


class HelloServerView(APIView):
    permission_classes = [AllowAny]
    def get(self, request):
        return Response({"message": "Hello from Server!"})

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


class GetAllUsersView(APIView):
    permission_classes = [AllowAny]
    @swagger_auto_schema(
        manual_parameters=[
            openapi.Parameter('status', openapi.IN_QUERY, description="Filter by status", type=openapi.TYPE_STRING),
            openapi.Parameter('role', openapi.IN_QUERY, description="Filter by role", type=openapi.TYPE_STRING),
            openapi.Parameter('email', openapi.IN_QUERY, description="Filter by email (partial match)", type=openapi.TYPE_STRING),
            openapi.Parameter('page', openapi.IN_QUERY, description="Page number", type=openapi.TYPE_INTEGER),
            openapi.Parameter('page_size', openapi.IN_QUERY, description="Page size", type=openapi.TYPE_INTEGER),
        ],
        responses={200: UserSerializer(many=True)},
        operation_summary="Get All Users",
        operation_description="Optionally filter by status, role, or email (partial match). Supports pagination with 'page' and 'page_size'."
    )
    def get(self, request):
        users = User.objects.all()

        status_param = request.GET.get('status')
        role_param = request.GET.get('role')
        email_param = request.GET.get('email')
        page = int(request.GET.get('page', 1))
        page_size = int(request.GET.get('page_size', 15))

        if status_param:
            users = users.filter(status=status_param)
        if role_param:
            users = users.filter(role=role_param)
        if email_param:
            users = users.filter(email__icontains=email_param)

        total_count = users.count()
        start = (page - 1) * page_size
        end = start + page_size
        users_page = users.order_by('-created_at')[start:end]

        serializer = UserSerializer(users_page, many=True)
        return Response({
            'results': serializer.data,
            'total': total_count,
            'page': page,
            'page_size': page_size
        }, status=200)

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

class UserAnalyticsView(APIView):
    permission_classes = [AllowAny]
    
    def get(self, request):
        period = request.GET.get('period', 'week')  # week, month, year, all
        today = now().date()
        
        # Base querysets
        all_users = User.objects.all()
        admin_users = all_users.filter(role='admin')
        professional_users = all_users.filter(role='professional')
        user_users = all_users.filter(role='user')

        if period == 'all':
            return Response({
                'total_users': all_users.count(),
                'admin_count': admin_users.count(),
                'professional_count': professional_users.count(),
                'regular_count': user_users.count(),
                'period': 'all'
            })

        # Date ranges
        if period == 'week':
            start_date = today - timedelta(days=today.weekday())
            end_date = start_date + timedelta(days=6)
            labels = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
            
            data_all = []
            data_admin = []
            data_professional = []
            data_user = []
            
            for i in range(7):
                day = start_date + timedelta(days=i)
                data_all.append(all_users.filter(created_at__date=day).count())
                data_admin.append(admin_users.filter(created_at__date=day).count())
                data_professional.append(professional_users.filter(created_at__date=day).count())
                data_user.append(user_users.filter(created_at__date=day).count())

        elif period == 'month':
            start_date = today.replace(day=1)
            end_date = (start_date + relativedelta(months=1)) - timedelta(days=1)
            labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4']
            
            data_all = [0] * 4
            data_admin = [0] * 4
            data_professional = [0] * 4
            data_user = [0] * 4
            
            current_date = start_date
            week_num = 0
            
            while current_date <= end_date and week_num < 4:
                week_end = min(current_date + timedelta(days=6), end_date)
                
                data_all[week_num] = all_users.filter(
                    created_at__date__gte=current_date,
                    created_at__date__lte=week_end
                ).count()
                
                data_admin[week_num] = admin_users.filter(
                    created_at__date__gte=current_date,
                    created_at__date__lte=week_end
                ).count()
                
                data_professional[week_num] = professional_users.filter(
                    created_at__date__gte=current_date,
                    created_at__date__lte=week_end
                ).count()
                
                data_user[week_num] = user_users.filter(
                    created_at__date__gte=current_date,
                    created_at__date__lte=week_end
                ).count()
                
                current_date = week_end + timedelta(days=1)
                week_num += 1

        elif period == 'year':
            start_date = today.replace(month=1, day=1)
            end_date = today.replace(month=12, day=31)
            labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
            
            data_all = [0] * 12
            data_admin = [0] * 12
            data_professional = [0] * 12
            data_user = [0] * 12
            
            for month in range(12):
                month_start = start_date.replace(month=month+1, day=1)
                month_end = (month_start + relativedelta(months=1)) - timedelta(days=1)
                
                data_all[month] = all_users.filter(
                    created_at__date__gte=month_start,
                    created_at__date__lte=month_end
                ).count()
                
                data_admin[month] = admin_users.filter(
                    created_at__date__gte=month_start,
                    created_at__date__lte=month_end
                ).count()
                
                data_professional[month] = professional_users.filter(
                    created_at__date__gte=month_start,
                    created_at__date__lte=month_end
                ).count()
                
                data_user[month] = user_users.filter(
                    created_at__date__gte=month_start,
                    created_at__date__lte=month_end
                ).count()

        # Role breakdown for the period
        admin_count = admin_users.filter(created_at__date__lte=end_date).count()
        professional_count = professional_users.filter(created_at__date__lte=end_date).count()
        regular_count = user_users.filter(created_at__date__lte=end_date).count()
        total_users = all_users.filter(created_at__date__lte=end_date).count()
        new_users = all_users.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).count()

        return Response({
            'labels': labels,
            'data_all': data_all,
            'data_admin': data_admin,
            'data_professional': data_professional,
            'data_user': data_user,
            'total_users': total_users,
            'new_users': new_users,
            'admin_count': admin_count,
            'professional_count': professional_count,
            'regular_count': regular_count,
            'start_date': str(start_date),
            'end_date': str(end_date),
            'period': period,
        })

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