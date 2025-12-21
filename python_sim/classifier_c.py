import numpy as np
from PIL import Image

INPUT_SOURCE = './input/obama_2.png'
INPUT_TARGETS = ['./input/target_0.png', './input/target_1.png', './input/target_2.png', './input/target_3.png', './input/target_4.png']

def load_image(path):
    """Load image as uint8 numpy array (H, W, 3)."""
    img = Image.open(path).resize((128, 128)).convert("RGB")
    return np.asarray(img, dtype=np.uint8)

def sad_rgb(img1, img2):
    """
    Compute SAD between two RGB images.
    img1, img2: uint8 arrays of shape (128, 128, 3)
    """
    diff = np.abs(img1.astype(np.int16) - img2.astype(np.int16))
    return np.sum(diff)

# ---- Example usage ----
source = load_image(INPUT_SOURCE)

targets = [load_image(path) for path in INPUT_TARGETS]

sad_scores = [sad_rgb(source, t) for t in targets]

best_index = np.argmin(sad_scores)

print("SAD scores:", sad_scores)
print("Most similar target index:", best_index)
