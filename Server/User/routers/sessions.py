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
import google.generativeai as genai # Import the gemini library

router = APIRouter(prefix="/sessions", tags=["sessions"])


class ProcessEmotionRequest(BaseModel):
    emotion: str
    voice_content: str

# Dictionary for emotion colors (can be moved to a config or constants file if preferred)
EMOTION_COLORS = {
    "happy": "#FFFF00",  # Yellow
    "sad": "#0000FF",    # Blue
    "angry": "#FF0000",  # Red
    "fearful": "#800080", # Purple
    "surprised": "#FFA500", # Orange
    "disgusted": "#008000", # Green
    "neutral": "#A9A9A9" # DarkGray
}


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
    return db.query(SessionModel).filter(
        SessionModel.user_id == current_user.id
    ).offset(skip).limit(limit).all()


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
        raise HTTPException(status_code=404, detail="Session not found")
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
        raise HTTPException(status_code=404, detail="Session not found")
    if session.end_time:
        raise HTTPException(status_code=400, detail="Session already ended")
    session.end_time = datetime.utcnow()
    db.commit()
    return {"message": "Session ended successfully"}


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
        raise HTTPException(status_code=404, detail="Session not found")
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
    """Process emotion data and generate wellness suggestions."""
    # 1. Store detection data
    detection = EmotionDetection(session_id=session_id)
    db.add(detection)
    db.commit()
    db.refresh(detection)

    # Determine emotion color for the response
    calculated_emotion_color = EMOTION_COLORS.get(req.emotion.lower(), "#A9A9A9") # Default to dark gray

    # 2. Store facial data (emotion_color is not stored in DB here)
    facial = FacialData(
        detection_id=detection.id,
        emotion=req.emotion,
    )
    db.add(facial)
    db.commit()
    db.refresh(facial) # Refresh to get auto-generated ID if needed for other relations

    # 3. Store voice data
    voice = VoiceData(detection_id=detection.id, content=req.voice_content)
    db.add(voice)
    db.commit()
    db.refresh(voice) # Refresh to get auto-generated ID if needed

    # 4. Generate wellness suggestion
    suggestion_text = generate_wellness_response(
        emotion=req.emotion,
        content=req.voice_content,
        db=db
    )

    # 5. Store suggestion
    suggestion = WellnessSuggestion(
        detection_id=detection.id,
        suggestion=suggestion_text
    )
    db.add(suggestion)
    db.commit()
    db.refresh(suggestion) # Refresh to get auto-generated ID if needed

    # The response should be structured for Flutter list display
    # Assuming the suggestion_text is already in a bulleted format (e.g., "Intro. • Tip1 • Tip2")
    # We need to parse it into a list for the response.
    # We will split by "•" and strip whitespace.
    parts = suggestion_text.split('•')
    acknowledgment = parts[0].strip() if parts else ""
    suggestions_list = [s.strip() for s in parts[1:] if s.strip()]

    return {
        "session_id": session_id,
        "emotion": req.emotion,
        "voice_content": req.voice_content, # Include the voice content from the request
        "acknowledgment": acknowledgment,   # Acknowledgment part of the suggestion
        "suggestions": suggestions_list,     # List of individual suggestions
        "emotion_color": calculated_emotion_color
    }


def generate_wellness_response(emotion: str, content: str, db: Session) -> str:
    """Generate appropriate wellness response based on emotion and content."""
    # First try Gemini API
    if settings.gemini_api_key:
        try:
            genai.configure(api_key=settings.gemini_api_key)
            return generate_with_gemini(emotion, content)
        except Exception as e:
            print(f"Gemini failed: {str(e)}")
            if settings.openrouter_api_key:
                try:
                    return generate_with_openrouter(emotion, content)
                except Exception as e_openrouter:
                    print(f"OpenRouter failed: {str(e_openrouter)}")
    elif settings.openrouter_api_key:
        try:
            return generate_with_openrouter(emotion, content)
        except Exception as e:
            print(f"OpenRouter failed: {str(e)}")
    
    # Final fallback to our curated responses
    return get_curated_response(emotion, content)


def generate_with_gemini(emotion: str, content: str) -> str:
    """Generate response using Gemini API."""
    prompt = f"""You are a compassionate mental health assistant. The user is feeling {emotion}.
    
User's words: "{content}"

Provide:
1. A brief (10-15 word) empathetic acknowledgment of their emotion
2. Three (3) concise wellness suggestions (12 words max each) tailored to their specific situation
3. Format as: "I hear you're feeling [emotion]. • Suggestion 1 • Suggestion 2 • Suggestion 3"

Focus on practical, actionable advice suitable for their emotional state."""
    
    model = genai.GenerativeModel('gemini-1.5-flash')
    response = model.generate_content(prompt)
    return response.text


def generate_with_openrouter(emotion: str, content: str) -> str:
    """Generate response using OpenRouter API."""
    headers = {
        "Authorization": f"Bearer {settings.openrouter_api_key}",
        "Content-Type": "application/json"
    }
    
    prompt = f"""As a mental health assistant, respond to a user feeling {emotion} who said:
"{content}"

Provide:
1. A short (10-15 word) emotional validation
2. Five (5) very brief wellness tips (12-15 words max each)
3. Format as single paragraph with bullet points using '•' as the bullet character."""

    payload = {
        "model": "openai/gpt-4o",
        "messages": [
            {"role": "system", "content": "You are a compassionate wellness assistant. Be concise yet warm."},
            {"role": "user", "content": prompt}
        ],
        "max_tokens": 250 # Increased max_tokens to accommodate 5 suggestions
    }
    
    response = requests.post(
        settings.openrouter_api_url,
        headers=headers,
        json=payload,
        timeout=10
    )
    response.raise_for_status()
    return response.json()["choices"][0]["message"]["content"]


def get_curated_response(emotion: str, content: str) -> str:
    """Curated fallback responses for each emotion."""
    emotion = emotion.lower()
    base_responses = {
        "happy": "I'm glad you're feeling happy! • Savor this positive moment • Share your joy with others • Note what brought you this happiness",
        "sad": "I hear you're feeling sad. • Be gentle with yourself • Reach out to someone you trust • This feeling will pass",
        "angry": "Anger is a valid emotion. • Take deep breaths before reacting • Physical activity can help release • Consider the root cause calmly",
        "fearful": "Fear can feel overwhelming. • Focus on your breathing • Break concerns into smaller pieces • You've handled hard things before",
        "surprised": "Surprise can be unsettling. • Take a moment to process • Assess if this is positive/negative • Give yourself time to adjust",
        "disgusted": "Disgust is a strong reaction. • Distance yourself if needed • Reflect on what triggered this • Practice self-care after exposure",
        "neutral": "Neutral feelings are okay. • Check in with your body • Consider journaling your thoughts • Small pleasures can be grounding"
    }
    
    # Special cases
    if "cheat" in content.lower() or "betray" in content.lower():
        return ("I hear your pain about betrayal. • Your feelings are valid • Consider talking to a trusted friend • Avoid impulsive decisions right now")
    
    if "stress" in content.lower() or "overwhelm" in content.lower():
        return ("Stress feels heavy. • Prioritize one small thing first • 5-minute breaks help reset • You don't have to solve everything now")
    
    # Ensure curated response also uses the bullet format for consistency
    return base_responses.get(emotion, 
        "I want to support you. • Practice mindful breathing • Break challenges into steps • Remember progress isn't linear"
    )


@router.post("/{session_id}/feedback", response_model=FeedbackResponse)
def submit_feedback(
    session_id: int,
    feedback: FeedbackCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Submit feedback about a session."""
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.user_id == current_user.id
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if not session.end_time:
        raise HTTPException(status_code=400, detail="Session not ended yet")
    
    # Check for existing feedback
    existing = db.query(Feedback).filter(Feedback.session_id == session_id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Feedback already submitted")
    
    db_feedback = Feedback(
        session_id=session_id,
        comment=feedback.comment,
        rating=feedback.rating
    )
    db.add(db_feedback)
    db.commit()
    return db_feedback


@router.get("/{session_id}/history", response_model=SessionWithDetections)
def get_session_history(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get complete session history with all related data."""
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.user_id == current_user.id
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    detections = db.query(EmotionDetection).filter(
        EmotionDetection.session_id == session.id
    ).all()
    
    detection_data = []
    for det in detections:
        facial = db.query(FacialData).filter(
            FacialData.detection_id == det.id
        ).first()
        voice = db.query(VoiceData).filter(
            VoiceData.detection_id == det.id
        ).first()
        wellness = db.query(WellnessSuggestion).filter(
            WellnessSuggestion.detection_id == det.id
        ).first()
        
        facial_response = None
        if facial:
            emotion_from_facial = facial.emotion.lower()
            facial_emotion_color = EMOTION_COLORS.get(emotion_from_facial, "#A9A9A9")
            facial_response = FacialDataResponse(
                id=facial.id,
                detection_id=facial.detection_id,
                emotion=facial.emotion,
                timestamp=facial.timestamp,
                emotion_color=facial_emotion_color
            )
        
        # Prepare wellness suggestion for history display
        history_acknowledgment = ""
        history_suggestions_list = []
        if wellness and wellness.suggestion:
            parts = wellness.suggestion.split('•')
            history_acknowledgment = parts[0].strip() if parts else ""
            history_suggestions_list = [s.strip() for s in parts[1:] if s.strip()]

        detection_data.append(EmotionDetectionWithData(
            id=det.id,
            session_id=det.session_id,
            timestamp=det.timestamp,
            facial_data=[facial_response] if facial_response else [],
            voice_data=[VoiceDataResponse.from_orm(voice)] if voice else [],
            wellness_suggestions=[WellnessSuggestionResponse(
                id=wellness.id,
                detection_id=wellness.detection_id,
                timestamp=wellness.timestamp,
                suggestion=wellness.suggestion, # Keep original suggestion for DB model, if it's there
                acknowledgment=history_acknowledgment, # New field for acknowledgment
                suggestions=history_suggestions_list # New field for list of suggestions
            )] if wellness else []
        ))

    return SessionWithDetections(
        id=session.id,
        user_id=session.user_id,
        start_time=session.start_time,
        end_time=session.end_time,
        emotion_detections=detection_data
    )