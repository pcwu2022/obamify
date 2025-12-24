# Script to generate a .bin file with a repeating pattern
# Pattern: FF FF FF 00 00 00 00 00 (8 bytes)
# Total bits: 5 * 2^16 = 327680 bits
# Total bytes: 327680 / 8 = 40960 bytes


# Original pattern: FF FF FF 00 00 00 00 00
pattern = bytes([0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00])
total_bytes = 5 * 2**16 // 8

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

with open("output/pattern.bin", "wb") as f:
    repeats = total_bytes // len(pattern)
    remainder = total_bytes % len(pattern)
    full_pattern = pattern * repeats + pattern[:remainder]
    swapped_pattern = swap_word_bytes(full_pattern)
    f.write(swapped_pattern)

print(f"Generated output/pattern.bin with {total_bytes} bytes (word bytes swapped).")
