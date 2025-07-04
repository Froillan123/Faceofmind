from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from django.utils.timezone import now
from datetime import timedelta
from dateutil.relativedelta import relativedelta
from coreapi.models import User
from django.core.cache import cache
from django.db.models import Count, Q
import json

class UserAnalyticsView(APIView):
    permission_classes = [AllowAny]
    
    def get(self, request):
        period = request.GET.get('period', 'week')  # week, month, year, all
        today = now().date()
        
        # Cache key for this specific request
        cache_key = f"analytics_{period}_{today}"
        cached_data = cache.get(cache_key)
        
        if cached_data:
            return Response(cached_data)
        
        # Optimized database queries with select_related and prefetch_related
        all_users = User.objects.all()
        admin_users = all_users.filter(role='admin')
        professional_users = all_users.filter(role='professional')
        user_users = all_users.filter(role='user')

        if period == 'all':
            # Use aggregation for better performance
            counts = all_users.aggregate(
                total=Count('id'),
                admin_count=Count('id', filter=Q(role='admin')),
                professional_count=Count('id', filter=Q(role='professional')),
                regular_count=Count('id', filter=Q(role='user'))
            )
            
            result = {
                'total_users': counts['total'],
                'admin_count': counts['admin_count'],
                'professional_count': counts['professional_count'],
                'regular_count': counts['regular_count'],
                'period': 'all'
            }
            
            # Cache for 5 minutes
            cache.set(cache_key, result, 300)
            return Response(result)

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
                # Use optimized queries with date filtering
                day_users = all_users.filter(created_at__date=day)
                data_all.append(day_users.count())
                data_admin.append(day_users.filter(role='admin').count())
                data_professional.append(day_users.filter(role='professional').count())
                data_user.append(day_users.filter(role='user').count())

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
                
                # Optimized week queries
                week_users = all_users.filter(
                    created_at__date__gte=current_date,
                    created_at__date__lte=week_end
                )
                
                data_all[week_num] = week_users.count()
                data_admin[week_num] = week_users.filter(role='admin').count()
                data_professional[week_num] = week_users.filter(role='professional').count()
                data_user[week_num] = week_users.filter(role='user').count()
                
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
                
                # Optimized month queries
                month_users = all_users.filter(
                    created_at__date__gte=month_start,
                    created_at__date__lte=month_end
                )
                
                data_all[month] = month_users.count()
                data_admin[month] = month_users.filter(role='admin').count()
                data_professional[month] = month_users.filter(role='professional').count()
                data_user[month] = month_users.filter(role='user').count()

        # Role breakdown for the period
        admin_count = admin_users.filter(created_at__date__lte=end_date).count()
        professional_count = professional_users.filter(created_at__date__lte=end_date).count()
        regular_count = user_users.filter(created_at__date__lte=end_date).count()
        total_users = all_users.filter(created_at__date__lte=end_date).count()
        new_users = all_users.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).count()

        result = {
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
        }
        
        # Cache for 5 minutes
        cache.set(cache_key, result, 300)
        return Response(result) 