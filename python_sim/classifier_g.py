import numpy as np
from PIL import Image

INPUT_SOURCE = './input/obama_2.png'
INPUT_TARGETS = ['./input/t2.png', './input/obama.png', './input/bill.png', './input/vangogh.png', './input/fk.png']

def get_lbp_image(image_array):
    """
    Computes the Local Binary Pattern (LBP) for a grayscale image.
    Hardware Note: On an FPGA/MCU, this is a 3x3 sliding window loop.
    """
    # Get dimensions
    rows, cols = image_array.shape
    
    # We slice the array to create views for the 8 neighbors
    # This is a vectorized way to do the comparison without slow Python loops
    # Center image (excluding 1-pixel border)
    center = image_array[1:-1, 1:-1]
    
    # The 8 neighbors (top-left, top, top-right, etc.)
    # We compare each neighbor to the center. 
    # (neighbor >= center) results in a boolean (0 or 1)
    
    # 7 0 1
    # 6 C 2
    # 5 4 3
    
    val0 = (image_array[:-2, 1:-1]  >= center) * 1   # Top
    val1 = (image_array[:-2, 2:]    >= center) * 2   # Top-Right
    val2 = (image_array[1:-1, 2:]   >= center) * 4   # Right
    val3 = (image_array[2:, 2:]     >= center) * 8   # Bottom-Right
    val4 = (image_array[2:, 1:-1]   >= center) * 16  # Bottom
    val5 = (image_array[2:, :-2]    >= center) * 32  # Bottom-Left
    val6 = (image_array[1:-1, :-2]  >= center) * 64  # Left
    val7 = (image_array[:-2, :-2]   >= center) * 128 # Top-Left
    
    # Sum them up to get the LBP code (0-255) for every pixel
    lbp_map = val0 + val1 + val2 + val3 + val4 + val5 + val6 + val7
    
    return lbp_map.astype(np.uint8)

def get_spatial_histogram(lbp_map, grid_x=8, grid_y=8):
    """
    Divides the LBP map into a grid and calculates a histogram for each cell.
    Concatenates them into one long feature vector.
    """
    h, w = lbp_map.shape
    # Calculate cell size
    cell_h = h // grid_y
    cell_w = w // grid_x
    
    full_histogram = []
    
    for r in range(grid_y):
        for c in range(grid_x):
            # Extract the cell
            r_start = r * cell_h
            c_start = c * cell_w
            cell = lbp_map[r_start : r_start + cell_h, c_start : c_start + cell_w]
            
            # Compute histogram for this cell (256 bins for values 0-255)
            # In hardware, this is just incrementing an array index.
            hist, _ = np.histogram(cell, bins=256, range=(0, 256))
            
            # Normalize? (Optional: helps if image brightness varies wildly)
            # For strict hardware simplicity, you can skip normalization if sizes are fixed.
            # We will skip normalization here to keep it integer-math friendly.
            
            full_histogram.extend(hist)
            
    return np.array(full_histogram, dtype=np.int32)

def calculate_similarity(hist1, hist2):
    """
    Compares two histograms using Histogram Intersection.
    Hardware Cost: strict minimum() and addition.
    Result: Higher score = Better match.
    """
    # Intersection: Sum of min(A[i], B[i])
    # This counts how many "texture features" they share in the exact same regions.
    intersection = np.minimum(hist1, hist2)
    score = np.sum(intersection)
    return score

def load_and_process(image_path_or_array):
    """
    Helper to load image, convert to grayscale, and get the feature vector.
    """
    if isinstance(image_path_or_array, str):
        # Load from file
        img = Image.open(image_path_or_array).convert('L') # Convert to Grayscale
        img = img.resize((128, 128)) # Ensure size is correct
        img_arr = np.array(img)
    else:
        # Use provided array (for dummy data)
        img_arr = image_path_or_array

    # 1. Compute LBP
    lbp_map = get_lbp_image(img_arr)
    
    # 2. Compute Spatial Histogram (4x4 grid is a good balance for hardware)
    features = get_spatial_histogram(lbp_map, grid_x=4, grid_y=4)
    
    return features

# --- MAIN EXECUTION ---
if __name__ == "__main__":
    print("--- Simulating Hardware LBP Face Matching ---")
    
    # 1. Create Dummy Data (Replace this with actual file paths like "face1.jpg")
    # We create a 'source' face and 5 'target' faces.
    # Target 2 will be a slight modification of Source to ensure it wins.
    
    np.random.seed(42)
    
    # Generate random noise image as "Source"
    # source_img = np.random.randint(0, 255, (128, 128), dtype=np.uint8)
    source_img = INPUT_SOURCE

    targets = INPUT_TARGETS
    
    # targets = []
    # # Target 0: Random noise
    # targets.append(np.random.randint(0, 255, (128, 128), dtype=np.uint8))
    
    # # Target 1: Random noise
    # targets.append(np.random.randint(0, 255, (128, 128), dtype=np.uint8))
    
    # # Target 2: THE MATCH (Source image + slight noise)
    # noise = np.random.randint(-20, 20, (128, 128), dtype=np.int16)
    # match_img = np.clip(source_img.astype(np.int16) + noise, 0, 255).astype(np.uint8)
    # targets.append(match_img)
    
    # # Target 3 & 4: Random noise
    # targets.append(np.random.randint(0, 255, (128, 128), dtype=np.uint8))
    # targets.append(np.random.randint(0, 255, (128, 128), dtype=np.uint8))

    # 2. Process Source
    print("Processing Source Image...")
    source_hist = load_and_process(source_img)

    # 3. Compare against Targets
    scores = []
    print(f"Comparing against {len(targets)} targets...\n")
    
    for i, target_img in enumerate(targets):
        target_hist = load_and_process(target_img)
        score = calculate_similarity(source_hist, target_hist)
        scores.append(score)
        print(f"Target {i}: Similarity Score = {score}")

    # 4. Decide Winner
    best_index = np.argmax(scores)
    print(f"\nWINNER: Target {best_index} is most alike to Source.")