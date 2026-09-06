## Avif-Enc

A utility library for converting image files to modern image formats 2025 for the web.

# (.jpg, .jpeg, .png) -> .avif

Converts jpg, jpeg and png formats to avif using avifenc with full control over avif enc parameters.

## Example usage

# Linux

# Help
avif-enc.sh --help

# Dry-run PNG
avif-enc.sh --fi png -n

# Dry-run JPG
avif-enc.sh --fi jpg -n

# Real conversion with custom quality and processing speed
avif-enc.sh --fi png -q 90 -s 5

# Using a config file
avif-enc.sh --fi jpg -c avifenc-bat-jpg-avif.conf

# Windows (not tested)

# Help
avif-enc-batch.bat --help

# Dry-run PNG
avif-enc-batch.bat --fi png -n

# Dry-run JPG
avif-enc-batch.bat --fi jpg -n

# Real conversion with custom quality
avif-enc-batch.bat --fi png -q 90 -s 5

# Using a config file
avif-enc-batch.bat --fi jpg -c avifenc-bat-jpg-avif.conf


