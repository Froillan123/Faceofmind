# sessions.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional # Import Optional
from datetime import datetime, timedelta
from database import get_db
from models import Session as SessionModel, User, EmotionDetection, FacialData, VoiceData, WellnessSuggestion, Feedback
from schemas import SessionCreate, SessionResponse, SessionWithDetections, FeedbackCreate, FeedbackResponse, EmotionDetectionWithData, FacialDataResponse, VoiceDataResponse, WellnessSuggestionResponse, SessionOverview # Removed FeedbackCreate, FeedbackResponse as they are defined later.
from dependencies import get_current_active_user, get_current_user
from config import settings
import requests
import json
from pydantic import BaseModel
import google.generativeai as genai
from random import uniform
from collections import defaultdict, Counter
from zoneinfo import ZoneInfo  # Add this import

router = APIRouter(prefix="/sessions", tags=["sessions"])

class ProcessEmotionRequest(BaseModel):
    emotion: str
    voice_content: str

class DiagnosisRequest(BaseModel):
    window: str  # 'day', '3days', 'week', 'month'

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

SUICIDAL_KEYWORDS = [
    "die", "suicide", "kill myself", "end my life", "self-harm", "hurt myself", "give up", "worthless", "no way out"
]

def contains_suicidal_keywords(text: str) -> bool:
    text_lower = text.lower()
    return any(kw in text_lower for kw in SUICIDAL_KEYWORDS)

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

def summarize_suggestion(suggestion: str) -> str:
    if not suggestion:
        return None
    # Try to get the first sentence
    for sep in [".", "!", "?"]:
        if sep in suggestion:
            first_sentence = suggestion.split(sep)[0].strip()
            if first_sentence:
                return first_sentence
    # If no sentence-ending punctuation, return first 6 words
    words = suggestion.split()
    return " ".join(words[:6]) + ("..." if len(words) > 6 else "")

@router.get("/", response_model=List[SessionOverview])
def get_user_sessions(
    skip: int = 0,
    limit: int = 5,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get all sessions for the current user, with dominant emotion and brief suggestion."""
    sessions = db.query(SessionModel).filter(
        SessionModel.user_id == current_user.id
    ).order_by(SessionModel.start_time.desc()).offset(skip).limit(limit).all()

    print(f"[DEBUG] User: {current_user.email} (id={current_user.id}), Sessions found: {len(sessions)}")

    result = []
    for session in sessions:
        # Get all detections for this session
        detections = db.query(EmotionDetection).filter(
            EmotionDetection.session_id == session.id
        ).all()
        # Find dominant emotion
        emotions = []
        for det in detections:
            facial = db.query(FacialData).filter(FacialData.detection_id == det.id).first()
            if facial:
                emotions.append(facial.emotion.lower())
        dominant_emotion = None
        if emotions:
            dominant_emotion = Counter(emotions).most_common(1)[0][0]
        # Get the first wellness suggestion (summarized)
        suggestion = None
        for det in detections:
            wellness = db.query(WellnessSuggestion).filter(WellnessSuggestion.detection_id == det.id).first()
            if wellness and wellness.suggestion:
                raw_suggestion = wellness.suggestion.split('•')[0].strip()
                suggestion = summarize_suggestion(raw_suggestion)
                break
        result.append(SessionOverview(
            id=session.id,
            user_id=session.user_id,
            start_time=session.start_time,
            end_time=session.end_time,
            dominant_emotion=dominant_emotion,
            suggestion=suggestion
        ))
    return result

def call_openrouter_gpt4o(prompt: str) -> str:
    """Call OpenRouter's GPT-4o as a fallback."""
    api_url = settings.openrouter_api_url or "https://openrouter.ai/api/v1/chat"
    api_key = settings.openrouter_api_key
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    data = {
        "model": "openai/gpt-4o",
        "messages": [
            {"role": "system", "content": "You are a compassionate mental health assistant."},
            {"role": "user", "content": prompt}
        ]
    }
    try:
        resp = requests.post(api_url, headers=headers, data=json.dumps(data), timeout=30)
        resp.raise_for_status()
        result = resp.json()
        # OpenRouter returns choices[0].message.content
        return result["choices"][0]["message"]["content"].strip()
    except Exception as e:
        return "AI awareness unavailable (OpenRouter fallback failed). Please try again later."

@router.post("/diagnosis")
def get_diagnosis(
    req: DiagnosisRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Aggregate user's emotion detections, classify intensity, and get diagnosis from Gemini."""
    # Determine time window
    MANILA_TZ = ZoneInfo("Asia/Manila")
    now = datetime.now(MANILA_TZ)
    if req.window == 'day':
        since = now.replace(hour=0, minute=0, second=0, microsecond=0)
    elif req.window == '3days':
        since = now - timedelta(days=3)
    elif req.window == 'week':
        since = now - timedelta(weeks=1)
    elif req.window == 'month':
        since = now - timedelta(days=30)
    else:
        raise HTTPException(status_code=400, detail="Invalid window")

    # Get all user's sessions (all time)
    sessions = db.query(SessionModel).filter(
        SessionModel.user_id == current_user.id
    ).all()
    session_ids = [s.id for s in sessions]
    if not session_ids:
        return {"diagnosis": "No sessions in this window.", "emotion_tally": {}, "intensity_breakdown": {}}

    # Get all emotion detections in these sessions, but only those in the time window
    detections = db.query(EmotionDetection).filter(
        EmotionDetection.session_id.in_(session_ids),
        EmotionDetection.timestamp >= since
    ).all()
    if not detections:
        return {"diagnosis": "No emotion detections in this window.", "emotion_tally": {}, "intensity_breakdown": {}}

    # Tally emotions and classify intensity
    emotion_tally = {}
    intensity_breakdown = {"mild": 0, "moderate": 0, "severe": 0}
    emotion_intensity_map = {}
    severe_negative_count = 0
    for det in detections:
        facial = db.query(FacialData).filter(FacialData.detection_id == det.id).first()
        if not facial:
            continue
        emotion = facial.emotion.lower()
        # Deterministic intensity assignment
        if emotion in ["happy", "content", "neutral"]:
            intensity = "mild"
        elif emotion in ["sad", "angry", "depressed", "furious", "fearful", "anxious", "stressed", "overwhelmed"]:
            intensity = "severe"
        else:
            intensity = "moderate"
        emotion_tally[emotion] = emotion_tally.get(emotion, 0) + 1
        intensity_breakdown[intensity] += 1
        if emotion not in emotion_intensity_map:
            emotion_intensity_map[emotion] = {"mild": 0, "moderate": 0, "severe": 0}
        emotion_intensity_map[emotion][intensity] += 1
        # Count severe negative emotions for awareness
        if intensity == "severe" and emotion in ["sad", "depressed", "angry", "furious", "fearful", "anxious", "stressed", "overwhelmed"]:
            severe_negative_count += 1

    # Check for suicidal/self-harm keywords in recent voice data
    recent_voice = db.query(VoiceData).join(EmotionDetection).filter(EmotionDetection.id.in_([d.id for d in detections])).order_by(VoiceData.id.desc()).limit(3).all()
    suicidal_flag = False
    if recent_voice:
        for v in recent_voice:
            if contains_suicidal_keywords(v.content):
                suicidal_flag = True
                break
    # Optionally, check facial emotion text as well (not just voice)
    if not suicidal_flag:
        for det in detections:
            facial = db.query(FacialData).filter(FacialData.detection_id == det.id).first()
            if facial and contains_suicidal_keywords(facial.emotion):
                suicidal_flag = True
                break

    # Prepare summary for Gemini
    summary = f"User emotion summary (window: {req.window}):\n"
    for emotion, count in emotion_tally.items():
        summary += f"- {emotion}: {count} times (mild: {emotion_intensity_map[emotion]['mild']}, moderate: {emotion_intensity_map[emotion]['moderate']}, severe: {emotion_intensity_map[emotion]['severe']})\n"
    summary += f"\nTotal detections: {len(detections)}\n"
    summary += f"Intensity breakdown: mild={intensity_breakdown['mild']}, moderate={intensity_breakdown['moderate']}, severe={intensity_breakdown['severe']}\n"
    if severe_negative_count > 0:
        summary += f"\nThere were {severe_negative_count} severe negative emotion detections.\n"
    if suicidal_flag:
        summary += ("\nWARNING: There are indications of suicidal thoughts or self-harm in recent user input. "
                    "Strongly recommend the user seek immediate professional help or contact a crisis hotline.\n")

    recent_voice = db.query(VoiceData).join(EmotionDetection).filter(EmotionDetection.id.in_([d.id for d in detections])).order_by(VoiceData.id.desc()).limit(3).all()
    if recent_voice:
        summary += "\nRecent voice entries:\n"
        for v in recent_voice:
            summary += f"- {v.content[:100]}\n"
    recent_suggestions = db.query(WellnessSuggestion).join(EmotionDetection).filter(EmotionDetection.id.in_([d.id for d in detections])).order_by(WellnessSuggestion.id.desc()).limit(3).all()
    if recent_suggestions:
        summary += "\nRecent wellness suggestions:\n"
        for s in recent_suggestions:
            summary += f"- {s.suggestion[:100]}\n"

    # Send to Gemini for diagnosis
    diagnosis_prompt = summary + "\n\nBased on the above, provide a brief mental health analysis. Use language like 'You are experiencing...' or 'It appears you may be experiencing...'. If there is a pattern of severe negative emotions (e.g., sadness, anger, fear), raise awareness and suggest the user may benefit from talking to a professional, but do NOT replace professional advice. Be concise, compassionate, and focus on awareness and next steps, not diagnosis."
    try:
        genai.configure(api_key=settings.gemini_api_key)
        model = genai.GenerativeModel('gemini-1.5-flash')
        response = model.generate_content(diagnosis_prompt)
        diagnosis = response.text.strip()
    except Exception as e:
        # Fallback to OpenRouter GPT-4o
        diagnosis = call_openrouter_gpt4o(diagnosis_prompt)

    return {
        "diagnosis": diagnosis,
        "emotion_tally": emotion_tally,
        "intensity_breakdown": intensity_breakdown,
        "emotion_intensity_map": emotion_intensity_map,
        "window": req.window
    }

@router.get("/intensity_chart")
def get_intensity_chart(
    window: str = 'week',
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    MANILA_TZ = ZoneInfo("Asia/Manila")
    now = datetime.now(MANILA_TZ)
    if window == 'day':
        since = now.replace(hour=0, minute=0, second=0, microsecond=0)
        days = [since.date()]
    elif window == '3days':
        since = now - timedelta(days=3)
        days = [(since + timedelta(days=i)).date() for i in range(4)]
    elif window == 'week':
        monday = now - timedelta(days=now.weekday())
        days = [(monday + timedelta(days=i)).date() for i in range(7)]
        since = monday.replace(hour=0, minute=0, second=0, microsecond=0)
    elif window == 'month':
        since = now - timedelta(days=30)
        days = [(since + timedelta(days=i)).date() for i in range(31)]
    else:
        raise HTTPException(status_code=400, detail="Invalid window")

    sessions = db.query(SessionModel).filter(
        SessionModel.user_id == current_user.id
    ).all()
    session_ids = [s.id for s in sessions]
    detections = db.query(EmotionDetection).filter(
        EmotionDetection.session_id.in_(session_ids),
        EmotionDetection.timestamp >= since
    ).all()

    day_map = defaultdict(list)
    for det in detections:
        det_date = det.timestamp.astimezone(MANILA_TZ).date()
        facial = db.query(FacialData).filter(FacialData.detection_id == det.id).first()
        if not facial:
            continue
        emotion = facial.emotion.lower()
        # Deterministic intensity assignment
        if emotion in ["happy", "content", "neutral"]:
            intensity = "mild"
        elif emotion in ["sad", "angry", "depressed", "furious", "fearful", "anxious", "stressed", "overwhelmed"]:
            intensity = "severe"
        else:
            intensity = "moderate"
        day_map[det_date].append((emotion, intensity))

    chart = []
    for day in days:
        emotions = [e for e, _ in day_map.get(day, [])]
        intensities = [i for _, i in day_map.get(day, [])]
        if emotions:
            dominant_emotion = Counter(emotions).most_common(1)[0][0]
            intensity_tally = {k: intensities.count(k) for k in ["mild", "moderate", "severe"]}
        else:
            dominant_emotion = None
            intensity_tally = {"mild": 0, "moderate": 0, "severe": 0}
        chart.append({
            "day": str(day),
            "dominant_emotion": dominant_emotion,
            "intensity_tally": intensity_tally
        })
    return chart

@router.get("/dominant_emotion_chart")
def get_dominant_emotion_chart(
    window: str = 'week',
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    MANILA_TZ = ZoneInfo("Asia/Manila")
    now = datetime.now(MANILA_TZ)
    if window == 'day':
        since = now.replace(hour=0, minute=0, second=0, microsecond=0)
        days = [since.date()]
    elif window == '3days':
        since = now - timedelta(days=3)
        days = [(since + timedelta(days=i)).date() for i in range(4)]
    elif window == 'week':
        monday = now - timedelta(days=now.weekday())
        days = [(monday + timedelta(days=i)).date() for i in range(7)]
        since = monday.replace(hour=0, minute=0, second=0, microsecond=0)
    elif window == 'month':
        since = now - timedelta(days=30)
        days = [(since + timedelta(days=i)).date() for i in range(31)]
    else:
        raise HTTPException(status_code=400, detail="Invalid window")

    sessions = db.query(SessionModel).filter(
        SessionModel.user_id == current_user.id
    ).all()
    session_ids = [s.id for s in sessions]
    detections = db.query(EmotionDetection).filter(
        EmotionDetection.session_id.in_(session_ids),
        EmotionDetection.timestamp >= since
    ).all()

    day_map = defaultdict(list)
    for det in detections:
        det_date = det.timestamp.astimezone(MANILA_TZ).date()
        facial = db.query(FacialData).filter(FacialData.detection_id == det.id).first()
        if not facial:
            continue
        emotion = facial.emotion.lower()
        day_map[det_date].append(emotion)

    chart = []
    for day in days:
        emotions = day_map.get(day, [])
        if emotions:
            dominant_emotion = Counter(emotions).most_common(1)[0][0]
        else:
            dominant_emotion = None
        chart.append({
            "day": str(day),
            "dominant_emotion": dominant_emotion
        })
    return chart

@router.get("/count")
def get_session_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get the total number of sessions for the current user."""
    count = db.query(SessionModel).filter(SessionModel.user_id == current_user.id).count()
    return {"count": count}

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
    """Process emotion data and generate wellness suggestions using Gemini 1.5 Flash. Also ends the session automatically."""
    from zoneinfo import ZoneInfo
    MANILA_TZ = ZoneInfo("Asia/Manila")
    detection = EmotionDetection(session_id=session_id, timestamp=datetime.now(MANILA_TZ)) # Use Manila time for timestamp
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
    suggestion_text = None
    try:
        # Check for suicidal/self-harm keywords
        if contains_suicidal_keywords(req.voice_content):
            prompt = (
                "The user has expressed thoughts of suicide or self-harm. "
                "Your role is to be extremely gentle, calm, and supportive. "
                "Do NOT judge or dismiss their feelings. "
                "Encourage them to reach out to a mental health professional or crisis hotline immediately. "
                "Provide immediate comfort, grounding techniques, and remind them they are not alone. "
                "Format: [Gentle acknowledgment] • [Immediate comfort] • [Crisis support suggestion] • [Encouragement to seek help]"
                f"\nUser's message: '{req.voice_content}'"
            )
        else:
            prompt = build_gemini_prompt(req.emotion.lower(), req.voice_content)
        # Try Gemini
        genai.configure(api_key=settings.gemini_api_key)
        model = genai.GenerativeModel('gemini-1.5-flash')
        response = model.generate_content(prompt)
        suggestion_text = format_gemini_response(response.text, req.emotion.lower())
    except Exception as e:
        # Fallback to OpenRouter GPT-4o
        suggestion_text = call_openrouter_gpt4o(prompt)

    # 5. Store suggestion
    suggestion = WellnessSuggestion(
        detection_id=detection.id,
        suggestion=suggestion_text
    )
    db.add(suggestion)
    db.commit()
    db.refresh(suggestion)

    # 6. End the session automatically
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.user_id == current_user.id
    ).first()
    if session and not session.end_time:
        session.end_time = datetime.now(MANILA_TZ)
        db.commit()

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
        
        
        emotion = emotion.lower()
        prompt = build_gemini_prompt(emotion, content)
        
        
        response = model.generate_content(prompt)
        
       
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

    else:   
        return base_prompt.format(emotion=emotion, content=content)

def format_gemini_response(response_text: str, emotion: str) -> str:
    """Format Gemini's response for consistent output."""
    response_text = response_text.strip()
    
    if '•' not in response_text:
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
    
    if emotion == "stressed": 
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
            facial_data=facial_response, 
            voice_data=voice_response,   
            wellness_suggestions=wellness_suggestion_response, 
            emotion_color=facial_emotion_color, 
            facial_emotion=facial_emotion_str 
        ))

    return SessionWithDetections(
        id=session.id,
        user_id=session.user_id,
        start_time=session.start_time,
        end_time=session.end_time,
        emotion_detections=detection_data
    )