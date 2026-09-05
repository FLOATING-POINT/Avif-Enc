@echo off
setlocal enabledelayedexpansion

:: ==========================================
:: CONFIGURATION SETTINGS (ADJUST THESE)
:: ==========================================

:: 1. Define image file extensions to process (space-separated, lowercase)
set "extensions=.jpg .jpeg .png .webp .tiff"

:: 2. Define target widths in pixels (space-separated array)
:: Aspect ratios are automatically maintained based on these widths
set "sizes=300 800 1200 1920"

:: 3. Define the directory name where new files will be saved
set "out_dir=output_images"

:: 4. Compression Quality (CRF: Constant Rate Factor)
:: Lower number = Higher Quality / Bigger Files (Range: 0-63)
:: 20 = High quality/Archival, 26 = Balanced web sweet-spot, 34 = Heavy compression
set "quality=26"

:: 5. Encoder Speed / CPU Usage Preset
:: Lower number = Better compression but SLOW. Higher number = FASTER processing but larger files.
:: 4 = Great compression balance, 6 = Standard/Fast, 8 = Real-time rapid encoding
set "speed_preset=4"


:: ==========================================
:: AUTOMATED PROCESSING ENGINE (DO NOT EDIT)
:: ==========================================

if not exist "%out_dir%" mkdir "%out_dir%"

for %%f in (*) do (
    set "ext=%%~xf"
    
    for %%e in (%extensions%) do (
        if /i "!ext!"=="%%e" (
            for %%w in (%sizes%) do (
                echo.
                echo --------------------------------------------------
                echo Processing: %%f --^> Width: %%w px
                echo --------------------------------------------------
                
                :: FFmpeg Settings Breakdown:
                :: -vf "scale=%%w:-1"          -> Scales width to variable, calculates height proportionally (-1)
                :: -c:v libaom-av1             -> Employs the industry-standard high-quality AV1 encoder
                :: -crf %quality%              -> Applies your chosen quality setting
                :: -cpu-used %speed_preset%    -> Applies your chosen speed/efficiency preset
                :: -pix_fmt yuv420p10le        -> Forces 10-bit color to eliminate sky/gradient color banding
                :: -still_picture 1            -> Instructs FFmpeg to optimize container tags for static images (not video)
                
                ffmpeg -y -i "%%f" -vf "scale=%%w:-1" -c:v libaom-av1 -crf %quality% -cpu-used %speed_preset% -pix_fmt yuv420p10le -still_picture 1 "%out_dir%\%%~nf_%%w.avif"
            )
        )
    )
)

echo.
echo ==================================================
echo SUCCESS: All images have been converted to AVIF!
echo ==================================================
pause
