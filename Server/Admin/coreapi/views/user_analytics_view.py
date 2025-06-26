from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from django.utils.timezone import now
from datetime import timedelta
from dateutil.relativedelta import relativedelta
from coreapi.models import User

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