from PIL import Image
from numpy import asarray
import random
import json
import matplotlib.pyplot as plt

N = 1000
M = 1000
W = 200
H = 200
MAX_LENGTH = 5

INPUT_SOURCE = './input/bob.png'
INPUT_TARGETS = ['./input/bill.png']
OUTPUT_FILE = './output/obamified.png'

img_source = Image.open(INPUT_SOURCE).resize((W, H))
img_target = Image.open(INPUT_TARGETS[0]).resize((W, H))
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
    global W, H
    rgba_s = s[i, j]
    loss = 0
    rgba_t = t[k, l]
    pixel_diff = rgba_s - rgba_t
    
    dist_sq = ((i - k)**2 + (j - l)**2)**2
    dist_pixel = pixel_diff[0]**2 + pixel_diff[1]**2 + pixel_diff[2]**2 
    
    loss += (dist_sq + dist_pixel) / ((W**2 + H**2)**2 + 3*256**2)
            
    return loss / (W * H)

def pixel_best_move(s, t, i, j):
    global W, H, MAX_LENGTH
    movements = [(0, 1), (1, 0), (0, -1), (-1, 0)]
    best_move = (0, 0)
    best_loss_diff = 0

    for l_i in range(1, MAX_LENGTH + 1):
        for l_j in range(1, MAX_LENGTH + 1):
            for di, dj in movements:
                k = i + di * l_i
                l = j + dj * l_j
                if k < 0 or k >= W or l < 0 or l >= H: continue
                loss_old = loss_pixel(s, t, i, j, k, l)
                temp_val_ij = s[i, j].copy() 
                temp_val_kl = s[k, l].copy()
                s[i, j] = temp_val_kl
                s[k, l] = temp_val_ij
                loss_new = loss_pixel(s, t, i, j, k, l)
                temp_val_ij = s[i, j].copy() 
                temp_val_kl = s[k, l].copy()
                s[i, j] = temp_val_kl
                s[k, l] = temp_val_ij
                
                loss_diff = loss_new - loss_old
                if loss_diff > best_loss_diff: 
                    best_loss_diff = loss_diff
                    best_move = (di * l_i, dj * l_j)
            
    return best_move[0], best_move[1], best_loss_diff

total_loss = 0
# Replace saving normalized float array (which causes KeyError) with a denormalized uint8 image
obamified_image = Image.fromarray(reconstruct(source, source_mean, source_std))
obamified_image.save(OUTPUT_FILE)
for epoch in range(N):
    print(f"Epoch {epoch}: loss = {total_loss}")
    sum_loss = 0

    for m in range(M):
        i = random.randint(0, W - 1)
        j = random.randint(0, H - 1)
        di, dj, loss = pixel_best_move(source, target, i, j)
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
    total_loss += sum_loss / M