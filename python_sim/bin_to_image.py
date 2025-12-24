#!/usr/bin/env python3
"""Convert targets.bin to an image. Format: RR GG BB 00 (4 bytes per pixel)."""

import sys
import os
from PIL import Image

def bin_to_image(filepath, width=None, height=None, output_path=None):
    """Read a binary file and convert to image (format: RR GG BB 00 per pixel)."""
    with open(filepath, 'rb') as f:
        data = f.read()
    
    # Calculate number of pixels (4 bytes per pixel)
    num_pixels = len(data) // 4
    print(f"File size: {len(data)} bytes")
    print(f"Number of pixels: {num_pixels}")
    
    # Try to determine dimensions if not provided
    if width is None or height is None:
        # Common dimension possibilities for 15360 pixels
        possibilities = [
            (128, 120), (120, 128),
            (160, 96), (96, 160),
            (192, 80), (80, 192),
            (64, 240), (240, 64),
            (256, 60), (60, 256),
        ]
        
        for w, h in possibilities:
            if w * h == num_pixels:
                width, height = w, h
                break
        
        if width is None:
            # Default guess
            import math
            width = int(math.sqrt(num_pixels))
            height = num_pixels // width
            print(f"Warning: Could not determine exact dimensions, using {width}x{height}")
    
    print(f"Image dimensions: {width}x{height}")
    
    # Create image
    img = Image.new('RGB', (width, height))
    pixels = img.load()
    
    for i in range(min(num_pixels, width * height)):
        offset = i * 4
        r = data[offset]
        g = data[offset + 1]
        b = data[offset + 2]
        # data[offset + 3] is always 0x00, ignored
        
        x = i % width
        y = i // width
        pixels[x, y] = (r, g, b)
    
    # Determine output path
    if output_path is None:
        base = os.path.splitext(filepath)[0]
        output_path = base + '.png'
    
    img.save(output_path)
    print(f"Image saved to: {output_path}")
    
    return img

if __name__ == '__main__':
    # Default path to targets.bin
    default_path = os.path.join(os.path.dirname(__file__), '..', 'src', 'targets.bin')
    
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        filepath = default_path
    
    # Optional: specify dimensions as arguments
    width = int(sys.argv[2]) if len(sys.argv) > 2 else None
    height = int(sys.argv[3]) if len(sys.argv) > 3 else None
    
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    
    bin_to_image(filepath, width, height)
