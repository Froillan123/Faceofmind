from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from django.utils.timezone import now
from coreapi.views.user_analytics_view import UserAnalyticsView

class AllUserAnalyticsView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        today = now().date()
        periods = ['week', 'month', 'year', 'all']
        result = {}
        for period in periods:
            # Simulate a request object with period param
            req = request._request
            req.GET = req.GET.copy()
            req.GET['period'] = period
            # Use the same logic as UserAnalyticsView
            view = UserAnalyticsView()
            resp = view.get(request)
            result[period] = resp.data
        return Response(result) 