@echo off
setlocal EnableDelayedExpansion

REM Usage: skill_install.cmd <platform> [skill]
REM   platform: cursor | claudecode | codex  (aliases: claude, claude-code)
REM   skill:    omitted or "all" installs every skill in this repo (overwrite if present)

set "SCRIPT_NAME=skill_install.cmd"
set "PLATFORM=%~1"
set "SKILL=%~2"
set "REPO_ROOT=%~dp0"
if "%REPO_ROOT:~-1%"=="\" set "REPO_ROOT=%REPO_ROOT:~0,-1%"

if /I "%PLATFORM%"=="-h" goto :help
if /I "%PLATFORM%"=="--help" goto :help
if "%PLATFORM%"=="" goto :usage

call :log_info "starting %SCRIPT_NAME% REPO_ROOT=%REPO_ROOT%"
call :log_info "PLATFORM arg=%PLATFORM% SKILL arg=%SKILL%"

call :normalize_platform "%PLATFORM%"
if errorlevel 1 exit /b 1
set "PLATFORM=!NORM_PLATFORM!"
call :log_info "normalized platform=!PLATFORM!"

call :dest_root "!PLATFORM!"
set "DEST_ROOT=!SKILLS_ROOT!"
call :log_info "skills root=!DEST_ROOT!"

if "%SKILL%"=="" goto :install_all
if /I "%SKILL%"=="all" goto :install_all
if "%SKILL%"=="-" goto :install_all
if "%SKILL%"=="*" goto :install_all
goto :install_one

:install_all
call :log_step "mode: install all skills from repository"
set "COUNT=0"
for /d %%D in ("%REPO_ROOT%\*") do (
  if exist "%%D\SKILL.md" (
  call :install_skill "%%~nxD"
  if errorlevel 1 exit /b 1
  set /a COUNT+=1
  )
)
call :log_ok "batch install finished (!COUNT! skill(s))"
exit /b 0

:install_one
call :log_step "mode: install single skill %SKILL%"
call :install_skill "%SKILL%"
if errorlevel 1 exit /b 1
call :log_ok "single install finished"
exit /b 0

:install_skill
set "SKILL_NAME=%~1"
set "SRC=%REPO_ROOT%\%SKILL_NAME%"
set "DEST=%DEST_ROOT%\%SKILL_NAME%"

call :log_info "----- install skill=!SKILL_NAME! platform=!PLATFORM! -----"
call :log_debug "source=%SRC%"

if not exist "%SRC%\SKILL.md" (
  call :log_error "no skill '!SKILL_NAME!' (missing SKILL.md)"
  exit /b 1
)

call :log_info "destination=%DEST%"
if exist "%DEST%" (
  call :log_warn "existing install at %DEST%; will replace"
  dir /a "%DEST%" 2>nul
) else (
  call :log_debug "no previous install at %DEST%"
)

if not exist "%DEST_ROOT%" (
  call :log_step "mkdir %DEST_ROOT%"
  mkdir "%DEST_ROOT%"
)

if exist "%DEST%" (
  call :log_step "remove previous %DEST%"
  rmdir "%DEST%" 2>nul
  if exist "%DEST%" rd /s /q "%DEST%" 2>nul
  if exist "%DEST%" del /f /q "%DEST%" 2>nul
)

call :log_step "mklink /J %DEST% %SRC%"
mklink /J "%DEST%" "%SRC%" 2>nul
if not errorlevel 1 (
  call :log_ok "installed '!SKILL_NAME!' -> %DEST% (junction)"
  dir /a "%DEST%" 2>nul
  if /I "!PLATFORM!"=="codex" goto :codex_legacy
  exit /b 0
)

call :log_warn "junction failed; falling back to robocopy mirror"
call :log_step "robocopy %SRC% %DEST% /E /IS /IT"
robocopy "%SRC%" "%DEST%" /E /IS /IT
if errorlevel 8 (
  call :log_error "failed to copy '!SKILL_NAME!' to %DEST% (robocopy exit !ERRORLEVEL!)"
  exit /b 1
)
call :log_ok "installed '!SKILL_NAME!' -> %DEST% (copy)"
dir /a "%DEST%" 2>nul

:codex_legacy
if /I not "!PLATFORM!"=="codex" exit /b 0
set "LEGACY_ROOT=%USERPROFILE%\.codex\skills"
set "LEGACY_DEST=%LEGACY_ROOT%\%SKILL_NAME%"
call :log_info "legacy codex destination=!LEGACY_DEST!"
if not exist "%LEGACY_ROOT%" (
  call :log_step "mkdir %LEGACY_ROOT%"
  mkdir "%LEGACY_ROOT%"
)
if exist "%LEGACY_DEST%" (
  call :log_step "remove previous legacy !LEGACY_DEST!"
  rmdir "%LEGACY_DEST%" 2>nul
  if exist "%LEGACY_DEST%" rd /s /q "%LEGACY_DEST%" 2>nul
)
call :log_step "mklink /J !LEGACY_DEST! %SRC%"
mklink /J "%LEGACY_DEST%" "%SRC%" 2>nul
if not errorlevel 1 (
  call :log_ok "legacy install '!SKILL_NAME!' -> !LEGACY_DEST! (junction)"
) else (
  call :log_warn "legacy junction failed; robocopy copy"
  robocopy "%SRC%" "%LEGACY_DEST%" /E /IS /IT
  if errorlevel 8 exit /b 1
  call :log_ok "legacy install '!SKILL_NAME!' -> !LEGACY_DEST! (copy)"
)
exit /b 0

:normalize_platform
set "NORM_PLATFORM="
set "P=%~1"
if /I "%P%"=="cursor" set "NORM_PLATFORM=cursor" & exit /b 0
if /I "%P%"=="claudecode" set "NORM_PLATFORM=claudecode" & exit /b 0
if /I "%P%"=="claude" set "NORM_PLATFORM=claudecode" & exit /b 0
if /I "%P%"=="claude-code" set "NORM_PLATFORM=claudecode" & exit /b 0
if /I "%P%"=="codex" set "NORM_PLATFORM=codex" & exit /b 0
call :log_error "unknown platform: %~1"
exit /b 1

:dest_root
set "SKILLS_ROOT="
if /I "%~1"=="cursor" set "SKILLS_ROOT=%USERPROFILE%\.cursor\skills" & exit /b 0
if /I "%~1"=="claudecode" set "SKILLS_ROOT=%USERPROFILE%\.claude\skills" & exit /b 0
if /I "%~1"=="codex" set "SKILLS_ROOT=%USERPROFILE%\.agents\skills" & exit /b 0
exit /b 1

:log_info
echo INFO  %SCRIPT_NAME%: %*
exit /b 0

:log_warn
echo WARN  %SCRIPT_NAME%: %*
exit /b 0

:log_error
echo ERROR %SCRIPT_NAME%: %*
exit /b 0

:log_ok
echo OK    %SCRIPT_NAME%: %*
exit /b 0

:log_step
echo STEP  %SCRIPT_NAME%: %*
exit /b 0

:log_debug
echo DEBUG %SCRIPT_NAME%: %*
exit /b 0

:help
call :print_usage
exit /b 0

:usage
call :print_usage
exit /b 1

:print_usage
echo Usage: skill_install.cmd [-h ^| --help]
echo        skill_install.cmd ^<platform^> [skill]
echo.
echo Options:
echo   -h, --help   Show this help and exit.
echo.
echo Platforms: cursor, claudecode ^(claude, claude-code^), codex
echo Examples:
echo   skill_install.cmd cursor markdown-to-docx
echo   skill_install.cmd claude
exit /b 0