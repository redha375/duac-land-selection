@echo off
cd /d "%~dp0"
start "Parcel app local server" /min py -m http.server 8765 --directory www
ping 127.0.0.1 -n 3 > nul
start "" http://127.0.0.1:8765/
echo Keep the local server window open while using the app.
pause
