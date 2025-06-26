# FaceofMind User API

A FastAPI-based backend for the FaceofMind application, providing user management, authentication, and session management features.

## Features

- **User Authentication**: JWT-based authentication with access and refresh tokens
- **User Management**: CRUD operations for user accounts with role-based access control
- **Session Management**: Create, track, and manage user sessions
- **Database Integration**: PostgreSQL database with SQLAlchemy ORM
- **API Documentation**: Automatic OpenAPI/Swagger documentation
- **CORS Support**: Cross-origin resource sharing enabled

## Tech Stack

- **FastAPI**: Modern, fast web framework for building APIs
- **SQLAlchemy**: SQL toolkit and ORM
- **PostgreSQL**: Primary database
- **JWT**: JSON Web Tokens for authentication
- **Alembic**: Database migration tool
- **Pydantic**: Data validation using Python type annotations

## Project Structure

```
Server/User/
├── main.py                 # FastAPI application entry point
├── config.py              # Configuration settings
├── database.py            # Database connection and session management
├── models.py              # SQLAlchemy models
├── schemas.py             # Pydantic schemas for request/response
├── auth.py                # Authentication utilities
├── dependencies.py        # FastAPI dependencies
├── requirements.txt       # Python dependencies
├── alembic.ini           # Alembic configuration
├── routers/              # API route modules
│   ├── __init__.py
│   ├── auth.py           # Authentication routes
│   ├── users.py          # User management routes
│   └── sessions.py       # Session management routes
└── README.md             # This file
```

## Setup Instructions

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Environment Configuration

The application uses the following environment variables (configured in `config.py`):

- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET_TOKEN`: Secret key for JWT token signing
- `JWT_ACCESS_TOKEN`: Access token secret
- `JWT_REFRESH_TOKEN`: Refresh token secret
- `JWT_ACCESS_TOKEN_EXPIRE_MINUTES`: Access token expiration time
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_EMAIL`, `SMTP_PASSWORD`: Email configuration

### 3. Database Setup

The application will automatically create tables when first run. For production, use Alembic migrations:

```bash
# Initialize Alembic (first time only)
alembic init alembic

# Create a migration
alembic revision --autogenerate -m "Initial migration"

# Apply migrations
alembic upgrade head
```

### 4. Run the Application

```bash
# Development server
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Or run directly
python main.py
```

## API Endpoints

### Authentication (`/api/v1/auth`)

- `POST /register` - Register a new user
- `POST /login` - Login and get access token
- `POST /refresh` - Refresh access token
- `GET /me` - Get current user information

### Users (`/api/v1/users`)

- `GET /` - Get all users (admin only)
- `GET /{user_id}` - Get specific user
- `PUT /{user_id}` - Update user
- `DELETE /{user_id}` - Delete user (admin only)
- `PATCH /{user_id}/activate` - Activate user (admin only)
- `PATCH /{user_id}/deactivate` - Deactivate user (admin only)

### Sessions (`/api/v1/sessions`)

- `POST /` - Create new session
- `GET /` - Get user sessions
- `GET /{session_id}` - Get specific session
- `PATCH /{session_id}/end` - End session
- `DELETE /{session_id}` - Delete session

## Database Models

### User
- `id`: Primary key
- `email`: Unique email address
- `password`: Hashed password
- `first_name`: User's first name
- `last_name`: User's last name
- `role`: User role (user, admin, etc.)
- `status`: Account status (inactive, active, deactivated, suspended)
- `created_at`: Account creation timestamp

### Session
- `id`: Primary key
- `user_id`: Foreign key to User
- `start_time`: Session start timestamp
- `end_time`: Session end timestamp (nullable)

### Additional Models
- `EmotionDetection`: Tracks emotion detection sessions
- `FacialData`: Stores facial emotion data
- `VoiceData`: Stores voice analysis data
- `Feedback`: User feedback for sessions
- `WellnessSuggestion`: Wellness recommendations
- `CommunityPost`: Community posts
- `CommunityComment`: Comments on posts
- `Reminder`: User reminders

## Authentication

The API uses JWT (JSON Web Tokens) for authentication:

1. **Login**: User provides email/password, receives access token
2. **Access**: Include token in Authorization header: `Bearer <token>`
3. **Refresh**: Use refresh token to get new access token when expired

### Example Usage

```bash
# Register a new user
curl -X POST "http://localhost:8000/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123",
    "first_name": "John",
    "last_name": "Doe",
    "role": "user"
  }'

# Login
curl -X POST "http://localhost:8000/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'

# Use access token
curl -X GET "http://localhost:8000/api/v1/auth/me" \
  -H "Authorization: Bearer <access_token>"
```

## API Documentation

Once the server is running, you can access:

- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`
- **OpenAPI JSON**: `http://localhost:8000/openapi.json`

## Development

### Adding New Endpoints

1. Create a new router file in `routers/`
2. Define your endpoints with proper schemas
3. Include the router in `main.py`

### Database Migrations

```bash
# Create new migration
alembic revision --autogenerate -m "Description of changes"

# Apply migrations
alembic upgrade head

# Rollback migration
alembic downgrade -1
```

### Testing

```bash
# Run with pytest (if tests are added)
pytest

# Run with coverage
pytest --cov=.
```

## Production Deployment

1. Set up proper environment variables
2. Configure CORS origins for production
3. Use a production ASGI server like Gunicorn
4. Set up proper logging
5. Configure database connection pooling
6. Set up monitoring and health checks

## Security Considerations

- Passwords are hashed using bcrypt
- JWT tokens have expiration times
- CORS is configured (adjust for production)
- Role-based access control implemented
- Input validation using Pydantic schemas

## License

This project is part of the FaceofMind application.

## OTP Registration & Verification

- When a user registers, an OTP is sent to their email.
- The user must verify the OTP using `/api/v1/auth/verify-otp` to activate their account.
- OTPs are stored securely in Redis and expire after 5 minutes.

### Example Usage

```bash
# Register a new user (triggers OTP email)
curl -X POST "http://localhost:9000/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123",
    "first_name": "John",
    "last_name": "Doe",
    "role": "user"
  }'

# Verify OTP
curl -X POST "http://localhost:9000/api/v1/auth/verify-otp" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "otp": "123456"
  }'
```

## Running on a Different Port

To avoid conflict with Django (port 8000), run FastAPI on port 9000:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 9000
# or
python run.py 9000
```

Swagger UI will be available at: `http://localhost:9000/docs` 