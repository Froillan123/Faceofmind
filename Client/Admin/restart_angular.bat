@echo off
echo Stopping Angular development server...
echo.
echo Please stop the current Angular server (Ctrl+C) if it's running.
echo.
pause

echo Starting Angular development server with routing fixes...
echo.
echo This will enable proper handling of page refreshes.
echo.

ng serve --port 4200 --host 0.0.0.0

pause 