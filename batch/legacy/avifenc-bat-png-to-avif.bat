@echo off
:: ############################################################################
:: TERMINAL
mode con: cols=100 lines=9999
setlocal enabledelayedexpansion
:: ############################################################################
:: NOTE Must be used with appropriate config file avifenc-config-%EXT_IN%.bat
:: 
:: NOTE: See encoder settings - avif-enc-configuration.md
:: ############################################################################


set FORMAT=avif
set EXT_OUT=avif
set EXT_IN=png
set "DELETE_ORIG=true"

set CONFIG="avifenc-bat-%EXT_IN%-%EXT_OUT%.conf"


:: ############################################################################
:: LOG FILES - Use absolute paths to script directory
set "SCRIPT_DIR=%~dp0"
set LOGFILE_SUCCESS=log-%EXT_IN%-%EXT_OUT%-success.txt
set "LOG_S=%SCRIPT_DIR%%LOGFILE_SUCCESS%"

:: ############################################################################
:: FAILURE
set LOGFILE_FAILURE=log-%EXT_IN%-%EXT_OUT%-failure.txt
set "LOG_F=%SCRIPT_DIR%%LOGFILE_FAILURE%"

:: ############################################################################

set TOTAL_FILES=0
set SUCCESS_FILES=0
set FAILED_FILES=0
set TOTAL_ORIGINAL_SIZE=0
set TOTAL_AVIF_SIZE=0

call :LogAll "=========================================" 
call :LogAll "Current script %~n0%~x0" 
call :LogAll "Starting batch conversion at [%date% %time%]" 
call :LogAll "EXT_OUT: %EXT_OUT%" 
call :LogAll "EXT_IN: %EXT_IN%" 
call :LogAll "=========================================" 
call :LogAll ""


:: Handle PNG files
REM Change to parent directory and process from there
::cd /d "..\"
for /r %%f in (*.png) do (
    set /a TOTAL_FILES+=1
    call :LogSuccess "*******************************************" 
    call :LogSuccess "Converting %EXT_IN%: %%f" 
    call :LogSuccess "[%date% %time%] Processing %EXT_IN%: %%f" 
    call :LogSuccess "Input size: %%~zf bytes" 
    
    :: Build output filename
    set "output_file=%%~dpnf.!EXT_OUT!"
    call :LogSuccess "Output file: !output_file!" 

    :: Record start time
    set "start_time=%time%"
    call :GetTimeMs start_ms   

    if exist "%~dp0%CONFIG%" (
        call :LogSuccess "Config file found: %CONFIG%"
    ) else (
        call :LogFailure "Config file missing: %CONFIG%"
        
    )

    :: Log the batch file call
    call :LogSuccess "Calling: %CONFIG% with %%f !output_file!" 

    @REM call "%CONFIG%" "%%f" "!output_file!"
    call "%~dp0%CONFIG%" "%%f" "!output_file!"

    :: Convert using config file - FIXED: use consistent output file
    :: "%%f" "!output_file!"
     set "AVIF_EXIT_CODE=!errorlevel!"

    :: Log the exit code
     call :LogSuccess "Batch file exit code: !AVIF_EXIT_CODE!" 

    :: Record end time and calculate duration
    set "end_time=%time%"
    call :GetTimeMs end_ms
    set /a duration_ms=end_ms - start_ms
    set /a duration_sec=duration_ms / 1000
    set /a duration_ms_remainder=duration_ms %% 1000

    if exist "!output_file!" (
        for %%a in ("!output_file!") do (
            set /a TOTAL_ORIGINAL_SIZE+=%%~zf
            set /a TOTAL_AVIF_SIZE+=%%~za
            set /a REDUCTION=100-%%~za*100/%%~zf
            call :LogSuccess "Output size: %%~za bytes" 
            call :LogSuccess "Size reduction: !REDUCTION!%% Percent" 
        )
        call :LogSuccess "SUCCESS: Created !output_file!"  
        call :LogSuccess "Time taken: !duration_sec!.!duration_ms_remainder! seconds" 
        
        set /a SUCCESS_FILES+=1
        if "!DELETE_ORIG!"=="true" (
            call :LogSuccess "Deleting original file: %%f"
            del "%%f"
        )
    ) else (
        call :LogFailure "*******************************************"  
        call :LogFailure "FAILED: Could not create !output_file!" 
        call :LogFailure "AVIFenc exit code: !AVIF_EXIT_CODE!" 
        call :LogFailure "Time taken: !duration_sec!.!duration_ms_remainder! seconds" 
        call :LogFailure "*******************************************"  
        set /a FAILED_FILES+=1
    )
    
    call :LogSuccess ""
)


:: Display and log summary
call :LogSuccess ""
call :LogSuccess "========================================"  
call :LogSuccess "Conversion Summary:"  
call :LogSuccess "Total files processed: %TOTAL_FILES%"  
call :LogSuccess "Successful conversions: %SUCCESS_FILES%"  
call :LogSuccess "Failed conversions: %FAILED_FILES%"  
if !TOTAL_ORIGINAL_SIZE! gtr 0 (
    set /a TOTAL_REDUCTION=100-TOTAL_AVIF_SIZE*100/TOTAL_ORIGINAL_SIZE
    call :LogSuccess "Total size reduction: !TOTAL_REDUCTION!%% Percent"  
    call :LogSuccess "Original total size: !TOTAL_ORIGINAL_SIZE! bytes"  
    call :LogSuccess "Converted total size: !TOTAL_AVIF_SIZE! bytes"  
)

call :LogSuccess "" 
call :LogSuccess "========================================" 
call :LogSuccess "Conversion completed at [%date% %time%]" 
call :LogSuccess "Total files processed: %TOTAL_FILES%" 
call :LogSuccess "Successful conversions: %SUCCESS_FILES%" 
call :LogSuccess "Failed conversions: %FAILED_FILES%" 
if !TOTAL_ORIGINAL_SIZE! gtr 0 (
    call :LogSuccess "Total size reduction: !TOTAL_REDUCTION!%% Percent" 
    call :LogSuccess "Original total size: !TOTAL_ORIGINAL_SIZE! bytes" 
    call :LogSuccess "Converted total size: !TOTAL_AVIF_SIZE! bytes" 
)
call :LogSuccess "========================================" 

echo Log files created in script directory: %SCRIPT_DIR%
echo Success log: %LOG_S%
echo Failure log: %LOG_F%

pause
goto :eof

:: ############################################################################
:: FUNCTIONS
:: ############################################################################

:LogAll
:: Logs to console, success log, and failure log
echo %~1
echo %~1 >> "%LOG_S%"
echo %~1 >> "%LOG_F%"
goto :eof

:LogFailure
:: Logs to console, success log, and failure log
echo %~1
echo %~1 >> "%LOG_F%"
goto :eof

:LogSuccess
:: Logs to console, success log, and failure log
echo %~1
echo %~1 >> "%LOG_S%"
goto :eof

:GetTimeMs
setlocal
set /a ms=0

:: Parse time components (handle both comma and dot as decimal separator)
for /f "tokens=1-4 delims=:., " %%a in ("%time%") do (
    set /a "ms=(1%%a - 100) * 3600000 + (1%%b - 100) * 60000 + (1%%c - 100) * 1000"
    
    :: Handle hundredths of seconds (2 digits)
    set "hundredths=%%d"
    if "!hundredths:~0,1!"=="0" set "hundredths=!hundredths:~1!"
    if "!hundredths!"=="" set "hundredths=0"
    set /a "ms+=!hundredths! * 10"
)

endlocal & set "%1=%ms%"
goto :EOF