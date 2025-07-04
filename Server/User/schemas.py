# schemas.py
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


class UserProfileUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None


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


class RegisterResponse(BaseModel):
    message: str
    user: UserResponse

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
    timestamp: datetime # This remains as EmotionDetection has a timestamp

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
    # Removed timestamp: datetime
    # Removed emotion_color: str -- this is a derived value, not a stored one
    class Config:
        orm_mode = True


# Voice Data schemas
class VoiceDataBase(BaseModel):
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
    comment: str 
    rating: int 

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
    # Removed timestamp: datetime
    # Added for frontend display derived from the suggestion string
    acknowledgment: str = ""
    suggestions: List[str] = []
    url: List[str] = []

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
    comment_count: int  # Added field for number of comments

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
    # Add user info fields for login response
    id: Optional[int] = None
    email: Optional[EmailStr] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    role: Optional[str] = None
    status: Optional[UserStatus] = None
    created_at: Optional[datetime] = None


class RefreshTokenRequest(BaseModel):
    refresh_token: str


# Response schemas with relationships
class UserWithSessions(UserResponse):
    sessions: List[SessionResponse] = []


class EmotionDetectionWithData(EmotionDetectionResponse):
    facial_data: Optional[FacialDataResponse] = None # Change to Optional singular
    voice_data: Optional[VoiceDataResponse] = None # Change to Optional singular
    wellness_suggestions: Optional[WellnessSuggestionResponse] = None # Change to Optional singular
    # Add fields for direct display related to the detection
    emotion_color: str = ""
    facial_emotion: Optional[str] = None # To display the facial emotion easily

class SessionWithDetections(SessionResponse):
    emotion_detections: List[EmotionDetectionWithData] = []

# Your FeedbackCreate and FeedbackResponse were duplicated and inconsistent.
# I've kept the one that matches your router's usage.
# If Feedback is not directly linked to EmotionDetection, then your existing schema for it is fine.
# I am assuming Feedback is for the entire session, not a specific detection within it.

class SessionOverview(BaseModel):
    id: int
    user_id: int
    start_time: datetime
    end_time: Optional[datetime]
    dominant_emotion: Optional[str]
    suggestion: Optional[str]

    class Config:
        orm_mode = True

class PasswordResetRequest(BaseModel):
    email: EmailStr

class PasswordResetConfirm(BaseModel):
    email: EmailStr
    otp: str
    new_password: str