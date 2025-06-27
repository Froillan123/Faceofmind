from django.db import models
from django.utils import timezone

class User(models.Model):
    class Status(models.TextChoices):
        INACTIVE = 'inactive'
        ACTIVE = 'active'
        DEACTIVATED = 'deactivated'
        SUSPENDED = 'suspended'

    email = models.EmailField(unique=True)
    password = models.TextField()
    first_name = models.TextField()
    last_name = models.TextField()
    role = models.TextField()
    status = models.CharField(max_length=15, choices=Status.choices, default=Status.INACTIVE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "users"

    @classmethod
    def valid_statuses(cls):
        return ['inactive', 'active', 'deactivated', 'suspended']

class Session(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    start_time = models.DateTimeField(auto_now_add=True)
    end_time = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "sessions"

class EmotionDetection(models.Model):
    session = models.ForeignKey(Session, on_delete=models.CASCADE)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "emotion_detections"

class FacialData(models.Model):
    detection = models.ForeignKey(EmotionDetection, on_delete=models.CASCADE)
    emotion = models.TextField()

    class Meta:
        db_table = "facial_data"

class VoiceData(models.Model):
    detection = models.ForeignKey(EmotionDetection, on_delete=models.CASCADE)
    content = models.TextField()

    class Meta:
        db_table = "voice_data"

class Feedback(models.Model):
    session = models.ForeignKey(Session, on_delete=models.CASCADE)
    comment = models.TextField()
    rating = models.IntegerField()

    class Meta:
        db_table = "feedback"

class WellnessSuggestion(models.Model):
    detection = models.ForeignKey(EmotionDetection, on_delete=models.CASCADE)
    suggestion = models.TextField()

    class Meta:
        db_table = "wellness_suggestions"

class CommunityPost(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "community_posts"

class CommunityComment(models.Model):
    post = models.ForeignKey(CommunityPost, on_delete=models.CASCADE)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "community_comments"

class Reminder(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    title = models.TextField()
    description = models.TextField()
    reminder_time = models.DateField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "reminders"
