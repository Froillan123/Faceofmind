from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from coreapi.models import Feedback
from coreapi.serializers import FeedbackSerializer
from rest_framework.permissions import AllowAny

class FeedbackListView(APIView):
    permission_classes = [AllowAny]
    def get(self, request):
        feedbacks = Feedback.objects.all()
        serializer = FeedbackSerializer(feedbacks, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK) 