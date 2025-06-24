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

class UserAnalyticsView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        period = request.GET.get('period', 'week')  # week, month, year, custom
        group_by = request.GET.get('group_by', 'day')  # day, week, month
        start = request.GET.get('start')
        end = request.GET.get('end')

        today = now().date()
        all_users = User.objects.all()
        admin_users = all_users.filter(role='admin')
        professional_users = all_users.filter(role='professional')
        user_users = all_users.filter(role='user')

        # Date filtering for total/new user counts only
        if period == 'week':
            start_date = today - timedelta(days=today.weekday())
            end_date = start_date + timedelta(days=6)
        elif period == 'month':
            start_date = today.replace(day=1)
            end_date = today.replace(day=31)
        elif period == 'year':
            start_date = today.replace(month=1, day=1)
            end_date = today.replace(month=12, day=31)
        elif period == 'custom' and start and end:
            start_date = parse_date(start)
            end_date = parse_date(end)
        else:
            start_date = all_users.order_by('created_at').first().created_at.date() if all_users.exists() else today
            end_date = today

        # Do NOT filter all_users, admin_users, etc. for chart bins
        # Only use the filter for total/new user counts below
        all_users_period = all_users.filter(created_at__date__gte=start_date, created_at__date__lte=end_date)
        admin_users_period = admin_users.filter(created_at__date__gte=start_date, created_at__date__lte=end_date)
        professional_users_period = professional_users.filter(created_at__date__gte=start_date, created_at__date__lte=end_date)
        user_users_period = user_users.filter(created_at__date__gte=start_date, created_at__date__lte=end_date)

        # Grouping (filter bins by selected period)
        labels = []
        data_all = []
        data_admin = []
        data_professional = []
        data_user = []
        if period == 'week':
            week_days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
            counts_all = [0] * 7
            counts_admin = [0] * 7
            counts_professional = [0] * 7
            counts_user = [0] * 7
            for i in range(7):
                d = start_date + timedelta(days=i)
                if d < start_date or d > end_date:
                    continue
                idx = d.weekday()  # Monday=0
                counts_all[idx] = all_users.filter(created_at__date=d, created_at__date__gte=start_date, created_at__date__lte=end_date).count()
                counts_admin[idx] = admin_users.filter(created_at__date=d, created_at__date__gte=start_date, created_at__date__lte=end_date).count()
                counts_professional[idx] = professional_users.filter(created_at__date=d, created_at__date__gte=start_date, created_at__date__lte=end_date).count()
                counts_user[idx] = user_users.filter(created_at__date=d, created_at__date__gte=start_date, created_at__date__lte=end_date).count()
            labels = week_days
            data_all = counts_all
            data_admin = counts_admin
            data_professional = counts_professional
            data_user = counts_user
        elif period == 'month':
            week_labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4']
            counts_all = [0] * 4
            counts_admin = [0] * 4
            counts_professional = [0] * 4
            counts_user = [0] * 4
            if start_date.month == 12:
                next_month = start_date.replace(year=start_date.year+1, month=1, day=1)
            else:
                next_month = start_date.replace(month=start_date.month+1, day=1)
            last_day = (next_month - timedelta(days=1)).day
            for i in range(4):
                week_start_day = 1 + i*7
                week_end_day = min(week_start_day + 6, last_day)
                week_start = start_date.replace(day=week_start_day)
                week_end = start_date.replace(day=week_end_day)
                # Clamp to selected period
                if week_end < start_date or week_start > end_date:
                    continue
                real_start = max(week_start, start_date)
                real_end = min(week_end, end_date)
                counts_all[i] = all_users.filter(created_at__date__gte=real_start, created_at__date__lte=real_end).count()
                counts_admin[i] = admin_users.filter(created_at__date__gte=real_start, created_at__date__lte=real_end).count()
                counts_professional[i] = professional_users.filter(created_at__date__gte=real_start, created_at__date__lte=real_end).count()
                counts_user[i] = user_users.filter(created_at__date__gte=real_start, created_at__date__lte=real_end).count()
            labels = week_labels
            data_all = counts_all
            data_admin = counts_admin
            data_professional = counts_professional
            data_user = counts_user
        elif period == 'year':
            month_labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
            counts_all = [0] * 12
            counts_admin = [0] * 12
            counts_professional = [0] * 12
            counts_user = [0] * 12
            for i in range(12):
                month_start = start_date.replace(month=i+1, day=1)
                if i == 11:
                    month_end = month_start.replace(day=31)
                else:
                    next_month = month_start.replace(day=28) + timedelta(days=4)
                    month_end = (next_month.replace(day=1) - timedelta(days=1))
                # Clamp to selected period
                if month_end < start_date or month_start > end_date:
                    continue
                real_start = max(month_start, start_date)
                real_end = min(month_end, end_date)
                counts_all[i] = all_users.filter(created_at__date__gte=real_start, created_at__date__lte=real_end).count()
                counts_admin[i] = admin_users.filter(created_at__date__gte=real_start, created_at__date__lte=real_end).count()
                counts_professional[i] = professional_users.filter(created_at__date__gte=real_start, created_at__date__lte=real_end).count()
                counts_user[i] = user_users.filter(created_at__date__gte=real_start, created_at__date__lte=real_end).count()
            labels = month_labels
            data_all = counts_all
            data_admin = counts_admin
            data_professional = counts_professional
            data_user = counts_user
        else:
            # fallback to previous logic
            if group_by == 'day':
                days = (end_date - start_date).days + 1
                for i in range(days):
                    d = start_date + timedelta(days=i)
                    labels.append(d.strftime('%A'))
                    data_all.append(all_users.filter(created_at__date=d).count())
                    data_admin.append(admin_users.filter(created_at__date=d).count())
                    data_professional.append(professional_users.filter(created_at__date=d).count())
                    data_user.append(user_users.filter(created_at__date=d).count())
            elif group_by == 'week':
                week_labels = []
                week_data_all = []
                week_data_admin = []
                week_data_professional = []
                week_data_user = []
                current = start_date
                while current <= end_date:
                    week_start = current
                    week_end = min(week_start + timedelta(days=6), end_date)
                    week_labels.append(f"{week_start.strftime('%Y-%m-%d')} - {week_end.strftime('%Y-%m-%d')}")
                    week_data_all.append(all_users.filter(created_at__date__gte=week_start, created_at__date__lte=week_end).count())
                    week_data_admin.append(admin_users.filter(created_at__date__gte=week_start, created_at__date__lte=week_end).count())
                    week_data_professional.append(professional_users.filter(created_at__date__gte=week_start, created_at__date__lte=week_end).count())
                    week_data_user.append(user_users.filter(created_at__date__gte=week_start, created_at__date__lte=week_end).count())
                    current = week_end + timedelta(days=1)
                labels = week_labels
                data_all = week_data_all
                data_admin = week_data_admin
                data_professional = week_data_professional
                data_user = week_data_user
            elif group_by == 'month':
                month_labels = []
                month_data_all = []
                month_data_admin = []
                month_data_professional = []
                month_data_user = []
                current = start_date.replace(day=1)
                while current <= end_date:
                    next_month = (current.replace(day=28) + timedelta(days=4)).replace(day=1)
                    month_end = min(next_month - timedelta(days=1), end_date)
                    month_labels.append(current.strftime('%B %Y'))
                    month_data_all.append(all_users.filter(created_at__date__gte=current, created_at__date__lte=month_end).count())
                    month_data_admin.append(admin_users.filter(created_at__date__gte=current, created_at__date__lte=month_end).count())
                    month_data_professional.append(professional_users.filter(created_at__date__gte=current, created_at__date__lte=month_end).count())
                    month_data_user.append(user_users.filter(created_at__date__gte=current, created_at__date__lte=month_end).count())
                    current = next_month
                labels = month_labels
                data_all = month_data_all
                data_admin = month_data_admin
                data_professional = month_data_professional
                data_user = month_data_user

        # Role breakdown
        admin_count = admin_users_period.count()
        professional_count = professional_users_period.count()
        regular_count = user_users_period.count()
        total_users = User.objects.count()
        new_users = all_users_period.count()

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
            'group_by': group_by,
        })
