from PIL import Image
import random
import json
import matplotlib.pyplot as plt

# Configuration and constants
N = 1024
M = 16384
W = 256
H = 256
MAX_LENGTH = 10

INPUT_SOURCE = './input/t2.png'
INPUT_TARGETS = ['./input/fk.png']
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

def VGA(source, output_file=OUTPUT_FILE, width=W, height=H):
	nested = [[decode_pixel(source[x][y]) for y in range(H)] for x in range(W)]
	# Accepts nested uint8 original-style pixels and saves image to disk
	data = []
	loss_image = []
	total_loss = 0
	loss_is_zero_count = 0
	for y in range(height):
		for x in range(width):
			r, g, b, l = nested[x][y]
			total_loss += l
			if l == 0:
				loss_is_zero_count += 1
			data.append((clamp_uint8(r), clamp_uint8(g), clamp_uint8(b)))
			loss_image.append((l, l, l))

	img = Image.new('RGB', (width, height))
	img.putdata(data)
	img.save(output_file)
	loss_img = Image.new('RGB', (width, height))
	loss_img.putdata(loss_image)
	loss_img.save(output_file.replace('.png', '_loss.png'))
	print(f"Average loss of current obamified image: {total_loss // (width * height)}")
	print(f"Pixels with zero loss: {loss_is_zero_count} / {width * height}")
    

""" Obamify Algorithm """

def loss_pixel(s, t, i, j, k, l):
	# s,t are normalized (encoded) nested arrays; return small uint8 loss
	rgb_s = s[i][j]
	rgb_t = t[k][l]
	d0 = int(rgb_s[0]) - int(rgb_t[0])
	d1 = int(rgb_s[1]) - int(rgb_t[1])
	d2 = int(rgb_s[2]) - int(rgb_t[2])
	sq = (d0 * d0 + d1 * d1 + d2 * d2) // 256
	return clamp_uint8(sq)
	# absum = abs(d0) + abs(d1) + abs(d2)
	# return clamp_uint8(absum // 4)

def init_loss(s, t):
	for i in range(W):
		for j in range(H):
			s[i][j][3] = loss_pixel(s, t, i, j, i, j)

def random_swap(s, t, i, j):
	movements = [(0, 1), (1, 0), (0, -1), (-1, 0)]
	l_i = random.randint(1, MAX_LENGTH)
	l_j = random.randint(1, MAX_LENGTH)
	di, dj = movements[random.randint(0, 3)]
	k = i + di * l_i
	l = j + dj * l_j
	if k < 0 or k >= W or l < 0 or l >= H:
		return 0, 0, 0
	loss_old = s[i][j][3] + s[k][l][3]
	# loss_old = loss_pixel(s, t, i, j, i, j) + loss_pixel(s, t, k, l, k, l)
	loss_move_forward = loss_pixel(s, t, i, j, k, l)
	loss_move_reverse = loss_pixel(s, t, k, l, i, j)
	loss_new = loss_move_forward + loss_move_reverse
	if loss_new <= loss_old:
		s[i][j][3] = clamp_uint8(loss_move_reverse)
		s[k][l][3] = clamp_uint8(loss_move_forward)
		for c in range(3): # not swapping loss channel
			s[i][j][c], s[k][l][c] = s[k][l][c], s[i][j][c]
		return di * l_i, dj * l_j, clamp_uint8(loss_new)
	return 0, 0, loss_old

def rand_cdf_6(max_i):
	i = random.randint(0, 6 * max_i - 1)
	if i < max_i:
		return i // 4
	if i < 5 * max_i:
		return i // 8 + max_i // 8
	return i // 4 - max_i // 2

def rand_cdf_14(max_i):
	i = random.randint(0, 14 * max_i - 1)
	if i < max_i:
		return i // 8
	if i < 13 * max_i:
		return i // 16 + max_i // 16
	return i // 8 - max_i * 3 // 4

def run_obamify(source_file=INPUT_SOURCE, target_file=INPUT_TARGETS[0], output_file=OUTPUT_FILE):
	# Load originals via Camera
	source = Camera(source_file, W, H)
	target = Camera(target_file, W, H)

	# initial save
	# VGA(source, output_file, W, H)
	# VGA(source, "source_reconstructed.png", W, H)
	# VGA(target, "target_reconstructed.png", W, H)

	# save loss to the 4th byte
	init_loss(source, target)

	losses = []
	for epoch in range(N):
		sum_loss = 0
		for _ in range(M):
			# i = rand_cdf_6(W)
			# j = rand_cdf_14(H)
			i = random.randint(0, W - 1)
			j = random.randint(0, H - 1)
			
			di, dj, loss = random_swap(source, target, i, j)
			
			if 0 <= i + di < W and 0 <= j + dj < H: 
				sum_loss += loss

		VGA(source, output_file, W, H)

		if sum_loss == 0:
			break
		losses.append(abs(sum_loss) // M)
		print(f"Epoch {epoch}: loss = {sum_loss / M}")

if __name__ == '__main__':
	run_obamify()