from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime, date
from models import UserStatus


# User schemas
class UserBase(BaseModel):
    email: EmailStr
    first_name: str
    last_name: str


class UserCreate(UserBase):
    password: str


class UserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    role: Optional[str] = None
    status: Optional[UserStatus] = None


class UserResponse(UserBase):
    id: int
    role: str
    status: UserStatus
    created_at: datetime

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"

    class Config:
        orm_mode = True


# Session schemas
class SessionBase(BaseModel):
    pass


class SessionCreate(SessionBase):
    pass


class SessionResponse(SessionBase):
    id: int
    user_id: int
    start_time: datetime
    end_time: Optional[datetime] = None

    class Config:
        orm_mode = True


# Emotion Detection schemas
class EmotionDetectionBase(BaseModel):
    pass


class EmotionDetectionCreate(EmotionDetectionBase):
    pass


class EmotionDetectionResponse(EmotionDetectionBase):
    id: int
    session_id: int
    timestamp: datetime

    class Config:
        orm_mode = True


# Facial Data schemas
class FacialDataBase(BaseModel):
    emotion: str


class FacialDataCreate(FacialDataBase):
    pass


class FacialDataResponse(FacialDataBase):
    id: int
    detection_id: int

    class Config:
        orm_mode = True


# Voice Data schemas
class VoiceDataBase(BaseModel):
    audio_path: str
    content: str


class VoiceDataCreate(VoiceDataBase):
    pass


class VoiceDataResponse(VoiceDataBase):
    id: int
    detection_id: int

    class Config:
        orm_mode = True


# Feedback schemas
class FeedbackBase(BaseModel):
    comment: str
    rating: int


class FeedbackCreate(FeedbackBase):
    pass


class FeedbackResponse(FeedbackBase):
    id: int
    session_id: int

    class Config:
        orm_mode = True


# Wellness Suggestion schemas
class WellnessSuggestionBase(BaseModel):
    suggestion: str


class WellnessSuggestionCreate(WellnessSuggestionBase):
    pass


class WellnessSuggestionResponse(WellnessSuggestionBase):
    id: int
    detection_id: int

    class Config:
        orm_mode = True


# Community Post schemas
class CommunityPostBase(BaseModel):
    content: str


class CommunityPostCreate(CommunityPostBase):
    pass


class CommunityPostUpdate(BaseModel):
    content: str


class CommunityPostResponse(CommunityPostBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True


# Community Comment schemas
class CommunityCommentBase(BaseModel):
    content: str


class CommunityCommentCreate(CommunityCommentBase):
    pass


class CommunityCommentUpdate(BaseModel):
    content: str


class CommunityCommentResponse(CommunityCommentBase):
    id: int
    post_id: int
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True


# Reminder schemas
class ReminderBase(BaseModel):
    title: str
    description: str
    reminder_time: date
    is_active: bool = True


class ReminderCreate(ReminderBase):
    pass


class ReminderUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    reminder_time: Optional[date] = None
    is_active: Optional[bool] = None


class ReminderResponse(ReminderBase):
    id: int
    user_id: int
    created_at: datetime

    class Config:
        orm_mode = True


# Authentication schemas
class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class RefreshTokenRequest(BaseModel):
    refresh_token: str


# Response schemas with relationships
class UserWithSessions(UserResponse):
    sessions: List[SessionResponse] = []


class SessionWithDetections(SessionResponse):
    emotion_detections: List[EmotionDetectionResponse] = []


class EmotionDetectionWithData(EmotionDetectionResponse):
    facial_data: List[FacialDataResponse] = []
    voice_data: List[VoiceDataResponse] = []
    wellness_suggestions: List[WellnessSuggestionResponse] = []

class FeedbackCreate(BaseModel):
    comment: str
    rating: int  # 1-5

class FeedbackResponse(BaseModel):
    id: int
    session_id: int
    comment: str
    rating: int

    class Config:
        orm_mode = True 