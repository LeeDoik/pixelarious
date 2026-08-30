@echo off
setlocal
title LAST LOGIN (데스크톱 실행)

cd /d "%~dp0"

rem --- 데스크톱 실행본: Godot 편집기 실행 파일로 프로젝트를 바로 띄운다 (익스포트 불필요) ---
set "GODOT=C:\Users\LeeDoik\tools\godot\godot.exe"
if not exist "%GODOT%" (
  echo   [!] Godot 실행 파일이 없다: %GODOT%
  pause
  exit /b 1
)

echo.
echo   LAST LOGIN — 데스크톱 실행
echo   ------------------------------------
echo   세이브: %%APPDATA%%\Godot\app_userdata\LAST LOGIN\save.json
echo   처음부터 다시 하려면 그 파일을 지우고 실행한다.
echo.

start "" "%GODOT%" --path "games-src\last-login"
