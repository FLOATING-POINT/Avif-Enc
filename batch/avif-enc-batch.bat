@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: avifenc-batch.bat
:: Unified PNG/JPG → AVIF batch converter for Windows
:: ============================================================

:: ===== Defaults =====
set "FORMAT_IN="
set "FORMAT_OUT=avif"
set "DELETE_ORIG=false"
set "DRY_RUN=false"
set "QUALITY=92"
set "SPEED=4"
set "CHROMA="
set "SEARCH_DIR=."
set "PAUSE_EVERY=10"
set "CONFIG_FILE="
set "SCRIPT_DIR=%~dp0"

:: Counters
set /a TOTAL_FILES=0
set /a SUCCESS_FILES=0
set /a FAILED_FILES=0
set /a TOTAL_ORIGINAL_SIZE=0
set /a TOTAL_OUTPUT_SIZE=0

:: ===== Parse arguments =====
:parse_args
if "%~1"=="" goto args_done

if /i "%~1"=="--format-in"  (set "FORMAT_IN=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--fi"         (set "FORMAT_IN=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--format-out" (set "FORMAT_OUT=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--fo"         (set "FORMAT_OUT=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--config"     (set "CONFIG_FILE=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-c"           (set "CONFIG_FILE=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--dry-run"    (set "DRY_RUN=true" & shift & goto parse_args)
if /i "%~1"=="-n"           (set "DRY_RUN=true" & shift & goto parse_args)
if /i "%~1"=="--delete-orig"(set "DELETE_ORIG=true" & shift & goto parse_args)
if /i "%~1"=="-d"           (set "DELETE_ORIG=true" & shift & goto parse_args)
if /i "%~1"=="--quality"    (set "QUALITY=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-q"           (set "QUALITY=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--speed"      (set "SPEED=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-s"           (set "SPEED=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--chroma"     (set "CHROMA=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-y"           (set "CHROMA=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--dir"        (set "SEARCH_DIR=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--pause-every"(set "PAUSE_EVERY=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--help"       goto show_help
if /i "%~1"=="-h"           goto show_help

echo Unknown option: %~1
echo Use --help for usage.
exit /b 1

:args_done

:: ===== Validation =====
if "!FORMAT_IN!"=="" (
    echo Error: --format-in / --fi is required ^(png, jpg or jpeg^)
    exit /b 1
)

set "FORMAT_IN=!FORMAT_IN!"
if /i not "!FORMAT_IN!"=="png" if /i not "!FORMAT_IN!"=="jpg" if /i not "!FORMAT_IN!"=="jpeg" (
    echo Error: unsupported input format '!FORMAT_IN!'. Use png, jpg or jpeg.
    exit /b 1
)

if /i not "!FORMAT_OUT!"=="avif" (
    echo Error: only 'avif' is currently supported as output format.
    exit /b 1
)

:: Config file validation
if not "!CONFIG_FILE!"=="" (
    if not exist "!CONFIG_FILE!" (
        echo Error: config file does not exist: !CONFIG_FILE!
        exit /b 1
    )
)

:: Auto chroma
if "!CHROMA!"=="" if "!CONFIG_FILE!"=="" (
    if /i "!FORMAT_IN!"=="png" (set "CHROMA=444") else (set "CHROMA=420")
)

if not "!CHROMA!"=="" (
    if not "!CHROMA!"=="420" if not "!CHROMA!"=="422" if not "!CHROMA!"=="444" (
        echo Error: --chroma must be 420, 422 or 444
        exit /b 1
    )
)

:: ===== Logging setup =====
set "LOG_S=!SCRIPT_DIR!log-!FORMAT_IN!-!FORMAT_OUT!-success.txt"
set "LOG_F=!SCRIPT_DIR!log-!FORMAT_IN!-!FORMAT_OUT!-failure.txt"

call :LogAll "========================================="
call :LogAll "avifenc-batch.bat"
call :LogAll "Started at [%date% %time%]"
call :LogAll "Input format   : !FORMAT_IN!"
call :LogAll "Output format  : !FORMAT_OUT!"
if not "!CONFIG_FILE!"=="" (
    call :LogAll "Config file    : !CONFIG_FILE!"
) else (
    call :LogAll "Quality        : !QUALITY!"
    call :LogAll "Speed          : !SPEED!"
    call :LogAll "Chroma         : !CHROMA!"
)
call :LogAll "Delete original: !DELETE_ORIG!"
call :LogAll "Search dir     : !SEARCH_DIR!"
call :LogAll "Dry-run        : !DRY_RUN!"
call :LogAll "========================================="
call :LogAll ""

:: ===== Find files =====
pushd "!SEARCH_DIR!" 2>nul || (
    echo Error: cannot access directory !SEARCH_DIR!
    exit /b 1
)

if /i "!FORMAT_IN!"=="jpg" (
    set "MASK=*.jpg"
) else if /i "!FORMAT_IN!"=="jpeg" (
    set "MASK=*.jpeg"
) else (
    set "MASK=*.!FORMAT_IN!"
)

for /r %%f in (!MASK!) do (
    set /a TOTAL_FILES+=1
    call :ProcessFile "%%f"
)

:: Also match .jpeg when user asked for jpg
if /i "!FORMAT_IN!"=="jpg" (
    for /r %%f in (*.jpeg) do (
        set /a TOTAL_FILES+=1
        call :ProcessFile "%%f"
    )
)

popd

if !TOTAL_FILES! equ 0 (
    call :LogAll "No matching files found."
    goto summary
)

goto summary

:: ============================================================
:ProcessFile
set "input_file=%~1"
set "input_size=%~z1"

call :LogSuccess "*******************************************"
call :LogSuccess "[!TOTAL_FILES!] !input_file!"
call :LogSuccess "Input size: !input_size! bytes"

:: Build output path (same dir, change extension)
set "output_file=%~dpn1.!FORMAT_OUT!"
call :LogSuccess "Output file: !output_file!"

if /i "!DRY_RUN!"=="true" (
    if not "!CONFIG_FILE!"=="" (
        call :LogSuccess ">>> DRY-RUN: would call config !CONFIG_FILE!"
    ) else (
        call :LogSuccess ">>> DRY-RUN: quality=!QUALITY! speed=!SPEED! chroma=!CHROMA!"
    )
    set /a SUCCESS_FILES+=1
    goto :eof
)

:: Real conversion
call :GetTimeMs start_ms

if not "!CONFIG_FILE!"=="" (
    call "!CONFIG_FILE!" "!input_file!" "!output_file!"
) else (
    avifenc --ignore-xmp --ignore-exif --ignore-profile --ignore-icc ^
        -q !QUALITY! -s !SPEED! -y !CHROMA! ^
        -a end-usage=q -a cq-level=36 -a tune=ssim ^
        -a color:sharpness=1 -a color:enable-chroma-deltaq=1 ^
        -a color:enable-qm=1 -a color:deltaq-mode=3 ^
        "!input_file!" "!output_file!"
)
set "EXIT_CODE=!errorlevel!"

call :GetTimeMs end_ms
set /a duration_ms=end_ms - start_ms
if !duration_ms! lss 0 set /a duration_ms=0
set /a duration_sec=duration_ms / 1000
set /a duration_ms_rem=duration_ms %% 1000

if exist "!output_file!" (
    for %%a in ("!output_file!") do (
        set /a TOTAL_ORIGINAL_SIZE+=!input_size!
        set /a TOTAL_OUTPUT_SIZE+=%%~za
        set /a REDUCTION=100 - %%~za * 100 / !input_size!
        call :LogSuccess "Output size: %%~za bytes"
        call :LogSuccess "Size reduction: !REDUCTION!%%"
    )
    call :LogSuccess "SUCCESS: Created !output_file!"
    call :LogSuccess "Time taken: !duration_sec!.!duration_ms_rem! seconds"
    set /a SUCCESS_FILES+=1

    if /i "!DELETE_ORIG!"=="true" (
        call :LogSuccess "Deleting original: !input_file!"
        del "!input_file!"
    )
) else (
    call :LogFailure "FAILED: Could not create !output_file!"
    call :LogFailure "Exit code: !EXIT_CODE!"
    set /a FAILED_FILES+=1
)

call :LogSuccess ""
goto :eof

:: ============================================================
:summary
call :LogSuccess "========================================="
if /i "!DRY_RUN!"=="true" (
    call :LogSuccess "DRY-RUN Summary"
) else (
    call :LogSuccess "Conversion Summary"
)
call :LogSuccess "Processed : !TOTAL_FILES!"
call :LogSuccess "Successful: !SUCCESS_FILES!"
call :LogSuccess "Failed    : !FAILED_FILES!"

if !TOTAL_ORIGINAL_SIZE! gtr 0 (
    set /a TOTAL_REDUCTION=100 - TOTAL_OUTPUT_SIZE * 100 / TOTAL_ORIGINAL_SIZE
    call :LogSuccess "Size reduction: !TOTAL_REDUCTION!%%"
    call :LogSuccess "Original total: !TOTAL_ORIGINAL_SIZE! bytes"
    call :LogSuccess "Output total  : !TOTAL_OUTPUT_SIZE! bytes"
)
call :LogSuccess "Finished at [%date% %time%]"
call :LogSuccess "========================================="

echo.
echo Log files:
echo   Success: !LOG_S!
echo   Failure: !LOG_F!
echo.
pause
exit /b 0

:: ============================================================
:show_help
echo.
echo Usage: avifenc-batch.bat [OPTIONS]
echo.
echo Required:
echo   --format-in, --fi FORMAT     Input format: png ^| jpg ^| jpeg
echo.
echo Optional:
echo   --format-out, --fo FORMAT    Output format (only avif)          [avif]
echo   --config, -c FILE            Custom config script
echo   --dry-run, -n                Simulate only
echo   --delete-orig, -d            Delete originals after success
echo   --quality, -q N              Quality 0-100                      [92]
echo   --speed, -s N                Speed 0-10                         [4]
echo   --chroma, -y MODE            420 ^| 422 ^| 444                    [auto]
echo   --dir DIR                    Directory to process               [.]
echo   --pause-every N              (not fully implemented in bat)
echo   --help, -h                   Show this help
echo.
echo Examples:
echo   avifenc-batch.bat --fi png -n
echo   avifenc-batch.bat --fi jpg -q 85 -s 6 -d
echo   avifenc-batch.bat --fi png --config myconfig.bat
echo.
exit /b 0

:: ============================================================
:LogAll
echo %~1
echo %~1>>"!LOG_S!"
echo %~1>>"!LOG_F!"
goto :eof

:LogSuccess
echo %~1
echo %~1>>"!LOG_S!"
goto :eof

:LogFailure
echo %~1
echo %~1>>"!LOG_F!"
goto :eof

:GetTimeMs
:: Simple centisecond-based timer (good enough for batch)
set "t=%time%"
set "t=!t::=!"
set "t=!t:.=!"
set "t=!t: =0!"
set /a "%1=!t!"
goto :eof