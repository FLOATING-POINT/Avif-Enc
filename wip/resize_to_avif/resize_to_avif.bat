@echo off
setlocal enabledelayedexpansion

:: ==========================================
:: CONFIGURATION SETTINGS (ADJUST THESE)
:: Breakpoints 2026
:: <img src="image-800.avif"
::      srcset="image-384.avif 384w,
::              image-640.avif 640w,
::              image-1024.avif 1024w,
::              image-1280.avif 1280w,
::              image-1600.avif 1600w,
::              image-2048.avif 2048w"
::      sizes="(max-width: 640px) 100vw,
::             (max-width: 1024px) 50vw,
::             33vw"
::      alt="Your image">
:: ==========================================

set "extensions=.jpg .jpeg .png .webp .tiff .avif"
set "sizes=384 640 1024 1280 1600 2048"
set "out_dir=output_images"

:: ==========================================
:: ENCODER CHOICE – MUST BE SET HERE
:: ==========================================
:: Choose one: libaom-av1, libsvtav1, or librav1e
:: (If you leave this line commented or empty, the script will use libsvtav1)
set "encoder=libaom-av1"

:: ==========================================
:: QUALITY & SPEED
:: ==========================================
:: 0 – 63
:: Lower = better quality, larger file size. 0 = losless
set "quality=30"
::
:: range 0 – 8 
set "speed_preset=4"

:: ==========================================
:: SAFETY: If encoder is still empty, force a default
:: ==========================================
if "%encoder%"=="" set "encoder=libsvtav1"

:: ==========================================
:: ENGINE – DO NOT EDIT BELOW
:: ==========================================

:: Show the encoder we're using
echo Encoder selected: %encoder%
echo.

echo Working directory: %cd%
echo.
echo Press any key to start...
pause >nul

where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo ERROR: ffmpeg not found.
    pause
    exit /b 1
)

if not exist "%out_dir%" mkdir "%out_dir%"
echo Output folder: %out_dir%
echo.

:: Build encoder flags based on choice
set "enc_param=-c:v %encoder%"
set "quality_param=-crf %quality%"
set "speed_param=-cpu-used %speed_preset%"

if /i "%encoder%"=="libsvtav1" (
    set "speed_param=-preset %speed_preset%"
)
if /i "%encoder%"=="librav1e" (
    set "quality_param=-qp %quality%"
    set "speed_param=-speed %speed_preset%"
)

:: Double-check that the encoder variable is not empty
if "%encoder%"=="" (
    echo FATAL: Encoder variable is empty! Please set "encoder" in the configuration.
    pause
    exit /b 1
)

for %%f in (*) do (
    set "ext=%%~xf"
    set "matched=0"
    
    for %%e in (%extensions%) do (
        if /i "!ext!"=="%%e" (
            set "matched=1"
            echo [MATCH] %%f
            
            for %%w in (%sizes%) do (
                set "w=%%w"
                set "outfile=%out_dir%\%%~nf_!w!.avif"
                
                echo   - Encoding width !w! ...
                echo     Command: ffmpeg -y -i "%%f" -vf "scale=!w!:-1" !enc_param! !quality_param! !speed_param! -pix_fmt yuv420p10le "!outfile!"
                
                ffmpeg -y -i "%%f" -vf "scale=!w!:-1" !enc_param! !quality_param! !speed_param! -pix_fmt yuv420p10le "!outfile!"
                
                if errorlevel 1 (
                    echo     ERROR: Failed for width !w!
                ) else (
                    echo     OK: !outfile!
                )
                echo.
            )
        )
    )
    
    if "!matched!"=="0" (
        echo [SKIP] %%f (extension !ext! not in list)
    )
)

echo.
echo ==================================================
echo FINISHED. Check the "%out_dir%" folder.
echo ==================================================
pause