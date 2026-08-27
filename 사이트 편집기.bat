@echo off
setlocal
title PIXELARIOUS 사이트 편집기

cd /d "%~dp0"

set "URL=http://localhost:3000/editor"

echo.
echo   PIXELARIOUS 사이트 편집기
echo   ------------------------------------
echo.

rem --- 이미 개발 서버가 떠 있으면 브라우저만 연다 (편집기는 개발 서버 전용) ---
curl -sf -o nul "%URL%" && (
  echo   [i] 개발 서버가 이미 떠 있다. 브라우저만 연다.
  goto :open
)

rem --- 3000번을 다른 놈이 잡고 있으면 여기서 멈춘다 ---
netstat -ano | findstr /r /c:":3000 " | findstr "LISTENING" >nul && (
  echo   [!] 3000번 포트를 다른 서버가 잡고 있는데
  echo       %URL% 이 열리지 않는다.
  echo       예전에 켜둔 프로덕션 빌드나 죽다 만 서버다.
  echo       그 창을 닫고 다시 실행해라.
  echo.
  pause
  exit /b 1
)

rem --- 의존성 없으면 먼저 깔고 ---
if not exist "node_modules" (
  echo   [i] node_modules 가 없다. npm install 부터.
  call npm install
  if errorlevel 1 (
    echo   [!] npm install 실패.
    pause
    exit /b 1
  )
)

rem --- 개발 서버를 별도 창으로 띄운다 (이 창을 닫아도 서버는 산다) ---
echo   [i] 개발 서버를 켜는 중...
start "PIXELARIOUS DEV SERVER" cmd /k npm run dev

rem --- 편집기가 응답할 때까지 최대 90초 대기 ---
set /a TRY=0
:wait
set /a TRY+=1
if %TRY% gtr 90 goto :timeout
ping -n 2 127.0.0.1 >nul
curl -sf -o nul "%URL%" && goto :open
goto :wait

:timeout
echo   [!] 90초 안에 서버가 뜨지 않았다. DEV SERVER 창의 로그를 봐라.
echo.
pause
exit /b 1

:open
echo   [+] %URL%
start "" "%URL%"
exit /b 0
