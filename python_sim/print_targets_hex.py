#!/usr/bin/env python3
"""Print targets.bin file in HEX format (2 hex digits per byte)."""

import sys
import os

def print_hex(filepath, bytes_per_line=16):
    """Read a binary file and print its contents in HEX format."""
    with open(filepath, 'rb') as f:
        data = f.read()
    
    hex_bytes = [f'{b:02X}' for b in data]
    
    # Print with specified bytes per line to a text file
    output_path = filepath + '.hex.txt'
    with open(output_path, 'w') as out_f:
        for i in range(0, len(hex_bytes), bytes_per_line):
            out_f.write(' '.join(hex_bytes[i:i+bytes_per_line]) + '\n')
    print(f"Hex output written to: {output_path}")

if __name__ == '__main__':
    # Default path to targets.bin
    default_path = os.path.join(os.path.dirname(__file__), '..', 'src', 'targets.bin')
    
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        filepath = default_path
    
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    
    print(f"File: {filepath}")
    print(f"Size: {os.path.getsize(filepath)} bytes")
    print("-" * 50)
    print_hex(filepath)
