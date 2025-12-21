from PIL import Image
import matplotlib.pyplot as plt
import time
import argparse

# Configuration and constants
N = 1024
M = 1024
W = 128
H = 128
MAX_LENGTH = 8

TIME_BETWEEN_FRAMES_MS = 50  # 50 ms

parser = argparse.ArgumentParser(description='Obamify image transformation')
parser.add_argument('--input_source', type=str, default='./input/bob.png', help='Path to source image')
parser.add_argument('--input_target', type=str, default='./input/obama.png', help='Path to target image')
parser.add_argument('--output_file', type=str, default='./output/obamified_int.png', help='Path to output image')
args = parser.parse_args()

INPUT_SOURCE = args.input_source
INPUT_TARGET = args.input_target
OUTPUT_FILE = args.output_file

MOVEMENTS = [(0, 1), (1, 0), (0, -1), (-1, 0)]

""" Utility Functions """

def clamp_uint8(v):
	v = int(v)
	if v < 0: return 0
	if v > 255: return 255
	return v

""" Other Modules """

def Camera(file_path, width=W, height=H):
	# Load image, resize and return nested uint8 pixel array [x][y] -> [r,g,b]
	img = Image.open(file_path).resize((width, height)).convert('RGB')
	
    # Loss is saved in the 4th byte after RGB to save memory
	# returns nested list indexed as [x][y] -> [r,g,b,l] (all uint8 ints)
	pixels = list(img.getdata())
	nested = [[None for _ in range(height)] for _ in range(width)]
	for y in range(height):
		for x in range(width):
			r, g, b = pixels[y * width + x]
			nested[x][y] = [clamp_uint8(r), clamp_uint8(g), clamp_uint8(b), 255]

	# Preprocessing: encode into the integer "normalized" space
	encoded = [[nested[x][y] for y in range(height)] for x in range(width)]
	return encoded


class SRAM:
	def __init__(self, nested, width=W, height=H):
		self.width = width
		self.height = height
		# store a deep copy so original nested can be discarded
		self.mem = [[list(nested[x][y]) for y in range(height)] for x in range(width)]

	def getItem(self, i, j):
		return list(self.mem[i][j])

	def setItem(self, i, j, value):
		self.mem[i][j] = list(value)


class PRNG:
	def __init__(self, seed=1):
		# xorshift32 state must be non-zero
		self.state = (int(seed) & 0xFFFFFFFF) or 1

	def setseed(self, seed):
		self.state = (int(seed) & 0xFFFFFFFF) or 1

	def next(self):
		# xorshift32
		x = self.state
		x ^= (x << 13) & 0xFFFFFFFF
		x ^= (x >> 17) & 0xFFFFFFFF
		x ^= (x << 5) & 0xFFFFFFFF
		self.state = x & 0xFFFFFFFF
		return self.state

	def randint(self, low, high):
		if high < low:
			raise ValueError('high must be >= low')
		r = self.next()
		# avoid modulo bias for very small ranges by using simple mod
		return low + (r % (high - low + 1))


# global deterministic RNG instance
RNG = PRNG(1)

def VGA(output_file=OUTPUT_FILE, width=W, height=H):
	# read from global SRAM_S
	nested = [[SRAM_S.getItem(x, y) for y in range(H)] for x in range(W)]
	# Accepts nested uint8 original-style pixels and saves image to disk
	data = []
	loss_image = []
	global_loss = 0
	for y in range(height):
		for x in range(width):
			r, g, b, l = nested[x][y]
			data.append((clamp_uint8(r), clamp_uint8(g), clamp_uint8(b)))
			loss_image.append((l, l, l))
			global_loss += l
	
	print(f"Global loss: {global_loss // (width * height)}")

	img = Image.new('RGB', (width, height))
	img.putdata(data)
	img.save(output_file)
	loss_img = Image.new('RGB', (width, height))
	loss_img.putdata(loss_image)
	loss_img.save(output_file.replace('.png', '_loss.png'))
    
def loss_pixel(pixel_s, pixel_t):
	d0 = int(pixel_s[0]) - int(pixel_t[0])
	d1 = int(pixel_s[1]) - int(pixel_t[1])
	d2 = int(pixel_s[2]) - int(pixel_t[2])
	sq = (d0 * d0 + d1 * d1 + d2 * d2) // 256
	return clamp_uint8(sq)

def init_loss():
	for i in range(W):
		for j in range(H):
			pixel_s = SRAM_S.getItem(i, j)
			pixel_t = SRAM_T.getItem(i, j)
			pixel_s[3] = loss_pixel(pixel_s, pixel_t)
			SRAM_S.setItem(i, j, pixel_s)

""" Obamify Algorithm """

def obamify():
	
	# === Cycle 0 - CALC_INIT: generate random movement === #
	random_21_bits = RNG.randint(0, 2**21 - 1)
	deviation = random_21_bits % MAX_LENGTH	# select the 0-4 bits for deviation
	direction = (random_21_bits >> 5) % 4	# select the 5-6 bits for direction
	i = (random_21_bits >> 7) % W			# select the 7-13 bits for i
	j = (random_21_bits >> 14) % H			# select the 14-20 bits for j
	di, dj = MOVEMENTS[direction]
	k = i + (deviation if di != 0 else 0)
	l = j + (deviation if dj != 0 else 0)
	if k < 0 or k >= W or l < 0 or l >= H: return False, 0
	
	# === Cycle 1 - READ_SOURCE_1: read source pixel 1 === #
	pixel_s_1 = SRAM_S.getItem(i, j)
	# === Cycle 2 - READ_SOURCE_2: read source pixel 2 === #
	pixel_s_2 = SRAM_S.getItem(k, l)
	# === Cycle 3 - READ_TARGET_1: read target pixel 1 === #
	pixel_t_1 = SRAM_T.getItem(i, j)
	# === Cycle 4 - READ_TARGET_2: read target pixel 2 === #
	pixel_t_2 = SRAM_T.getItem(k, l)
	
	# === Cycle 5 - CALC_LOSS: calculate swap loss === #
	loss_old = int(pixel_s_1[3]) + int(pixel_s_2[3])
	loss_move_forward = loss_pixel(pixel_s_1, pixel_t_2)
	loss_move_reverse = loss_pixel(pixel_s_2, pixel_t_1)
	loss_new = loss_move_forward + loss_move_reverse
	
	if loss_new > loss_old: return True, loss_old
	
	# perform swap and update loss bytes
	pixel_s_1[3] = clamp_uint8(loss_move_reverse)
	pixel_s_2[3] = clamp_uint8(loss_move_forward)
	
	# swap RGB channels
	pixel_s_1[0], pixel_s_2[0] = pixel_s_2[0], pixel_s_1[0]
	pixel_s_1[1], pixel_s_2[1] = pixel_s_2[1], pixel_s_1[1]
	pixel_s_1[2], pixel_s_2[2] = pixel_s_2[2], pixel_s_1[2]
	
	# write back
	# === Cycle 6 - WRITE_SOURCE_1: write source pixel 1 === #
	SRAM_S.setItem(i, j, pixel_s_1)
	# === Cycle 7 - WRITE_SOURCE_2: write source pixel 2 === #
	SRAM_S.setItem(k, l, pixel_s_2)

	return True, clamp_uint8(loss_new)

def main(source_file=INPUT_SOURCE, target_file=INPUT_TARGET, output_file=OUTPUT_FILE):
	# Load originals via Camera
	source = Camera(source_file, W, H)
	target = Camera(target_file, W, H)

	# create SRAM wrappers
	global SRAM_S, SRAM_T
	SRAM_S = SRAM(source, W, H)
	SRAM_T = SRAM(target, W, H)

	# save loss to the 4th byte
	init_loss()
	VGA(output_file, W, H)
	time.sleep(1)
	
	for epoch in range(N):
		sum_loss = 0
		loop_start = time.perf_counter()

		for iteration in range(M):
			valid, loss = obamify()
			if valid: sum_loss += loss
		
		loop_end = time.perf_counter()
		loop_time_ms = (loop_end - loop_start) * 1_000

		VGA(output_file, W, H)

		print(f"Epoch {epoch}: loss = {sum_loss / M}, loop time = {loop_time_ms:.2f} ms")
		
		time.sleep(max(0, TIME_BETWEEN_FRAMES_MS - loop_time_ms) / 1000.0)
		
		if sum_loss == 0: break

if __name__ == '__main__':
	main()