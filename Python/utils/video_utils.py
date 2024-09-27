# Example usage
# In Python:
# video_path = "path/to/your/video.avi"
# get_video_info(video_path)
# Or from the terminal: 
# conda activate DEEPLABCUT
# video_path = "path/to/your/video.avi"
# python -c "from utils.video_utils import get_video_info; get_video_info('$video_path')"

import cv2
import os

def get_video_info(video_path):
    # Open the video file
    cap = cv2.VideoCapture(video_path)
    
    if not cap.isOpened():
        print(f"Error: Could not open video file {video_path}")
        return
    
    # Get frame dimensions
    frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    
    # Get number of frames
    frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    
    # Get the size of the video file in bytes
    file_size = os.path.getsize(video_path)
    
    # Calculate weight per frame
    weight_per_frame = file_size / frame_count if frame_count > 0 else 0
    
    # Print the information
    print(f"Video file: {video_path}")
    print(f"Frame dimensions: {frame_width}x{frame_height}")
    print(f"Number of frames: {frame_count}")
    print(f"File size: {file_size} bytes")
    print(f"Weight per frame: {weight_per_frame} bytes")
    
    # Release the video capture object
    cap.release()

