from PIL import Image
import matplotlib.pyplot as plt
import time

# Configuration and constants
N = 1024
M = 10240
W = 128
H = 128
MAX_LENGTH = 20

INPUT_SOURCE = './input/grayscale.png'
INPUT_TARGETS = ['./input/vangogh.png']
OUTPUT_FILE = './output/obamified_int.png'

# Mean is fixed to 127; std is chosen as 64 (easy bit-shift friendly)
MEAN = 128
STD = 64
_CONST_128_SQ = 128 * 128

""" Utility Functions """

def clamp_uint8(v):
	v = int(v)
	if v < 0: return 0
	if v > 255: return 255
	return v

# Integer encode/decode to map original 0..255 into a centered 0..255 "normalized" space
def encode_channel(channel):
	# channel: 0..255 -> encoded: 0..255, center at MEAN
	return clamp_uint8(((channel - MEAN) * 127) // STD + MEAN)

def decode_channel(encoded):
	# encoded: 0..255 -> approximate original 0..255
	return clamp_uint8(((encoded - MEAN) * STD + _CONST_128_SQ) // 128)

def encode_pixel(pixel):
	return [encode_channel(pixel[0]), encode_channel(pixel[1]), encode_channel(pixel[2]), pixel[3]]

def decode_pixel(pixel):
	return [decode_channel(pixel[0]), decode_channel(pixel[1]), decode_channel(pixel[2]), pixel[3]]

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
	encoded = [[encode_pixel(nested[x][y]) for y in range(height)] for x in range(width)]
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
def setseed(seed):
	RNG.setseed(seed)

def VGA(output_file=OUTPUT_FILE, width=W, height=H):
	# read from global SRAM_S
	nested = [[decode_pixel(SRAM_S.getItem(x, y)) for y in range(H)] for x in range(W)]
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
    

""" Obamify Algorithm """

def loss_pixel(i, j, k, l):
	# return small uint8 loss between SRAM_S(i,j) and SRAM_T(k,l)
	rgb_s = SRAM_S.getItem(i, j)
	rgb_t = SRAM_T.getItem(k, l)
	d0 = int(rgb_s[0]) - int(rgb_t[0])
	d1 = int(rgb_s[1]) - int(rgb_t[1])
	d2 = int(rgb_s[2]) - int(rgb_t[2])
	sq = (d0 * d0 + d1 * d1 + d2 * d2) // 256
	return clamp_uint8(sq)

def init_loss():
	for i in range(W):
		for j in range(H):
			p = SRAM_S.getItem(i, j)
			p[3] = loss_pixel(i, j, i, j)
			SRAM_S.setItem(i, j, p)

def random_swap(i, j):
	movements = [(0, 1), (1, 0), (0, -1), (-1, 0)]
	l_i = RNG.randint(1, MAX_LENGTH)
	l_j = RNG.randint(1, MAX_LENGTH)
	idx = RNG.randint(0, 3)
	di, dj = movements[idx]
	k = i + di * l_i
	l = j + dj * l_j
	if k < 0 or k >= W or l < 0 or l >= H:
		return 0, 0, 0
	# compute old loss by reading stored loss bytes
	p_i = SRAM_S.getItem(i, j)
	p_k = SRAM_S.getItem(k, l)
	loss_old = int(p_i[3]) + int(p_k[3])
	loss_move_forward = loss_pixel(i, j, k, l)
	loss_move_reverse = loss_pixel(k, l, i, j)
	loss_new = loss_move_forward + loss_move_reverse
	if loss_new <= loss_old:
		# assign losses corresponding to the colors that will end up at each position
		# after the swap: the color originally at (k,l) moves to (i,j), so
		# SRAM_S[i,j].loss should be loss_move_reverse; and vice-versa.
		p_i[3] = clamp_uint8(loss_move_reverse)
		p_k[3] = clamp_uint8(loss_move_forward)
		# swap RGB channels
		for c in range(3):
			p_i[c], p_k[c] = p_k[c], p_i[c]
		SRAM_S.setItem(i, j, p_i)
		SRAM_S.setItem(k, l, p_k)
		return di * l_i, dj * l_j, clamp_uint8(loss_new)
	return 0, 0, loss_old


def run_obamify(source_file=INPUT_SOURCE, target_file=INPUT_TARGETS[0], output_file=OUTPUT_FILE):
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
	# return
	
	for epoch in range(N):
		sum_loss = 0
		loop_start = time.perf_counter()
		for _ in range(M):
			i = RNG.randint(0, W - 1)
			j = RNG.randint(0, H - 1)
			
			di, dj, loss = random_swap(i, j)
			
			if 0 <= i + di < W and 0 <= j + dj < H:
				sum_loss += loss
		loop_end = time.perf_counter()
		loop_time_us = (loop_end - loop_start) * 1_000_000

		VGA(output_file, W, H)

		print(f"Epoch {epoch}: loss = {sum_loss / M}, loop time = {loop_time_us:.2f} µs")
		
		# time.sleep(max(0, 0.05 - loop_time_us / 1_000_000))
		if sum_loss == 0: break

if __name__ == '__main__':
	run_obamify()