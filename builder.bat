@echo off
for /f "tokens=2 delims=:" %%c in ('chcp') do set "localecode=%%c"
set "localecode=%localecode: =%"
chcp 65001 >nul
setlocal enabledelayedexpansion

:: Assess there is at least one argument
if "%~1"=="" (
    echo Usage: %~nx0 "filename.ext"
    if defined localecode chcp %localecode% >nul 2>&1
    endlocal
    exit /b 1
)

:: Rebuild full path from all arguments (supports unquoted spaces)
set "input=%~1"
shift
:collectArgs
if not "%~1"=="" (
    set "input=%input% %~1"
    shift
    goto collectArgs
)

:: Create temporary VBScript helper in %temp%
set "tmpvbs=%temp%\validate_filename_unicode.vbs"
> "%tmpvbs%" echo s = WScript.Arguments(0)
>> "%tmpvbs%" echo For i = 1 To Len(s)
>> "%tmpvbs%" echo   c = AscW(Mid(s, i, 1))
>> "%tmpvbs%" echo   If c ^< 32 Or c ^> 127 Then
>> "%tmpvbs%" echo     WScript.Quit 1
>> "%tmpvbs%" echo   End If
>> "%tmpvbs%" echo Next
>> "%tmpvbs%" echo WScript.Quit 0

cscript //nologo "%tmpvbs%" "%input%"
set "vbsExit=%errorlevel%"
if "%vbsExit%" NEQ "0" (
    if exist "%tmpvbs%" del "%tmpvbs%" >nul 2>&1
    if defined localecode chcp %localecode% >nul 2>&1
    echo Error: filename contains forbidden non-ASCII or invisible character.
    endlocal
    exit /b 1
)


:: Normalize path and extract name/ext
for %%F in ("%input%") do (
    set "fullpath=%%~fF"
    set "name=%%~nF"
    set "ext=%%~xF"
)

::DEBUG:: echo [DBG-CHK] fullpath=%fullpath% name=%name% ext=%ext%

if not exist "%fullpath%" (
    echo Error: File "%fullpath%" not found.
    if defined localecode chcp %localecode% >nul 2>&1
    endlocal
    exit /b 1
)

::DEBUG::  echo [DBG-CHK] file exists
if exist "%fullpath%\*" (
    echo Error: "%fullpath%" is a directory.
    if defined localecode chcp %localecode% >nul 2>&1
    endlocal
    exit /b 1
)

::DEBUG:: echo [DBG-CHK] ext=%ext%
if /i "%ext%"==".ldr" goto ext_ok
if /i "%ext%"==".dat" goto ext_ok
if /i "%ext%"==".mpd" goto ext_ok

echo Error: File must be .ldr, .dat, or .mpd (found "%ext%").
if defined localecode chcp %localecode% >nul 2>&1
endlocal
exit /b 1

:ext_ok

::DEBUG:: echo [DBG-CHK] in ext_ok

:: Extract dimension token = last token in base name
set "last="
for %%A in (%name%) do set "last=%%A"
::DEBUG:: echo [DBG-CHK] after last assignment last=!last!
if "%last%"=="" set "last=%name%"
::DEBUG:: echo [DBG-CHK] after fallback last=!last!

cscript //nologo "%tmpvbs%" "%last%"
::DEBUG:: echo [DBG-CHK] exit=%errorlevel%
set "vbsLastExit=%errorlevel%"
::DEBUG:: echo [DBG-CHK] vbsLastExit=%vbsLastExit%
if exist "%tmpvbs%" del "%tmpvbs%" >nul 2>&1
::DEBUG:: echo [DBG-CHK] after tmpvbs cleanup
::DEBUG:: echo [DBG-CHK] before vbs condition
if "%vbsLastExit%"=="0" goto vbs_check_done
if defined localecode (chcp %localecode% >nul 2>&1)
echo Error: file extension contains forbidden non-ASCII characters: "%last%"
echo Error: File must be .ldr, .dat, or .mpd (found "%ext%").
endlocal
exit /b 1

:vbs_check_done

::DEBUG:: echo [DBG-CHK] after vbs condition

:: Strict NxM parse
set "left="
set "right="
for /f "delims=xX" %%A in ("!last!") do set "left=%%A"
for /f "tokens=2 delims=xX" %%A in ("!last!") do set "right=%%A"
if "!left!"=="" goto invalid_format
if "!right!"=="" goto invalid_format

:: Success
echo Dimensions: !last!
if defined localecode chcp %localecode% >nul 2>&1
endlocal
exit /b 0

:invalid_format
echo Error: Dimensions must be in format NxM (found "!last!").
if defined localecode chcp %localecode% >nul 2>&1
endlocal
exit /b 1

