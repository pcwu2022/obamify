from PIL import Image

""" Utility Functions """

def clamp_uint8(v):
	v = int(v)
	if v < 0: return 0
	if v > 255: return 255
	return v

""" Other Modules """

def Camera(file_path, width, height):
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
	def __init__(self, nested, width, height):
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


def VGA(sram_s, output_file, width, height):
	# read from SRAM_S
	nested = [[sram_s.getItem(x, y) for y in range(height)] for x in range(width)]
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

def init_loss(sram_s, sram_t, width, height):
	for i in range(width):
		for j in range(height):
			pixel_s = sram_s.getItem(i, j)
			pixel_t = sram_t.getItem(i, j)
			pixel_s[3] = loss_pixel(pixel_s, pixel_t)
			sram_s.setItem(i, j, pixel_s)

# compare the source and various target images and pick the target image with the lowest loss
def select_target_image(source_file, target_files, width, height):
	print("Selecting best target image based on initial loss...")
	source = Camera(source_file, width, height)
	min_loss = None
	best_target = None
	for target_file in target_files:
		target = Camera(target_file, width, height)
		total_loss = 0
		for i in range(width):
			for j in range(height):
				pixel_s = source[i][j]
				pixel_t = target[i][j]
				total_loss += loss_pixel(pixel_s, pixel_t)
		print(f"Average loss for target {target_file}: {total_loss / (width * height):.2f}")
		if min_loss is None or total_loss < min_loss:
			min_loss = total_loss
			best_target = target_file
	print(f"Selected target image: {best_target} with loss {min_loss / (width * height):.2f}")
	return best_target