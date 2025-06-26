#!/usr/bin/env python3
"""
Simple script to run the FaceofMind User API
"""

import sys
import uvicorn
from main import app

if __name__ == "__main__":
    port = 9000
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except Exception:
            print("Invalid port argument, using default 9000.")
    print(f"Starting FaceofMind User API on port {port}...")
    print(f"API Documentation will be available at: http://localhost:{port}/docs")
    print("Press Ctrl+C to stop the server")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        reload=True,
        log_level="info"
    ) 