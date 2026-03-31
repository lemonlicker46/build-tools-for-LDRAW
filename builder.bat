@echo off
for /f "tokens=2 delims=:" %%c in ('chcp') do set "localecode=%%c"
set "localecode=%localecode: =%"
chcp 65001 >nul
setlocal enabledelayedexpansion

:: Check for input
if "%~1"=="" (
    echo Usage: %~nx0 "filename.ext"
    if defined localecode chcp %localecode% >nul 2>&1
    endlocal
    exit /b 1
)

:: Rebuild full path
set "input=%~1"
shift
:collectArgs
if not "%~1"=="" (
    set "input=%input% %~1"
    shift
    goto collectArgs
)

:: Normalize path
for %%F in ("%input%") do (
    set "fullpath=%%~fF"
    set "name=%%~nF"
    set "ext=%%~xF"
)

:: File checks
if not exist "%fullpath%" (
    echo Error: File "%fullpath%" not found.
    if defined localecode chcp %localecode% >nul 2>&1
    endlocal
    exit /b 1
)

if exist "%fullpath%\*" (
    echo Error: "%fullpath%" is a directory.
    if defined localecode chcp %localecode% >nul 2>&1
    endlocal
    exit /b 1
)

:: Extension check
if /i "%ext%"==".ldr" goto ext_ok
if /i "%ext%"==".dat" goto ext_ok
if /i "%ext%"==".mpd" goto ext_ok

echo Error: File must be .ldr, .dat, or .mpd (found "%ext%").
if defined localecode chcp %localecode% >nul 2>&1
endlocal
exit /b 1

:ext_ok

:: Extract last token (dimensions)
set "last="
for %%A in (%name%) do set "last=%%A"
if "%last%"=="" set "last=%name%"

:: Create temp VBScript
set "tmpvbs=%temp%\dim_to_ldu.vbs"

> "%tmpvbs%" echo dim input : input = WScript.Arguments(0)
>> "%tmpvbs%" echo input = Replace(input, "X", "x")
>> "%tmpvbs%" echo parts = Split(input, "x")
>> "%tmpvbs%" echo If UBound(parts) ^< 1 Then
>> "%tmpvbs%" echo   WScript.Quit 1
>> "%tmpvbs%" echo End If

>> "%tmpvbs%" echo Function ToLDU(val)
>> "%tmpvbs%" echo   val = Trim(val)
>> "%tmpvbs%" echo   If val = "" Then ToLDU = "_" : Exit Function
>> "%tmpvbs%" echo   unit = UCase(Right(val,1))
>> "%tmpvbs%" echo   num = val
>> "%tmpvbs%" echo   If unit = "L" Or unit = "P" Or unit = "S" Or unit = "B" Then
>> "%tmpvbs%" echo     num = Left(val, Len(val)-1)
>> "%tmpvbs%" echo   Else
>> "%tmpvbs%" echo     unit = "L"
>> "%tmpvbs%" echo   End If
>> "%tmpvbs%" echo   If Not IsNumeric(num) Then ToLDU = "?" : Exit Function
>> "%tmpvbs%" echo   num = CDbl(num)
>> "%tmpvbs%" echo   Select Case unit
>> "%tmpvbs%" echo     Case "L": factor = 20
>> "%tmpvbs%" echo     Case "P": factor = 8
>> "%tmpvbs%" echo     Case "S": factor = 16
>> "%tmpvbs%" echo     Case "B": factor = 24
>> "%tmpvbs%" echo   End Select
>> "%tmpvbs%" echo   ToLDU = num * factor
>> "%tmpvbs%" echo End Function

>> "%tmpvbs%" echo d1 = ToLDU(parts(0))
>> "%tmpvbs%" echo d2 = ToLDU(parts(1))
>> "%tmpvbs%" echo If UBound(parts) ^>= 2 Then
>> "%tmpvbs%" echo   d3 = ToLDU(parts(2))
>> "%tmpvbs%" echo Else
>> "%tmpvbs%" echo   d3 = "_"
>> "%tmpvbs%" echo End If

>> "%tmpvbs%" echo Function fmt(v)
>> "%tmpvbs%" echo   If v = "_" Then
>> "%tmpvbs%" echo     fmt = "_LDU"
>> "%tmpvbs%" echo   ElseIf v = "?" Then
>> "%tmpvbs%" echo     fmt = "?LDU"
>> "%tmpvbs%" echo   Else
>> "%tmpvbs%" echo     fmt = v ^& "LDU"
>> "%tmpvbs%" echo   End If
>> "%tmpvbs%" echo End Function

>> "%tmpvbs%" echo WScript.Echo fmt(d1) ^& "x" ^& fmt(d2) ^& "x" ^& fmt(d3)
>> "%tmpvbs%" echo WScript.Quit 0

:: Run VBScript
for /f "delims=" %%D in ('cscript //nologo "%tmpvbs%" "!last!"') do set "ldu=%%D"

if exist "%tmpvbs%" del "%tmpvbs%" >nul 2>&1

:: Align output
set "left=Dimensions: !last!"
set "pad=                                        "
set "left=!left!!pad!"
set "left=!left:~0,40!"

echo !left!!ldu!

if defined localecode chcp %localecode% >nul 2>&1
endlocal
exit /b 0