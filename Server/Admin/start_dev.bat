@echo off
echo Starting Django development server with ASGI support...
echo.
echo This will start the server with WebSocket support enabled.
echo.
echo Make sure you have activated your virtual environment first!
echo.
pause

REM Activate virtual environment (adjust path if needed)
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
) else (
    echo Virtual environment not found. Please activate it manually.
    pause
    exit /b 1
)

REM Start Django server with ASGI support using Daphne
echo Starting server on http://localhost:8000
echo WebSocket endpoint: ws://localhost:8000/ws/analytics/
echo.
echo Press Ctrl+C to stop the server
echo.

python -m daphne -b 0.0.0.0 -p 8000 FaceofMindAPI.asgi:application

pause 