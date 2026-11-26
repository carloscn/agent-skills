@echo off
setlocal EnableDelayedExpansion

REM Usage: skill_uninstall.cmd <platform> [skill]
REM   platform: cursor | claudecode | codex  (aliases: claude, claude-code)
REM   skill:    omitted or "all" uninstalls every skill from this repo under that platform

set "SCRIPT_NAME=skill_uninstall.cmd"
set "PLATFORM=%~1"
set "SKILL=%~2"
set "REPO_ROOT=%~dp0"
if "%REPO_ROOT:~-1%"=="\" set "REPO_ROOT=%REPO_ROOT:~0,-1%"
set "FORCE=%SKILL_UNINSTALL_FORCE%"

if /I "%PLATFORM%"=="-h" goto :help
if /I "%PLATFORM%"=="--help" goto :help
if "%PLATFORM%"=="" goto :usage

call :log_info "starting %SCRIPT_NAME% REPO_ROOT=%REPO_ROOT%"
call :log_info "PLATFORM arg=%PLATFORM% SKILL arg=%SKILL%"
if /I "%FORCE%"=="1" call :log_warn "SKILL_UNINSTALL_FORCE=1 (remove even if origin unclear)"

call :normalize_platform "%PLATFORM%"
if errorlevel 1 exit /b 1
set "PLATFORM=!NORM_PLATFORM!"
call :log_info "normalized platform=!PLATFORM!"

call :dest_root "!PLATFORM!"
set "DEST_ROOT=!SKILLS_ROOT!"
call :log_info "primary skills root=!DEST_ROOT!"

set "STAT_REMOVED=0"
set "STAT_ABSENT=0"
set "STAT_SKIPPED=0"
set "STAT_FAILED=0"

if "%SKILL%"=="" goto :uninstall_all
if /I "%SKILL%"=="all" goto :uninstall_all
if "%SKILL%"=="-" goto :uninstall_all
if "%SKILL%"=="*" goto :uninstall_all
goto :uninstall_one

:uninstall_all
call :log_step "mode: uninstall all skills from repository"
for /d %%D in ("%REPO_ROOT%\*") do (
  if exist "%%D\SKILL.md" (
    call :uninstall_skill "%%~nxD"
  )
)
goto :summary

:uninstall_one
call :log_step "mode: uninstall single skill %SKILL%"
call :uninstall_skill "%SKILL%"
goto :summary

:uninstall_skill
set "SKILL_NAME=%~1"
set "DEST=%DEST_ROOT%\%SKILL_NAME%"

call :log_info "----- uninstall skill=!SKILL_NAME! platform=!PLATFORM! -----"
if exist "%REPO_ROOT%\%SKILL_NAME%\SKILL.md" (
  call :log_debug "repo skill verified: %REPO_ROOT%\%SKILL_NAME%\SKILL.md"
) else (
  call :log_warn "skill not in repo (no %REPO_ROOT%\%SKILL_NAME%\SKILL.md); still trying platform path"
)

call :log_info "primary destination=%DEST%"
set "UCODE=0"
call :remove_path "%DEST%" "%SKILL_NAME%"
set "UCODE=!ERRORLEVEL!"

if /I "!PLATFORM!"=="codex" (
  set "LEGACY=%USERPROFILE%\.codex\skills\%SKILL_NAME%"
  call :log_info "legacy codex destination=!LEGACY!"
  call :remove_path "!LEGACY!" "%SKILL_NAME%"
  call :prune_empty "%USERPROFILE%\.codex\skills"
)

if "!UCODE!"=="0" (
  set /a STAT_REMOVED+=1
  call :log_ok "uninstall completed for !SKILL_NAME!"
) else if "!UCODE!"=="2" (
  set /a STAT_ABSENT+=1
  call :log_info "skill !SKILL_NAME! was not present (no-op)"
) else if "!UCODE!"=="3" (
  set /a STAT_SKIPPED+=1
  call :log_warn "uninstall skipped for !SKILL_NAME! (safety)"
) else (
  set /a STAT_FAILED+=1
  call :log_error "uninstall failed for !SKILL_NAME! (code=!UCODE!)"
)
exit /b 0

:remove_path
set "TARGET=%~1"
set "SNAME=%~2"

if not exist "%TARGET%" (
  call :log_info "nothing to remove at %TARGET%"
  exit /b 2
)

dir "%TARGET%" 2>nul | findstr /N "^" >nul
call :log_info "found entry: %TARGET%"
dir /a "%TARGET%" 2>nul

if /I not "%FORCE%"=="1" (
  if exist "%REPO_ROOT%\%SNAME%\SKILL.md" (
    fc /b "%REPO_ROOT%\%SNAME%\SKILL.md" "%TARGET%\SKILL.md" >nul 2>&1
    if errorlevel 1 (
      call :log_warn "SKILL.md at destination differs from repo; skipping %TARGET%"
      call :log_warn "set SKILL_UNINSTALL_FORCE=1 to delete anyway"
      exit /b 3
    )
    call :log_debug "SKILL.md matches repo (copy install)"
  )
)

call :log_step "removing %TARGET%"
rmdir "%TARGET%" 2>nul
if not exist "%TARGET%" (
  call :log_ok "removed junction or empty dir %TARGET%"
  exit /b 0
)
rd /s /q "%TARGET%" 2>nul
if not exist "%TARGET%" (
  call :log_ok "removed directory tree %TARGET%"
  exit /b 0
)
del /f /q "%TARGET%" 2>nul
if not exist "%TARGET%" (
  call :log_ok "removed file %TARGET%"
  exit /b 0
)

call :log_error "could not remove %TARGET%"
exit /b 1

:prune_empty
set "DIR=%~1"
if not exist "%DIR%" exit /b 0
dir /b "%DIR%" 2>nul | findstr "^" >nul
if errorlevel 1 (
  call :log_step "remove empty directory %DIR%"
  rmdir "%DIR%" 2>nul
  if not exist "%DIR%" call :log_ok "removed empty %DIR%"
)
exit /b 0

:normalize_platform
set "NORM_PLATFORM="
set "P=%~1"
if /I "%P%"=="cursor" set "NORM_PLATFORM=cursor" & exit /b 0
if /I "%P%"=="claude" set "NORM_PLATFORM=claudecode" & exit /b 0
if /I "%P%"=="claudecode" set "NORM_PLATFORM=claudecode" & exit /b 0
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

:summary
call :log_info "===== summary ====="
call :log_info "platform=!PLATFORM! removed=!STAT_REMOVED! absent=!STAT_ABSENT! skipped=!STAT_SKIPPED! failed=!STAT_FAILED!"
if !STAT_FAILED! gtr 0 exit /b 1
if !STAT_SKIPPED! gtr 0 exit /b 2
exit /b 0

:help
call :print_usage
exit /b 0

:usage
call :print_usage
exit /b 1

:print_usage
echo Usage: skill_uninstall.cmd [-h ^| --help]
echo        skill_uninstall.cmd ^<platform^> [skill]
echo.
echo Options:
echo   -h, --help   Show this help and exit.
echo.
echo Platforms: cursor, claudecode ^(claude, claude-code^), codex
echo Environment: SKILL_UNINSTALL_FORCE=1 to remove without origin checks
echo Examples:
echo   skill_uninstall.cmd cursor markdown-to-docx
echo   skill_uninstall.cmd claude
exit /b 0