from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.orm import Session
from database import get_db
from models import User, UserStatus
from schemas import UserCreate, UserResponse, LoginRequest, TokenResponse, RefreshTokenRequest, RegisterResponse, PasswordResetRequest, PasswordResetConfirm
from auth import verify_password, get_password_hash, create_access_token, create_refresh_token, get_user_from_refresh_token, store_jwt_in_redis, remove_jwt_from_redis
from dependencies import get_current_user
from datetime import timedelta
from otp import generate_otp, store_otp, verify_otp
import smtplib
from email.mime.text import MIMEText
from config import settings
import asyncio
from fastapi import BackgroundTasks
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

router = APIRouter(prefix="/auth", tags=["authentication"])

security = HTTPBearer()


def send_otp_email(email: str, otp: str):
    html_content = f"""
    <html>
      <body style='font-family: Arial, sans-serif; color: #222;'>
        <div style='max-width: 480px; margin: 0 auto; border: 1px solid #eee; border-radius: 12px; padding: 24px; background: #f9f9f9;'>
          <h2 style='color: #5CD581;'>Welcome to FaceofMind!</h2>
          <p>Thank you for registering. Your verification code is:</p>
          <div style='font-size: 28px; font-weight: bold; color: #5CD581; margin: 16px 0;'>{otp}</div>
          <p style='margin-top: 24px;'>If you did not request this, you can ignore this email.</p>
          <p style='color: #888; font-size: 13px; margin-top: 24px;'>
            <b>Note:</b> If you don't see this email in your inbox, please check your <b>Spam</b> or <b>Junk</b> folder.
          </p>
        </div>
      </body>
    </html>
    """
    msg = MIMEText(html_content, 'html')
    msg["Subject"] = "FaceofMind Email Verification Code"
    msg["From"] = settings.smtp_email
    msg["To"] = email
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port) as server:
        server.starttls()
        server.login(settings.smtp_email, settings.smtp_password)
        server.sendmail(settings.smtp_email, [email], msg.as_string())


def send_password_reset_email(email: str, otp: str):
    html_content = f"""
    <html>
      <body style='font-family: Arial, sans-serif; color: #222;'>
        <div style='max-width: 480px; margin: 0 auto; border: 1px solid #eee; border-radius: 12px; padding: 24px; background: #f9f9f9;'>
          <h2 style='color: #3498db;'>FaceofMind Password Reset</h2>
          <p>Here is your password reset code:</p>
          <div style='font-size: 28px; font-weight: bold; color: #3498db; margin: 16px 0;'>{otp}</div>
          <p style='margin-top: 24px;'>If you did not request a password reset, you can ignore this email.</p>
          <p style='color: #888; font-size: 13px; margin-top: 24px;'>
            <b>Note:</b> If you don't see this email in your inbox, please check your <b>Spam</b> or <b>Junk</b> folder.
          </p>
        </div>
      </body>
    </html>
    """
    msg = MIMEText(html_content, 'html')
    msg["Subject"] = "FaceofMind Password Reset Code"
    msg["From"] = settings.smtp_email
    msg["To"] = email
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port) as server:
        server.starttls()
        server.login(settings.smtp_email, settings.smtp_password)
        server.sendmail(settings.smtp_email, [email], msg.as_string())


@router.post("/register", response_model=RegisterResponse)
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
        status=UserStatus.INACTIVE  
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    # Generate and send OTP
    otp = generate_otp()
    try:
        asyncio.run(store_otp(user_data.email, otp))
    except RuntimeError:
        loop = asyncio.get_event_loop()
        loop.run_until_complete(store_otp(user_data.email, otp))
    background_tasks.add_task(send_otp_email, user_data.email, otp)
    
    return {
        "message": "User registered successfully. An OTP has been sent to your email for verification.",
        "user": db_user
    }


@router.post("/login", response_model=TokenResponse)
async def login(login_data: LoginRequest, db: Session = Depends(get_db)):
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
    
    # Check if user is suspended
    if user.status == UserStatus.SUSPENDED:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been suspended. Contact the administrator to see if you violated terms and conditions."
        )

    # Check if user is active
    if user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is not active. Please verify your email."
        )
    
    # Check if user is only 'user' role
    if user.role != 'user':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only users can log in from this portal."
        )
    
    # Create access token
    access_token_expires = timedelta(minutes=30)
    access_token = create_access_token(
        data={"sub": str(user.id), "email": user.email, "role": user.role},
        expires_delta=access_token_expires
    )
    
    # Store JWT in Redis
    await store_jwt_in_redis(access_token, str(user.id), 30 * 60)
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": 30 * 60,  # 30 minutes in seconds
        # User info for frontend
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "role": user.role,
        "status": user.status,
        "created_at": user.created_at,
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


@router.post("/logout")
async def logout(credentials: HTTPAuthorizationCredentials = Depends(security), current_user: User = Depends(get_current_user)):
    token = credentials.credentials
    await remove_jwt_from_redis(token, str(current_user.id))
    return {"message": "Successfully logged out."}


@router.post("/request-password-reset")
def request_password_reset(data: PasswordResetRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User with this email does not exist.")
    otp = generate_otp()
    try:
        asyncio.run(store_otp(data.email, otp))
    except RuntimeError:
        loop = asyncio.get_event_loop()
        loop.run_until_complete(store_otp(data.email, otp))
    background_tasks.add_task(send_password_reset_email, data.email, otp)
    return {"message": "Password reset OTP sent to your email."}


@router.post("/reset-password")
def reset_password(data: PasswordResetConfirm, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User with this email does not exist.")
    # Verify OTP
    try:
        valid = asyncio.run(verify_otp(data.email, data.otp))
    except RuntimeError:
        loop = asyncio.get_event_loop()
        valid = loop.run_until_complete(verify_otp(data.email, data.otp))
    if not valid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP.")
    # Set new password
    user.password = get_password_hash(data.new_password)
    db.commit()
    db.refresh(user)
    return {"message": "Password has been reset successfully."}