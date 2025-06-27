from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, ForeignKey, Date
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base
import enum


class UserStatus(str, enum.Enum):
    INACTIVE = "inactive"
    ACTIVE = "active"
    DEACTIVATED = "deactivated"
    SUSPENDED = "suspended"


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password = Column(Text, nullable=False)
    first_name = Column(Text, nullable=False)
    last_name = Column(Text, nullable=False)
    role = Column(Text, nullable=False)
    status = Column(String(15), default=UserStatus.INACTIVE)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    sessions = relationship("Session", back_populates="user")
    community_posts = relationship("CommunityPost", back_populates="user")
    community_comments = relationship("CommunityComment", back_populates="user")
    reminders = relationship("Reminder", back_populates="user")


class Session(Base):
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    start_time = Column(DateTime(timezone=True), server_default=func.now())
    end_time = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    user = relationship("User", back_populates="sessions")
    emotion_detections = relationship("EmotionDetection", back_populates="session")
    feedback = relationship("Feedback", back_populates="session")


class EmotionDetection(Base):
    __tablename__ = "emotion_detections"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    session = relationship("Session", back_populates="emotion_detections")
    facial_data = relationship("FacialData", back_populates="detection")
    voice_data = relationship("VoiceData", back_populates="detection")
    wellness_suggestions = relationship("WellnessSuggestion", back_populates="detection")


class FacialData(Base):
    __tablename__ = "facial_data"

    id = Column(Integer, primary_key=True, index=True)
    detection_id = Column(Integer, ForeignKey("emotion_detections.id"), nullable=False)
    emotion = Column(Text, nullable=False)

    # Relationships
    detection = relationship("EmotionDetection", back_populates="facial_data")


class VoiceData(Base):
    __tablename__ = "voice_data"

    id = Column(Integer, primary_key=True, index=True)
    detection_id = Column(Integer, ForeignKey("emotion_detections.id"), nullable=False)
    audio_path = Column(Text, nullable=False)
    content = Column(Text, nullable=False)

    # Relationships
    detection = relationship("EmotionDetection", back_populates="voice_data")


class Feedback(Base):
    __tablename__ = "feedback"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False)
    comment = Column(Text, nullable=False)
    rating = Column(Integer, nullable=False)

    # Relationships
    session = relationship("Session", back_populates="feedback")


class WellnessSuggestion(Base):
    __tablename__ = "wellness_suggestions"

    id = Column(Integer, primary_key=True, index=True)
    detection_id = Column(Integer, ForeignKey("emotion_detections.id"), nullable=False)
    suggestion = Column(Text, nullable=False)

    # Relationships
    detection = relationship("EmotionDetection", back_populates="wellness_suggestions")


class CommunityPost(Base):
    __tablename__ = "community_posts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    user = relationship("User", back_populates="community_posts")
    comments = relationship(
        "CommunityComment",
        back_populates="post",
        cascade="all, delete-orphan"
    )


class CommunityComment(Base):
    __tablename__ = "community_comments"

    id = Column(Integer, primary_key=True, index=True)
    post_id = Column(Integer, ForeignKey("community_posts.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    post = relationship("CommunityPost", back_populates="comments")
    user = relationship("User", back_populates="community_comments")


class Reminder(Base):
    __tablename__ = "reminders"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(Text, nullable=False)
    description = Column(Text, nullable=False)
    reminder_time = Column(Date, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    user = relationship("User", back_populates="reminders") 