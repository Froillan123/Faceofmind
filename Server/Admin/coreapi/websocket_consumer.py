import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.core.cache import cache
from coreapi.models import User
from django.utils.timezone import now
from datetime import timedelta
from dateutil.relativedelta import relativedelta

class AnalyticsConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        # Accept the connection
        await self.accept()
        
        # Add to analytics group
        await self.channel_layer.group_add("analytics", self.channel_name)
        
        # Send initial data
        await self.send_initial_analytics()
    
    async def disconnect(self, close_code):
        # Remove from analytics group
        await self.channel_layer.group_discard("analytics", self.channel_name)
    
    async def receive(self, text_data):
        """Handle incoming messages from client"""
        try:
            data = json.loads(text_data)
            message_type = data.get('type')
            
            if message_type == 'request_analytics':
                period = data.get('period', 'week')
                await self.send_analytics_update(period)
            elif message_type == 'ping':
                await self.send(text_data=json.dumps({'type': 'pong'}))
                
        except json.JSONDecodeError:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': 'Invalid JSON format'
            }))
    
    async def send_initial_analytics(self):
        """Send initial analytics data on connection"""
        analytics_data = await self.get_analytics_data('week')
        await self.send(text_data=json.dumps({
            'type': 'analytics_update',
            'data': analytics_data
        }))
    
    async def send_analytics_update(self, period):
        """Send analytics update for specific period"""
        analytics_data = await self.get_analytics_data(period)
        await self.send(text_data=json.dumps({
            'type': 'analytics_update',
            'period': period,
            'data': analytics_data
        }))
    
    @database_sync_to_async
    def get_analytics_data(self, period):
        """Get analytics data from database"""
        today = now().date()
        
        # Check cache first
        cache_key = f"analytics_{period}_{today}"
        cached_data = cache.get(cache_key)
        
        if cached_data:
            return cached_data
        
        # Get data from database
        all_users = User.objects.all()
        
        if period == 'all':
            from django.db.models import Count, Q
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
        else:
            # Get time-based analytics
            result = self._get_time_based_analytics(all_users, period, today)
        
        # Cache the result
        cache.set(cache_key, result, 300)
        return result
    
    def _get_time_based_analytics(self, all_users, period, today):
        """Get time-based analytics data"""
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
                month_users = all_users.filter(
                    created_at__date__gte=month_start,
                    created_at__date__lte=month_end
                )
                
                data_all[month] = month_users.count()
                data_admin[month] = month_users.filter(role='admin').count()
                data_professional[month] = month_users.filter(role='professional').count()
                data_user[month] = month_users.filter(role='user').count()
        
        # Calculate totals
        admin_users = all_users.filter(role='admin')
        professional_users = all_users.filter(role='professional')
        user_users = all_users.filter(role='user')
        
        admin_count = admin_users.filter(created_at__date__lte=end_date).count()
        professional_count = professional_users.filter(created_at__date__lte=end_date).count()
        regular_count = user_users.filter(created_at__date__lte=end_date).count()
        total_users = all_users.filter(created_at__date__lte=end_date).count()
        new_users = all_users.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).count()
        
        return {
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
    
    async def analytics_notification(self, event):
        """Handle analytics notifications from other parts of the system"""
        await self.send(text_data=json.dumps({
            'type': 'analytics_notification',
            'message': event['message'],
            'data': event.get('data', {})
        })) 