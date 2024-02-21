import argparse
import os, sys
import cv2
import json
import numpy as np
import time


def morph_open(image, crop=False, crop_size=400):
    # convert to grayscale
    if image.ndim == 3 and image.shape[2] == 3:  # Check if image has 3 dimensions and 3 channels (BGR)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    else:
        gray = image  # No need for conversion, already grayscale

    if crop:
        # Crop image center to crop size, by default 400x400 pixels
        # find center of the image
        center_x, center_y = gray.shape[1]//2, gray.shape[0]//2
        # crop image
        half_crop_size = crop_size//2
        gray = gray[center_y-half_crop_size:center_y+half_crop_size, center_x-half_crop_size:center_x+half_crop_size]
        
    # Apply an inverse binary threshold to the cropped image, with a threshold value of 9
    _, binary = cv2.threshold(gray, 9, 255, cv2.THRESH_BINARY_INV)

    # Apply morphological opening to the thresholded image with anchor 5,5  1 iteration, shape rectangle 10,10
    kernel = np.ones((10,10),np.uint8)
    opening = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel, iterations=1)

    return gray, opening

def find_contours(opening):
    # Find contours in the opened image with method CHAIN_APPROX_NONE, mode external, offset 0,0
    contours, _ = cv2.findContours(opening, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)

    return contours

def get_side_brightness(wpImage, contour=None):

    # If contour is provided, crop image to rectangle defined by contour extreme points
    if contour is not None:
        extrema = contour[:, 0, :]
        wpImage = wpImage[extrema[:, 1].min():extrema[:, 1].max(), extrema[:, 0].min():extrema[:, 0].max()]

    # Find brightness for each side
    top_brightness=np.sum(wpImage[0, :])
    bottom_brightness=np.sum(wpImage[-1, :])
    left_brightness=np.sum(wpImage[:, 0])
    right_brightness=np.sum(wpImage[:, -1])

    sideBrightness = {
        'top': top_brightness,
        'bottom': bottom_brightness,
        'left': left_brightness,
        'right': right_brightness
    }

    # Identify the side with the highest brightness (remember that the image is thresholded with an inverse binary threshold)
    sideBrightness['maxSide']=max(sideBrightness, key=sideBrightness.get) 

    # Add side brightness ratio
    sideBrightness['top_bottom_ratio'] = top_brightness / bottom_brightness
    sideBrightness['left_right_ratio'] = left_brightness / right_brightness

    return sideBrightness


def track_nose_tip(videoFileName, video_dir=None):
    ## Using OpenCV

    # Open video file defined by videoDirectory, videoFileName 
    # Open the video file
    vidcap = cv2.VideoCapture(videoFileName)

    if video_dir is not None:
        # Define the codec and create VideoWriter object
        fourcc = cv2.VideoWriter_fourcc(*'XVID')
        nt_overlay_vid = cv2.VideoWriter(os.path.join(video_dir, 'nose_tip.avi'), fourcc, 20.0, (int(vidcap.get(3)), int(vidcap.get(4))))
    
    # Loop through the video frames
    while vidcap.isOpened():
        # open the next frame
        try:
            success, image = vidcap.read()
        except:
            print('Error reading frame')
            continue
        # if there is no next frame, break the loop
        if not success:
            break
            
        # Threshold the frame and apply morphological opening to the binary image
        crop_size = 400
        _, opening = morph_open(image, crop=True, crop_size=crop_size)

        # Find contours in the opened morphology
        contours = find_contours(opening)

        # Filter contours based on minimum area threshold
        minArea = 6000
        filteredContours = [cnt for cnt in contours if cv2.contourArea(cnt) >= minArea]

        # Find the largest contour
        contour = max(filteredContours, key=cv2.contourArea)

        # # Get the current frame number
        # initialFrame=vidcap.get(cv2.CAP_PROP_POS_FRAMES)-1

        # Find the extreme points of the largest contour
        extrema = contour[:, 0, :]
        bottom_point = extrema[extrema[:, 1].argmax()]
        top_point = extrema[extrema[:, 1].argmin()]
        left_point = extrema[extrema[:, 0].argmin()]
        right_point = extrema[extrema[:, 0].argmax()]

        sideBrightness=get_side_brightness(opening, contour)

        # We keep the extrema along the longest axis. 
        # The head side is the base of triangle, while the nose is the tip of the triangle
        if sideBrightness['maxSide'] == 'top' or sideBrightness['maxSide'] == 'bottom':
            # Find the base of the triangle: if left and right extrema are on the top half of the image, the top extrema is the base
            face_axis='vertical'
            if sideBrightness['maxSide'] == 'bottom':
                face_orientation = 'up'
                f_nose_tip = top_point
            else:
                face_orientation = 'down'
                f_nose_tip = bottom_point
        else:
            # Find the base of the triangle: if top and bottom extrema are on the left half of the image, the left extrema is the base
            face_axis='horizontal'
            if sideBrightness['maxSide'] == 'right':
                face_orientation = 'left'
                f_nose_tip = left_point
            else:
                face_orientation = 'right'
                f_nose_tip = right_point

        # Finally, adjust the nose tip coordinates to the original image coordinates
        if crop_size is not None:
            f_nose_tip = f_nose_tip + np.array([image.shape[1]//2-crop_size//2, image.shape[0]//2-crop_size//2])

        # Add the frame's nose tip coordinates to the nose_tip array
        if 'nose_tip' not in locals():
            nose_tip = f_nose_tip
        else:
            nose_tip = np.vstack((nose_tip, f_nose_tip))

        if video_dir is not None:
            # Write the frame with the nose tip labelled on it to the opened video file. 
            # The nose tip is labelled with a blue circle
            nt_overlay_vid.write(cv2.circle(image, tuple(f_nose_tip), 10, (255, 0, 0), -1))

            # cv2.imwrite(os.path.join(video_dir, 'nose_tip.jpg'), cv2.circle(image, tuple(nose_tip), 10, (255, 0, 0), -1))

    # # Close the source and output video files
    vidcap.release()
    if video_dir is not None:
        nt_overlay_vid.release()

    return nose_tip

# Parse command-line arguments
parser = argparse.ArgumentParser()
parser.add_argument('--input', help='Path to input video file', required=True)
parser.add_argument('--base', help='Base name for output files', required=True)
parser.add_argument('--nproc', help='Number of trace processes', type=int, default=40)
parser.add_argument('--output_dir', help='Output directory', type=str, default=os.path.join('/data', 'WT'))
args = parser.parse_args()

# Set input and output file paths
input_file = args.input
base_name = args.base
output_dir = args.output_dir
input_dir = os.path.dirname(input_file)
nproc = args.nproc

# if output directory doesn't exist, create it
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# Write all print statements to a log file
log_file = open(os.path.join(input_dir, f'nose_track_{base_name}_log.txt'), 'w')
sys.stdout = log_file

# Time the script
start_time = time.time()
print('Start time:', time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(start_time)))

########################
### Run nose tracking
########################

# Time the tracking
start_time_track = time.time()

time_track = time.time() - start_time_track
print(f'Tracking took {time_track} seconds.')

# Get the nose tip coordinates
nose_tip = track_nose_tip(input_file)

# Save the nose tip coordinates to a json file
# with open(os.path.join(output_dir, f'nose_tip_{base_name}.json'), 'w') as f:
#     json.dump(nose_tip.tolist(), f)

# Save the nose tip coordinates to a csv file
np.savetxt(os.path.join(output_dir, f'nose_tip_{base_name}.csv'), nose_tip.astype(int), fmt='%d', delimiter=',')
    
# Overall time elapsed
time_elapsed = time.time() - start_time
print(f'Time for whole script: {time_elapsed} seconds')

# Close the log file
sys.stdout.close()
sys.stdout = sys.__stdout__



