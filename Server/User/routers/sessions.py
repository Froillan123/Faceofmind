from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
from database import get_db
from models import Session as SessionModel, User, EmotionDetection, FacialData, VoiceData, WellnessSuggestion, Feedback
from schemas import SessionCreate, SessionResponse, SessionWithDetections, FeedbackCreate, FeedbackResponse, EmotionDetectionWithData, FacialDataResponse, VoiceDataResponse, WellnessSuggestionResponse
from dependencies import get_current_active_user, get_current_user
from config import settings
import requests
import json
from pydantic import BaseModel

router = APIRouter(prefix="/sessions", tags=["sessions"])


class ProcessEmotionRequest(BaseModel):
    emotion: str
    voice_content: str


@router.post("/", response_model=SessionResponse)
def create_session(
    session_data: SessionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Create a new session for the current user."""
    db_session = SessionModel(
        user_id=current_user.id,
        start_time=datetime.utcnow()
    )
    
    db.add(db_session)
    db.commit()
    db.refresh(db_session)
    
    return db_session


@router.get("/", response_model=List[SessionResponse])
def get_user_sessions(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get all sessions for the current user."""
    sessions = db.query(SessionModel).filter(
        SessionModel.user_id == current_user.id
    ).offset(skip).limit(limit).all()
    
    return sessions


@router.get("/{session_id}", response_model=SessionResponse)
def get_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get a specific session by ID."""
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.user_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    
    return session


@router.patch("/{session_id}/end")
def end_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """End a session by setting the end time."""
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.user_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    
    if session.end_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session already ended"
        )
    
    session.end_time = datetime.utcnow()
    db.commit()
    db.refresh(session)
    
    return {"message": "Session ended successfully", "session": session}


@router.delete("/{session_id}")
def delete_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Delete a session."""
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.user_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    
    db.delete(session)
    db.commit()
    
    return {"message": "Session deleted successfully"}


@router.post("/{session_id}/process_emotion")
def process_emotion(
    session_id: int,
    req: ProcessEmotionRequest,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # 1. Insert EmotionDetection
    detection = EmotionDetection(session_id=session_id)
    db.add(detection)
    db.commit()
    db.refresh(detection)

    # 2. Insert FacialData
    facial = FacialData(detection_id=detection.id, emotion=req.emotion)
    db.add(facial)
    db.commit()
    db.refresh(facial)

    # 3. Insert VoiceData
    voice = VoiceData(detection_id=detection.id, audio_path="", content=req.voice_content)
    db.add(voice)
    db.commit()
    db.refresh(voice)

    # 4. Call OpenRouter API
    url = settings.openrouter_api_url
    headers = {
        "Authorization": f"Bearer {settings.openrouter_api_key}",
        "Content-Type": "application/json"
    }
    # Compose the prompt for OpenRouter (OpenAI-compatible)
    prompt = (
        f"Given the following:\n"
        f"- Detected facial emotion: {req.emotion}\n"
        f"- User said: \"{req.voice_content}\"\n"
        "Acknowledge the user's feelings and situation in your response. "
        "Then, give a wellness suggestion that is directly related to both the emotion and the voice content. "
        "Reply with:\n"
        "1 short main topic sentence (max 15 words), and 3 short bullet points (max 12 words each). "
        "Always use 'you' to address the user directly. Be concise and specific."
    )
    payload = {
        "model": "openai/gpt-4o", # or another model available on OpenRouter
        "messages": [
            {
                "role": "system",
                "content": "You are a wellness assistant. Always keep your answers short, specific, and directly related to the user's emotion and statement."
            },
            {"role": "user", "content": prompt}
        ],
        "max_tokens": 128
    }
    try:
        response = requests.post(url, json=payload, headers=headers)
        print("OpenRouter raw response:", response.text)
        response.raise_for_status()
        data = response.json()
        print("OpenRouter API response:", data)  # <-- LOG THE RAW RESPONSE
        # Extract the assistant's reply
        suggestion_text = data["choices"][0]["message"]["content"]
    except Exception as e:
        print("Exception in OpenRouter call:", e)
        raise HTTPException(status_code=500, detail=str(e))

    # 5. Store WellnessSuggestion
    suggestion = WellnessSuggestion(
        detection_id=detection.id,
        suggestion=suggestion_text
    )
    db.add(suggestion)
    db.commit()
    db.refresh(suggestion)

    return {
        "session_id": session_id,
        "emotion_detection_id": detection.id,
        "facial_emotion": req.emotion,
        "voice_content": req.voice_content,
        "wellness_suggestion": suggestion_text
    }


@router.post("/{session_id}/feedback", response_model=FeedbackResponse)
def submit_feedback(
    session_id: int,
    feedback: FeedbackCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    # 1. Check session exists and belongs to user
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.user_id == current_user.id
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if not session.end_time:
        raise HTTPException(status_code=400, detail="Session is not ended yet")

    # 2. Check if feedback already exists (optional, to prevent duplicates)
    existing = db.query(Feedback).filter(Feedback.session_id == session_id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Feedback already submitted for this session")

    # 3. Create feedback
    db_feedback = Feedback(session_id=session_id, comment=feedback.comment, rating=feedback.rating)
    db.add(db_feedback)
    db.commit()
    db.refresh(db_feedback)
    return db_feedback


@router.get("/{session_id}/feedback", response_model=FeedbackResponse)
def get_feedback(session_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    feedback = db.query(Feedback).join(SessionModel).filter(
        Feedback.session_id == session_id,
        SessionModel.user_id == current_user.id
    ).first()
    if not feedback:
        raise HTTPException(status_code=404, detail="Feedback not found")
    return feedback


@router.get("/{session_id}/history", response_model=SessionWithDetections)
def get_session_history(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get a session with all related emotion detections, facial data, voice data, and wellness suggestions."""
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.user_id == current_user.id
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    detections = db.query(EmotionDetection).filter(EmotionDetection.session_id == session.id).all()
    detection_with_data = []
    for det in detections:
        facial_data_orm = db.query(FacialData).filter(FacialData.detection_id == det.id).all()
        voice_data_orm = db.query(VoiceData).filter(VoiceData.detection_id == det.id).all()
        wellness_suggestions_orm = db.query(WellnessSuggestion).filter(WellnessSuggestion.detection_id == det.id).all()
        facial_data = [FacialDataResponse.from_orm(fd) for fd in facial_data_orm]
        voice_data = [VoiceDataResponse.from_orm(vd) for vd in voice_data_orm]
        wellness_suggestions = [WellnessSuggestionResponse.from_orm(ws) for ws in wellness_suggestions_orm]
        detection_with_data.append(EmotionDetectionWithData(
            id=det.id,
            session_id=det.session_id,
            timestamp=det.timestamp,
            facial_data=facial_data,
            voice_data=voice_data,
            wellness_suggestions=wellness_suggestions
        ))

    return SessionWithDetections(
        id=session.id,
        user_id=session.user_id,
        start_time=session.start_time,
        end_time=session.end_time,
        emotion_detections=detection_with_data
    ) 