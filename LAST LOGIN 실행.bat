@echo off
chcp 65001 >nul
setlocal
title LAST LOGIN (데스크톱 실행)

cd /d "%~dp0"

rem --- 데스크톱 실행본: Godot 편집기 실행 파일로 프로젝트를 바로 띄운다 (익스포트 불필요) ---
rem --- Godot 경로: 환경 변수 GODOT가 있으면 그것을, 없으면 PATH의 godot를 쓴다 ---
if not defined GODOT (
  for /f "delims=" %%G in ('where godot 2^>nul') do if not defined GODOT set "GODOT=%%G"
)
if not defined GODOT (
  echo   [!] Godot 4 실행 파일을 찾지 못했다.
  echo       PATH에 godot를 추가하거나, 환경 변수 GODOT에 godot.exe 경로를 지정한다.
  echo       예^) set GODOT=C:\tools\godot\godot.exe
  pause
  exit /b 1
)
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
