# sessions.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional # Import Optional
from datetime import datetime
from database import get_db
from models import Session as SessionModel, User, EmotionDetection, FacialData, VoiceData, WellnessSuggestion, Feedback
from schemas import SessionCreate, SessionResponse, SessionWithDetections, FeedbackCreate, FeedbackResponse, EmotionDetectionWithData, FacialDataResponse, VoiceDataResponse, WellnessSuggestionResponse # Removed FeedbackCreate, FeedbackResponse as they are defined later.
from dependencies import get_current_active_user, get_current_user
from config import settings
import requests
import json
from pydantic import BaseModel
import google.generativeai as genai

router = APIRouter(prefix="/sessions", tags=["sessions"])

class ProcessEmotionRequest(BaseModel):
    emotion: str
    voice_content: str

# Enhanced emotion color mapping with more nuanced emotions
EMOTION_COLORS = {
    # Positive emotions
    "happy": "#FFD700",  # Gold
    "joyful": "#FFD700",
    "excited": "#FF8C00",  # Dark orange
    "content": "#98FB98",  # Pale green
    "grateful": "#FFA07A",  # Light salmon
    "hopeful": "#87CEFA",  # Light sky blue
    
    # Negative emotions
    "sad": "#4682B4",    # Steel blue
    "depressed": "#1E90FF",  # Dodger blue
    "lonely": "#6495ED",  # Cornflower blue
    "angry": "#DC143C",  # Crimson
    "furious": "#B22222",  # Firebrick
    "frustrated": "#CD5C5C",  # Indian red
    "fearful": "#9370DB", # Medium purple
    "anxious": "#9932CC",  # Dark orchid
    "stressed": "#FF6347",  # Tomato
    "overwhelmed": "#FF4500",  # Orange red
    
    # Neutral/other
    "surprised": "#FFA500", # Orange
    "shocked": "#FF4500",
    "disgusted": "#2E8B57", # Sea green
    "neutral": "#778899", # Light slate gray
    "tired": "#A9A9A9",   # Dark gray
    "confused": "#DAA520"   # Golden rod
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
    """Process emotion data and generate wellness suggestions using Gemini 1.5 Flash."""
    # 1. Store detection data
    detection = EmotionDetection(session_id=session_id, timestamp=datetime.utcnow()) # Added timestamp here for EmotionDetection
    db.add(detection)
    db.commit()
    db.refresh(detection)

    # Get emotion color
    emotion_lower = req.emotion.lower()
    calculated_emotion_color = EMOTION_COLORS.get(emotion_lower, "#778899")

    # 2. Store facial data
    facial = FacialData(
        detection_id=detection.id,
        emotion=req.emotion,
    )
    db.add(facial)
    db.commit()
    db.refresh(facial)

    # 3. Store voice data
    voice = VoiceData(detection_id=detection.id, content=req.voice_content)
    db.add(voice)
    db.commit()
    db.refresh(voice)

    # 4. Generate wellness suggestion with Gemini 1.5 Flash
    suggestion_text = generate_wellness_response_with_gemini(
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
    db.refresh(suggestion)

    # Parse the response for the frontend
    parts = suggestion_text.split('•')
    acknowledgment = parts[0].strip() if parts else ""
    suggestions_list = [s.strip() for s in parts[1:] if s.strip()]

    return {
        "session_id": session_id,
        "emotion": req.emotion,
        "voice_content": req.voice_content,
        "acknowledgment": acknowledgment,
        "suggestions": suggestions_list,
        "emotion_color": calculated_emotion_color
    }

def generate_wellness_response_with_gemini(emotion: str, content: str, db: Session) -> str:
    """Generate wellness response using Gemini 1.5 Flash with enhanced prompting."""
    try:
        genai.configure(api_key=settings.gemini_api_key)
        
        # Create the model instance using 'gemini-1.5-flash'
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        # Craft the prompt based on emotion type
        emotion = emotion.lower()
        prompt = build_gemini_prompt(emotion, content)
        
        # Generate the response
        response = model.generate_content(prompt)
        
        # Format the response
        return format_gemini_response(response.text, emotion)
        
    except Exception as e:
        print(f"Gemini 1.5 Flash failed: {str(e)}")
        return get_enhanced_fallback_response(emotion, content)

def build_gemini_prompt(emotion: str, content: str) -> str:
    """Build a tailored prompt for Gemini based on emotion type."""
    base_prompt = """As a compassionate mental health assistant, respond to someone feeling {emotion} who shared:
"{content}"

Provide:
1. A brief (10-15 word) empathetic acknowledgment of their emotion
2. Three (3) concise wellness suggestions (12 words max each) tailored to their situation
3. Format as: "[Acknowledgment] • Suggestion 1 • Suggestion 2 • Suggestion 3"

Make suggestions practical, specific, and emotionally appropriate."""

    # Emotion-specific prompt variations
    if emotion in ["happy", "joyful", "excited", "content"]:
        return f"""As a positivity coach, respond to someone feeling {emotion} who shared:
"{content}"

Provide:
1. A warm validation (12-15 words)
2. Three suggestions to:
    - Deepen this positive state
    - Share it with others
    - Create lasting positive memories
3. Format as: "It's wonderful you're feeling {emotion}! • Suggestion 1 • Suggestion 2 • Suggestion 3"

Keep suggestions uplifting and practical."""

    elif emotion in ["sad", "depressed", "lonely"]:
        return f"""As a compassionate listener, respond to someone feeling {emotion} who shared:
"{content}"

Provide:
1. A validating acknowledgment (12-15 words)
2. Three gentle suggestions for:
    - Immediate comfort
    - Connection with others
    - Small steps toward relief
3. Format as: "I hear this {emotion} feeling is hard • Comfort idea • Connection suggestion • Small step"

Use a warm, non-judgmental tone."""

    elif emotion in ["angry", "furious", "frustrated"]:
        return f"""As an emotional regulation coach, respond to someone feeling {emotion} who shared:
"{content}"

Provide:
1. A validating but calming acknowledgment (12-15 words)
2. Three suggestions for:
    - Safe emotional release
    - Shifting perspective
    - Constructive action
3. Format as: "{emotion.capitalize()} makes sense here • Release technique • Perspective shift • Action step"

Keep suggestions practical and non-shaming."""

    elif emotion in ["fearful", "anxious", "stressed", "overwhelmed"]:
        return f"""As a calming presence, respond to someone feeling {emotion} who shared:
"{content}"

Provide:
1. A grounding acknowledgment (12-15 words)
2. Three suggestions for:
    - Immediate calming
    - Breaking down concerns
    - Regaining control
3. Format as: "{emotion.capitalize()} can feel overwhelming • Calming technique • Perspective tip • Action step"

Make suggestions concrete and doable."""

    else:   # Default prompt
        return base_prompt.format(emotion=emotion, content=content)

def format_gemini_response(response_text: str, emotion: str) -> str:
    """Format Gemini's response for consistent output."""
    # Basic cleaning
    response_text = response_text.strip()
    
    # Ensure proper bullet formatting
    if '•' not in response_text:
        # Try to convert other bullet types
        response_text = response_text.replace('*', '•')
        response_text = response_text.replace('-', '•')
    
    # Add acknowledgment if missing
    if not response_text.startswith(('I ', 'It', 'You', 'We', 'This', 'Your')):
        acknowledgment = {
            "happy": "I'm glad you're feeling this way!",
            "sad": "I hear this sadness is difficult.",
            "angry": "Anger is a valid emotion.",
            "fearful": "Fear can feel overwhelming.",
            "surprised": "Surprise can be disorienting.",
            "disgusted": "Disgust is a strong reaction.",
            "neutral": "Your feelings matter."
        }.get(emotion, "I want to support you.")
        response_text = f"{acknowledgment} • {response_text}"
    
    return response_text

def get_enhanced_fallback_response(emotion: str, content: str) -> str:
    """Comprehensive fallback responses when Gemini fails."""
    emotion = emotion.lower()
    
    # Positive emotions
    if emotion in ["happy", "joyful"]:
        return "It's wonderful you're feeling this way! • Savor this moment • Share your joy with someone • Note what created this happiness"
    
    if emotion == "excited":
        return "Excitement is energizing! • Channel this energy productively • Share your enthusiasm • Balance excitement with rest"
    
    if emotion == "content":
        return "Contentment is precious • Appreciate this peaceful moment • Do something kind for yourself • Note what brought this satisfaction"
    
    # Difficult emotions
    if emotion in ["sad", "depressed"]:
        return "I hear this sadness feels heavy • Be gentle with yourself • Reach out to someone safe • Small comforts can help"
    
    if emotion in ["angry", "furious"]:
        return "Anger points to important needs • Pause before reacting • Physical activity can help • Consider the need beneath anger"
    
    if emotion in ["fearful", "anxious"]:
        return "Fear feels overwhelming • Ground with deep breaths • Break concerns into smaller pieces • You've survived 100% of hard days"
    
    if emotion in ["surprised", "shocked"]:
        return "Surprise can be disorienting • Give yourself time to process • Assess if this is helpful/harmful • Reach out if needed"
    
    if emotion == "disgusted":
        return "Disgust is a strong reaction • Distance yourself if possible • Practice cleansing rituals • Be kind to yourself after"
    
    if emotion == "tired":
        return "Fatigue deserves compassion • Rest without guilt • Hydrate and nourish your body • Small breaks help"
    
    if emotion == "stressed": # Corrected this from a list to a string
        return "Stress feels overwhelming • Prioritize one small task • 5-minute breaks reset focus • This difficult period will pass"
    
    # Content-specific responses
    if any(word in content.lower() for word in ["cheat", "betray", "lied"]):
        return "Betrayal cuts deep • Your pain is valid • Consider talking to a trusted friend • Avoid major decisions while raw"
    
    if any(word in content.lower() for word in ["work", "job", "boss"]):
        return "Work stress is real • Set small, manageable goals • Breathe before responding • Your worth isn't defined by productivity"
    
    if any(word in content.lower() for word in ["lonely", "alone", "isolated"]):
        return "Loneliness is painful • Reach out to one person today • Join an online community • This feeling doesn't define your worth"
    
    # Default
    return "Your feelings matter • Practice mindful breathing • Break challenges into steps • Progress isn't always linear"

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
        facial_emotion_color = ""
        facial_emotion_str = None

        if facial:
            emotion_from_facial = facial.emotion.lower()
            facial_emotion_color = EMOTION_COLORS.get(emotion_from_facial, "#778899")
            facial_emotion_str = facial.emotion
            
            facial_response = FacialDataResponse(
                id=facial.id,
                detection_id=facial.detection_id,
                emotion=facial.emotion,
            )
        
        voice_response = VoiceDataResponse.from_orm(voice) if voice else None

        history_acknowledgment = ""
        history_suggestions_list = []
        wellness_suggestion_response = None
        if wellness and wellness.suggestion:
            parts = wellness.suggestion.split('•')
            history_acknowledgment = parts[0].strip() if parts else ""
            history_suggestions_list = [s.strip() for s in parts[1:] if s.strip()]
            wellness_suggestion_response = WellnessSuggestionResponse(
                id=wellness.id,
                detection_id=wellness.detection_id,
                suggestion=wellness.suggestion,
                acknowledgment=history_acknowledgment,
                suggestions=history_suggestions_list
            )

        detection_data.append(EmotionDetectionWithData(
            id=det.id,
            session_id=det.session_id,
            timestamp=det.timestamp,
            facial_data=facial_response, # Now a single object or None
            voice_data=voice_response,   # Now a single object or None
            wellness_suggestions=wellness_suggestion_response, # Now a single object or None
            emotion_color=facial_emotion_color, # Pass the color derived from facial data here
            facial_emotion=facial_emotion_str # Pass the facial emotion itself here for easier access
        ))

    return SessionWithDetections(
        id=session.id,
        user_id=session.user_id,
        start_time=session.start_time,
        end_time=session.end_time,
        emotion_detections=detection_data
    )