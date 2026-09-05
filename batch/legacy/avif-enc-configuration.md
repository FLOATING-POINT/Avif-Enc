## Encoder Settings

# Encoder Speed.

-s X = encoder speed.
Speed: 0=slowest/best compression, 10=fastest/worst compression. default = codecinternal default
99% of the time, lower is slower, but higher efficiency. My recommendation is 6 for speed, 3 for optimal quality. Anything lower is not very useful.

# Color Sharpness

-a color:sharpness=2

Sets how much detail retention you want vs artifacts. 0 is the default, and a bit blurry. 1 deactivates some RD optimizations regarding artifact prevention. 2 is the highest I'd go, as going higher doesn't change much of anything, but provides the most detail/bpp.

# Chroma

-a color:enable-chroma-deltaq=1
Enables chroma Q variation per SB.
Free quality increase. Not activated by default.

# Rate Distortion

-a tune=butteraugli
changes the RD(rate distortion) tune from psnr to butteraugli. You need to have a recent version of aomenc compiled with butteraugli support. Provides good detail retention and best color. A bit slower than PSNR tuning. Only works with 8b images(so no -d 10). If you want 10-bit(16-bit processing) and better detail retention(even in 8-bit) in exchange for worse color handling, consider using -a tune=ssim

# Color Deltag Mode

-a color:deltaq-mode=3
Default is objective Q variation per superblock(1), which is not optimal for intra-only psychov-visual quality. Very recently, a intra quality Q variation mode made for psycho-visual quality has been introduced, and it actuallys works well.

# Color AG Mode

-a color:aq-mode=1
is a variance based AQ mode. By default, it doesn't work very well for video, but it works well for intra-only photographic images, particularly when combined with the -a color:sharpness=2 flag.

# End Usage

-a end-usage=q
Chooses the "Quality" toggle, using quantizer modulation, with a certain quality level set by cq-level

# CQ Level

-a cq-level=XX
a certain quality level set by cq-level 0 - 63
Extra: for banding prevention without using grain synthesis, you can add in -d 10, which activates 10-bit output, and as such, 16bpc processing. It also improves efficiency nicely. Prevents the use of -a tune=butteraugli however. Combined with -d 10 and grain synthesis(-a color:enable-dnl-denoising=0 -a color:denoise-noise-level=5), it makes it a strong encoder, even in challenging scenarios.

-y X - Chroma sub sampling
-y 420: Best compression (recommended for photos)
-y 422: Good balance (use for high-quality sources)
-y 444: Maximum quality (use for images with text/graphics)
