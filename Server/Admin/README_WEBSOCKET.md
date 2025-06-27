# WebSocket Setup for Django Development Server

## Problem
The standard Django `runserver` command doesn't support WebSockets. You need to use an ASGI server like Daphne to enable WebSocket functionality.

## Solution
Use the provided startup scripts to run the Django server with ASGI support.

## Windows
```bash
# Option 1: Use the batch file
start_dev.bat

# Option 2: Manual command
python -m daphne -b 0.0.0.0 -p 8000 FaceofMindAPI.asgi:application
```

## Unix/Linux/Mac
```bash
# Option 1: Use the shell script
chmod +x start_dev.sh
./start_dev.sh

# Option 2: Manual command
python -m daphne -b 0.0.0.0 -p 8000 FaceofMindAPI.asgi:application
```

## What This Does
- Starts Django with ASGI support using Daphne
- Enables WebSocket connections on `ws://localhost:8000/ws/analytics/`
- Maintains all existing HTTP API functionality
- Provides real-time analytics updates to the Angular frontend

## Verification
After starting the server, you should see:
- HTTP API endpoints working normally
- WebSocket endpoint accessible at `ws://localhost:8000/ws/analytics/`
- No more 404 errors for WebSocket connections in the browser console

## Troubleshooting
If you still get WebSocket connection errors:
1. Make sure you're using the ASGI server (Daphne) and not `python manage.py runserver`
2. Check that the virtual environment is activated
3. Verify that all requirements are installed: `pip install -r requirements.txt`
4. Ensure the Angular proxy is configured correctly for HTTP requests 