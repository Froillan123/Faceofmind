from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.orm import Session
from database import get_db
from models import User, UserStatus
from schemas import UserCreate, UserResponse, LoginRequest, TokenResponse, RefreshTokenRequest
from auth import verify_password, get_password_hash, create_access_token, create_refresh_token, get_user_from_refresh_token
from dependencies import get_current_user
from datetime import timedelta
from otp import generate_otp, store_otp, verify_otp
import smtplib
from email.mime.text import MIMEText
from config import settings
import asyncio
from fastapi import BackgroundTasks

router = APIRouter(prefix="/auth", tags=["authentication"])


def send_otp_email(email: str, otp: str):
    msg = MIMEText(f"Your FaceofMind verification code is: {otp}")
    msg["Subject"] = "FaceofMind Email Verification Code"
    msg["From"] = settings.smtp_email
    msg["To"] = email
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port) as server:
        server.starttls()
        server.login(settings.smtp_email, settings.smtp_password)
        server.sendmail(settings.smtp_email, [email], msg.as_string())


@router.post("/register", response_model=UserResponse)
def register(user_data: UserCreate, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """Register a new user."""
    # Check if user already exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create new user
    hashed_password = get_password_hash(user_data.password)
    db_user = User(
        email=user_data.email,
        password=hashed_password,
        first_name=user_data.first_name,
        last_name=user_data.last_name,
        role="user",
        status=UserStatus.INACTIVE  # Default to inactive, needs activation
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    # Generate and send OTP
    otp = generate_otp()
    # Use asyncio.run for sync context
    try:
        asyncio.run(store_otp(user_data.email, otp))
    except RuntimeError:
        # If already in an event loop (e.g. in tests), fallback to loop.run_until_complete
        loop = asyncio.get_event_loop()
        loop.run_until_complete(store_otp(user_data.email, otp))
    background_tasks.add_task(send_otp_email, user_data.email, otp)
    
    return db_user


@router.post("/login", response_model=TokenResponse)
def login(login_data: LoginRequest, db: Session = Depends(get_db)):
    """Login user and return access token."""
    # Find user by email
    user = db.query(User).filter(User.email == login_data.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Verify password
    if not verify_password(login_data.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Check if user is active
    if user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is not active. Please contact administrator."
        )
    
    # Create access token
    access_token_expires = timedelta(minutes=30)
    access_token = create_access_token(
        data={"sub": str(user.id), "email": user.email, "role": user.role},
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": 30 * 60  # 30 minutes in seconds
    }


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(refresh_data: RefreshTokenRequest):
    """Refresh access token using refresh token."""
    # Verify refresh token
    payload = get_user_from_refresh_token(refresh_data.refresh_token)
    
    # Create new access token
    access_token_expires = timedelta(minutes=30)
    access_token = create_access_token(
        data={"sub": payload.get("sub"), "email": payload.get("email"), "role": payload.get("role")},
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": 30 * 60  # 30 minutes in seconds
    }


@router.get("/me", response_model=UserResponse)
def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current user information."""
    return current_user 


@router.post("/verify-otp")
async def verify_otp_endpoint(email: str = Body(...), otp: str = Body(...), db: Session = Depends(get_db)):
    if not await verify_otp(email, otp):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP")
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.status = UserStatus.ACTIVE
    db.commit()
    db.refresh(user)
    return {"message": "OTP verified, account activated", "user": user} 