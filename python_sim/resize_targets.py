#!/usr/bin/env python3
"""Script to resize target_0 to target_4 images to 128x128 pixels."""

from PIL import Image
import os

def resize_images():
    input_dir = "input"
    target_size = (128, 128)
    
    # Resize target_0 through target_4
    for i in range(5):
        filename = f"target_{i}.png"
        filepath = os.path.join(input_dir, filename)
        
        if os.path.exists(filepath):
            print(f"Resizing {filename}...")
            img = Image.open(filepath)
            img_resized = img.resize(target_size, Image.LANCZOS)
            img_resized.save(filepath)
            print(f"  ✓ {filename} resized to {target_size[0]}x{target_size[1]}")
        else:
            print(f"  ✗ {filename} not found")

if __name__ == "__main__":
    resize_images()
    print("\nDone!")
