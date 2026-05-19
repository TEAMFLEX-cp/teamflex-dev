@echo off
chcp 65001 > nul
cd /d "%~dp0"
title TeamFlex 실시간 감지 시작

echo.
echo  ╔══════════════════════════════════════════════════════════╗
echo  ║   TeamFlex 실시간 감지 시작                              ║
echo  ║                                                          ║
echo  ║   [1] Chrome CDP 시작 (포트 9222)                        ║
echo  ║   [2] Teams 폴러 연속 실행 (오배송+2회전 감지)            ║
echo  ║   [3] 수량 체크 스케줄러 (18/19/20시 자동)               ║
echo  ╚══════════════════════════════════════════════════════════╝
echo.

:: ── Chrome 경로 탐색 ───────────────────────────────────────────
set CHROME=
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe"       set CHROME=C:\Program Files\Google\Chrome\Application\chrome.exe
if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" set CHROME=C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
if exist "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"          set CHROME=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe

if not defined CHROME (
  echo  !! Chrome을 찾을 수 없습니다. Chrome을 설치 후 다시 실행하세요.
  pause & exit /b 1
)

:: ── STEP 1: Chrome CDP 확인 / 시작 ─────────────────────────────
echo  ┌─ STEP 1: Chrome CDP (포트 9222) ──────────────────────────
curl -s --max-time 2 http://localhost:9222/json >nul 2>&1
if not errorlevel 1 (
  echo  │  ✅ 이미 실행 중 — 기존 Chrome 사용
) else (
  echo  │  Chrome 시작 중...
  start "" "%CHROME%" ^
    --remote-debugging-port=9222 ^
    --remote-allow-origins=* ^
    --user-data-dir="%TEMP%\ChromeTeamsDebug" ^
    --window-size=1200,800 ^
    --no-first-run ^
    --no-default-browser-check ^
    "https://teams.cloud.microsoft/v2/"

  echo  │  대기 중 (10초)...
  timeout /t 10 /nobreak >nul

  :: fly.coupang.com 탭 추가
  start "" "%CHROME%" ^
    --remote-debugging-port=9222 ^
    --remote-allow-origins=* ^
    --user-data-dir="%TEMP%\ChromeTeamsDebug" ^
    "https://fly.coupang.com/ui/dashboard/realtime"
  timeout /t 3 /nobreak >nul

  curl -s --max-time 3 http://localhost:9222/json >nul 2>&1
  if errorlevel 1 (
    echo  │  !! Chrome CDP 응답 없음. 잠시 후 다시 시도하세요.
    pause & exit /b 1
  )
  echo  │  ✅ Chrome CDP 준비 완료
)
echo  └────────────────────────────────────────────────────────────
echo.

:: ── STEP 2: 탭 상태 확인 ────────────────────────────────────────
echo  ┌─ STEP 2: 탭 상태 확인 ─────────────────────────────────────
python -c "
import urllib.request, json
try:
    with urllib.request.urlopen('http://localhost:9222/json', timeout=3) as r:
        tabs = json.load(r)
    teams = [t for t in tabs if 'teams.cloud.microsoft' in t.get('url','')]
    fly   = [t for t in tabs if 'fly.coupang.com' in t.get('url','')]
    print('  │  전체 탭:', len(tabs), '개')
    print('  │  Teams:', '✅ 로그인됨' if teams else '❌ 없음 → Chrome에서 Teams 로그인 필요')
    print('  │  신선:  ', '✅ 로그인됨' if fly   else '⚠️  없음 (신선 감지 비활성)')
except Exception as e:
    print('  │  !! CDP 연결 실패:', e)
" 2>&1
echo  └────────────────────────────────────────────────────────────
echo.

:: ── STEP 3: 폴러 + 스케줄러 별도 창으로 실행 ───────────────────
echo  ┌─ STEP 3: 감지 서비스 시작 ─────────────────────────────────
echo  │
echo  │  [창 1] Teams 폴러 — 오배송 + 2회전 감지 (30초 주기)
start "📡 TeamFlex 폴러 [오배송+2회전]" cmd /k "chcp 65001>nul && cd /d "%~dp0" && echo. && echo  ===================================== && echo    TeamFlex Teams 폴러 실행 중... && echo    오배송 / 2회전 예상 감지 (30초 주기) && echo  ===================================== && echo. && python teams_poller.py"

timeout /t 2 /nobreak >nul

echo  │  [창 2] 수량 체크 스케줄러 — 18/19/20시 자동 체크
start "⏰ TeamFlex 수량체크 스케줄러" cmd /k "chcp 65001>nul && cd /d "%~dp0" && echo. && echo  ===================================== && echo    TeamFlex 수량 체크 스케줄러 실행 중... && echo    설정된 시간에 자동 수량 체크 && echo  ===================================== && echo. && python qty_check_scheduler.py"

echo  │
echo  └────────────────────────────────────────────────────────────
echo.
echo  ════════════════════════════════════════════════════════════
echo   ✅ 실시간 감지 서비스 시작 완료!
echo.
echo   열린 창:
echo    📡 폴러 창  — Teams 메시지 감지 (오배송/2회전)
echo    ⏰ 스케줄러 창 — 수량 체크 자동화
echo.
echo   중단하려면: 각 창에서 Ctrl+C 또는 창 닫기
echo   앱 확인:    https://teamflex-cp.github.io/teamflex-dev
echo  ════════════════════════════════════════════════════════════
echo.
pause
