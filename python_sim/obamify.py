from PIL import Image
from numpy import asarray
import random
import json
import matplotlib.pyplot as plt

N = 1000
M = 10000
W = 256
H = 256
MAX_LENGTH = 10
TARGET_LOSS_DISCOUNT = 0.8

INPUT_SOURCE = './input/vangogh.png'
INPUT_TARGETS = ['./input/fk.png']
OUTPUT_FILE = './output/obamified.png'

img_source = Image.open(INPUT_SOURCE).resize((W, H)).convert('RGB')
img_target = Image.open(INPUT_TARGETS[0]).resize((W, H)).convert('RGB')
source = asarray(img_source).copy()
target = asarray(img_target).copy()

# Compute mean and std for normalization
source_mean = source.mean(axis=(0, 1))
source_std = source.std(axis=(0, 1))
target_mean = target.mean(axis=(0, 1))
target_std = target.std(axis=(0, 1))

# Normalize source and target
source = (source - source_mean) / (source_std + 1e-8)
target = (target - target_mean) / (target_std + 1e-8)

def reconstruct(normalized_array, mean, std):
    return (normalized_array * std + mean).astype('uint8')

def loss_pixel(s, t, i, j, k, l):
    rgb_s = s[i, j]
    rgb_t = t[k, l]
    pixel_diff = rgb_s - rgb_t
    return pixel_diff[0]**2 + pixel_diff[1]**2 + pixel_diff[2]**2 

def random_swap(s, t, i, j):
    global W, H, MAX_LENGTH
    movements = [(0, 1), (1, 0), (0, -1), (-1, 0)]

    l_i = random.randint(1, MAX_LENGTH)
    l_j = random.randint(1, MAX_LENGTH)
    di, dj = movements[random.randint(0, 3)]

    k = i + di * l_i
    l = j + dj * l_j
    if k < 0 or k >= W or l < 0 or l >= H: return 0, 0, 0
    loss_old = loss_pixel(s, t, i, j, i, j) + loss_pixel(s, t, k, l, k, l) * TARGET_LOSS_DISCOUNT
    loss_new = loss_pixel(s, t, i, j, k, l) + loss_pixel(s, t, k, l, i, j) * TARGET_LOSS_DISCOUNT
    
    loss_diff = loss_new - loss_old
    if loss_diff <= 0: return di * l_i, dj * l_j, loss_diff
    return 0, 0, 0

# generate a random number in [0, max_i) using a piecewise linear CDF
def rand_cdf_6(max_i):
    i = random.randint(0, 6*max_i - 1)
    if i < max_i: return i // 4
    if i < 5*max_i: return i // 8 + max_i // 8
    return i // 4 - max_i // 2

def rand_cdf_14(max_i):
    i = random.randint(0, 14*max_i - 1)
    if i < max_i: return i // 8
    if i < 13*max_i: return i // 16 + max_i // 16
    return i // 8 - max_i * 3 // 4

# Replace saving normalized float array (which causes KeyError) with a denormalized uint8 image
obamified_image = Image.fromarray(reconstruct(source, source_mean, source_std))
obamified_image.save(OUTPUT_FILE)
losses = []
for epoch in range(N):
    sum_loss = 0
    for m in range(M):
        i = rand_cdf_6(W)
        j = rand_cdf_14(H)
        # i = random.randint(0, W - 1)
        # j = random.randint(0, W - 1)
        di, dj, loss = random_swap(source, target, i, j)
        k = i + di
        l = j + dj
        sum_loss += loss
        temp_val_ij = source[i, j].copy() 
        temp_val_kl = source[k, l].copy()
        source[i, j] = temp_val_kl
        source[k, l] = temp_val_ij
            
    obamified_image = Image.fromarray(reconstruct(source, source_mean, source_std))
    obamified_image.save(OUTPUT_FILE)

    if sum_loss == 0: break
    losses.append(sum_loss / M)
    print(f"Epoch {epoch}: loss = {sum_loss / M}")
    plt.clf()
    plt.plot(losses)
    plt.savefig("output/loss.png")