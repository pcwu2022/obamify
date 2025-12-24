#!/usr/bin/env python3
"""
Generate a binary file from target_0..target_4 images.
Output size: 4 * 128 * 128 * 5 bytes
Each pixel written as 4 bytes: R, G, B, 0 (placeholder)
"""

import os
from PIL import Image

INPUT_DIR = "input"
OUTPUT_DIR = "output"
OUTPUT_FILE = "targets.bin"
SIZE = (128, 128)
NUM_IMAGES = 5


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, OUTPUT_FILE)

    total_bytes = 0

    def swap_word_bytes(data):
        # Swap every 2 bytes (16-bit word)
        swapped = bytearray()
        for i in range(0, len(data), 2):
            if i+1 < len(data):
                swapped.append(data[i+1])
                swapped.append(data[i])
            else:
                swapped.append(data[i])
        return bytes(swapped)

    with open(out_path, "wb") as f:
        for i in range(NUM_IMAGES):
            name = f"target_{i}.png"
            path = os.path.join(INPUT_DIR, name)
            if not os.path.exists(path):
                raise FileNotFoundError(f"Missing image: {path}")

            img = Image.open(path).convert("RGB")
            if img.size != SIZE:
                raise ValueError(
                    f"Image {name} is {img.size}, expected {SIZE}. Please resize first."
                )

            # Collect pixel data for this image
            pixel_bytes = bytearray()
            for r, g, b in img.getdata():
                pixel_bytes.extend((r, g, b, 0))
            # Swap every 2 bytes (16-bit word)
            swapped = swap_word_bytes(pixel_bytes)
            f.write(swapped)
            total_bytes += len(swapped)

    expected = 4 * SIZE[0] * SIZE[1] * NUM_IMAGES
    print(f"Wrote {total_bytes} bytes to {out_path} (expected {expected}).")
    if total_bytes != expected:
        raise RuntimeError("Output size mismatch.")


if __name__ == "__main__":
    main()
