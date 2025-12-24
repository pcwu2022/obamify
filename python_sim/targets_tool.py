#!/usr/bin/env python3
"""
Unified tool for targets.bin operations:
1. Generate targets.bin from target_0..target_4 images
2. Print targets.bin in HEX format
3. Convert targets.bin back to image
4. Verify reconstruction matches original images

Format: Each pixel is 4 bytes: R, G, B, 0x00
"""

import os
import sys
import argparse
from PIL import Image
import numpy as np

# Configuration
INPUT_DIR = "input"
OUTPUT_DIR = "output"
DEFAULT_BIN_FILE = "targets.bin"
SIZE = (128, 128)
NUM_IMAGES = 5


def generate_bin(input_dir=INPUT_DIR, output_path=None):
    """Generate binary file from target_0..target_4 images."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    if output_path is None:
        output_path = os.path.join(OUTPUT_DIR, DEFAULT_BIN_FILE)

    total_bytes = 0
    with open(output_path, "wb") as f:
        for i in range(NUM_IMAGES):
            name = f"target_{i}.png"
            path = os.path.join(input_dir, name)
            if not os.path.exists(path):
                raise FileNotFoundError(f"Missing image: {path}")

            img = Image.open(path).convert("RGB")
            if img.size != SIZE:
                raise ValueError(
                    f"Image {name} is {img.size}, expected {SIZE}. Please resize first."
                )

            # Iterate pixels row-major and write R,G,B,0 per pixel
            for r, g, b in img.getdata():
                f.write(bytes((r, g, b, 0)))
                total_bytes += 4

    expected = 4 * SIZE[0] * SIZE[1] * NUM_IMAGES
    print(f"Generated: {output_path}")
    print(f"Wrote {total_bytes} bytes (expected {expected})")
    if total_bytes != expected:
        raise RuntimeError("Output size mismatch.")
    return output_path


def print_hex(filepath, output_path=None, bytes_per_line=16):
    """Print binary file contents in HEX format."""
    with open(filepath, 'rb') as f:
        data = f.read()

    hex_bytes = [f'{b:02X}' for b in data]

    if output_path is None:
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        base = os.path.basename(filepath)
        output_path = os.path.join(OUTPUT_DIR, base + '.hex.txt')

    with open(output_path, 'w') as out_f:
        for i in range(0, len(hex_bytes), bytes_per_line):
            out_f.write(' '.join(hex_bytes[i:i+bytes_per_line]) + '\n')

    print(f"File: {filepath}")
    print(f"Size: {len(data)} bytes")
    print(f"Hex output written to: {output_path}")
    return output_path


def bin_to_image(filepath, width=None, height=None, output_path=None):
    """Convert binary file to image (format: RR GG BB 00 per pixel)."""
    with open(filepath, 'rb') as f:
        data = f.read()

    num_pixels = len(data) // 4
    print(f"File size: {len(data)} bytes")
    print(f"Number of pixels: {num_pixels}")

    # For targets.bin: 5 images of 128x128 = 81920 pixels
    # Layout: 128 width, 640 height (5 images stacked vertically)
    if width is None or height is None:
        if num_pixels == SIZE[0] * SIZE[1] * NUM_IMAGES:
            width = SIZE[0]
            height = SIZE[1] * NUM_IMAGES
        else:
            # Try to find reasonable dimensions
            import math
            width = int(math.sqrt(num_pixels))
            height = num_pixels // width
            print(f"Warning: Using estimated dimensions {width}x{height}")

    print(f"Image dimensions: {width}x{height}")

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

    if output_path is None:
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        base = os.path.splitext(os.path.basename(filepath))[0]
        output_path = os.path.join(OUTPUT_DIR, base + '.png')

    img.save(output_path)
    print(f"Image saved to: {output_path}")
    return img, output_path


def create_reference_image(input_dir=INPUT_DIR):
    """Create reference image by concatenating target_0..target_4 vertically."""
    images = []
    for i in range(NUM_IMAGES):
        name = f"target_{i}.png"
        path = os.path.join(input_dir, name)
        if not os.path.exists(path):
            raise FileNotFoundError(f"Missing image: {path}")
        img = Image.open(path).convert("RGB")
        if img.size != SIZE:
            raise ValueError(f"Image {name} is {img.size}, expected {SIZE}")
        images.append(img)

    # Concatenate vertically
    total_height = SIZE[1] * NUM_IMAGES
    reference = Image.new('RGB', (SIZE[0], total_height))
    for i, img in enumerate(images):
        reference.paste(img, (0, i * SIZE[1]))

    return reference


def verify(bin_path, input_dir=INPUT_DIR):
    """Verify that reconstructed image matches original concatenated images."""
    print("=" * 60)
    print("VERIFICATION")
    print("=" * 60)

    # Create reference from original images
    print(f"Loading original images from: {input_dir}")
    reference = create_reference_image(input_dir)
    print(f"Reference image size: {reference.size}")

    # Reconstruct from binary
    print(f"Reconstructing from: {bin_path}")
    reconstructed, _ = bin_to_image(bin_path)

    # Compare
    ref_array = np.array(reference)
    rec_array = np.array(reconstructed)

    print("-" * 60)
    print("Comparison Results:")
    print(f"  Reference shape: {ref_array.shape}")
    print(f"  Reconstructed shape: {rec_array.shape}")

    if ref_array.shape != rec_array.shape:
        print("  ❌ FAILED: Shape mismatch!")
        return False

    # Pixel-by-pixel comparison
    if np.array_equal(ref_array, rec_array):
        print("  ✅ PASSED: Images are identical!")
        return True
    else:
        diff = np.abs(ref_array.astype(int) - rec_array.astype(int))
        num_diff = np.sum(diff > 0)
        max_diff = np.max(diff)
        mean_diff = np.mean(diff[diff > 0]) if num_diff > 0 else 0

        print(f"  ❌ FAILED: Images differ!")
        print(f"  Number of differing values: {num_diff}")
        print(f"  Max difference: {max_diff}")
        print(f"  Mean difference (non-zero): {mean_diff:.2f}")

        # Find first differing pixel
        for y in range(ref_array.shape[0]):
            for x in range(ref_array.shape[1]):
                if not np.array_equal(ref_array[y, x], rec_array[y, x]):
                    print(f"  First diff at ({x}, {y}): ref={ref_array[y,x]} rec={rec_array[y,x]}")
                    break
            else:
                continue
            break

        return False


def full_pipeline(input_dir=INPUT_DIR):
    """Run full pipeline: generate, convert back, verify."""
    print("=" * 60)
    print("FULL PIPELINE TEST")
    print("=" * 60)

    # Step 1: Generate binary
    print("\n[Step 1] Generating binary file...")
    bin_path = generate_bin(input_dir)

    # Step 2: Print hex (optional, just create the file)
    print("\n[Step 2] Creating hex dump...")
    print_hex(bin_path)

    # Step 3: Convert back to image
    print("\n[Step 3] Converting binary back to image...")
    reconstructed, img_path = bin_to_image(bin_path)

    # Step 4: Verify
    print("\n[Step 4] Verifying reconstruction...")
    success = verify(bin_path, input_dir)

    # Save reference for visual comparison
    reference = create_reference_image(input_dir)
    ref_path = os.path.join(OUTPUT_DIR, "reference_concatenated.png")
    reference.save(ref_path)
    print(f"\nReference image saved to: {ref_path}")

    print("\n" + "=" * 60)
    if success:
        print("✅ ALL TESTS PASSED!")
    else:
        print("❌ VERIFICATION FAILED!")
    print("=" * 60)

    return success


def main():
    parser = argparse.ArgumentParser(
        description="Unified tool for targets.bin operations",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python targets_tool.py generate              # Generate targets.bin from input images
  python targets_tool.py hex targets.bin       # Print hex dump
  python targets_tool.py image targets.bin     # Convert bin to image
  python targets_tool.py verify targets.bin    # Verify reconstruction
  python targets_tool.py pipeline              # Run full pipeline with verification
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='Command to run')

    # Generate command
    gen_parser = subparsers.add_parser('generate', help='Generate targets.bin from images')
    gen_parser.add_argument('-i', '--input-dir', default=INPUT_DIR, help='Input directory')
    gen_parser.add_argument('-o', '--output', help='Output binary file path')

    # Hex command
    hex_parser = subparsers.add_parser('hex', help='Print binary file in HEX format')
    hex_parser.add_argument('file', help='Binary file to convert')
    hex_parser.add_argument('-o', '--output', help='Output hex file path')

    # Image command
    img_parser = subparsers.add_parser('image', help='Convert binary to image')
    img_parser.add_argument('file', help='Binary file to convert')
    img_parser.add_argument('-w', '--width', type=int, help='Image width')
    img_parser.add_argument('-t', '--height', type=int, help='Image height')
    img_parser.add_argument('-o', '--output', help='Output image path')

    # Verify command
    verify_parser = subparsers.add_parser('verify', help='Verify reconstruction')
    verify_parser.add_argument('file', help='Binary file to verify')
    verify_parser.add_argument('-i', '--input-dir', default=INPUT_DIR, help='Original images directory')

    # Pipeline command
    pipe_parser = subparsers.add_parser('pipeline', help='Run full pipeline with verification')
    pipe_parser.add_argument('-i', '--input-dir', default=INPUT_DIR, help='Input directory')

    args = parser.parse_args()

    if args.command == 'generate':
        generate_bin(args.input_dir, args.output)
    elif args.command == 'hex':
        print_hex(args.file, args.output)
    elif args.command == 'image':
        bin_to_image(args.file, args.width, args.height, args.output)
    elif args.command == 'verify':
        success = verify(args.file, args.input_dir)
        sys.exit(0 if success else 1)
    elif args.command == 'pipeline':
        success = full_pipeline(args.input_dir)
        sys.exit(0 if success else 1)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
