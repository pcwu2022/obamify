# Script to generate a .bin file with a repeating pattern
# Pattern: FF FF FF 00 00 00 00 00 (8 bytes)
# Total bits: 5 * 2^16 = 327680 bits
# Total bytes: 327680 / 8 = 40960 bytes


# Original pattern: FF FF FF 00 00 00 00 00 (8 bytes)
pattern = [0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00]
total_bytes = 5 * 2**16 // 8

def reorder_bytes(data):
    # Reorder every 4 bytes: [b0, b1, b2, b3] -> [b2, b3, b0, b1]
    out = bytearray()
    for i in range(0, len(data), 4):
        group = data[i:i+4]
        if len(group) < 4:
            out.extend(group)  # leave as is if not enough bytes
        else:
            out.extend([group[2], group[3], group[0], group[1]])
    return out

with open("output/pattern.bin", "wb") as f:
    repeats = total_bytes // len(pattern)
    remainder = total_bytes % len(pattern)
    full_pattern = pattern * repeats + pattern[:remainder]
    reordered = reorder_bytes(full_pattern)
    f.write(reordered)

print(f"Generated output/pattern.bin with {total_bytes} bytes (reordered for SDRAM word order).")
