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
import math

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
    
    # Determine video format
    _, file_extension = os.path.splitext(video_path)
    file_extension = file_extension.lower()
    
    # Estimate processing rate (frames per minute)
    processing_rate = 14000  # frames per minute
    
    # Estimate wall time (in minutes)
    estimated_wall_time_minutes = frame_count / processing_rate
    # Round up and add 25% safety margin
    estimated_wall_time_minutes = int(math.ceil(estimated_wall_time_minutes * 1.25))
    estimated_wall_time_minutes = max(estimated_wall_time_minutes, 30)  # Minimum 30 minutes
    
    # Estimate memory per frame (bytes)
    # This is for 720 * 540 frames (388,800 pixels). Adjust scripts for other frame sizes.
    if file_extension in ['.mp4', '.mov']:
        memory_per_frame = 180000  # bytes per frame for MP4
    else:
        memory_per_frame = 540000  # bytes per frame for AVI
    
    # Estimate total memory (GB)
    estimated_memory_gb = (frame_count * memory_per_frame) / 1e9  # Convert to GB
    estimated_memory_gb *= 1.25  # Add 25% safety margin
    estimated_memory_gb = math.ceil(estimated_memory_gb)  # Round up
    
    # Print the information
    print(f"Video file: {video_path}")
    print(f"Frame dimensions: {frame_width}x{frame_height}")
    print(f"Number of frames: {frame_count}")
    print(f"File size: {file_size} bytes")
    print(f"Weight per frame: {weight_per_frame} bytes")
    print(f"Estimated wall time: {estimated_wall_time_minutes} minutes")
    print(f"Estimated memory: {estimated_memory_gb} GB")
    
    # Release the video capture object
    cap.release()
    
    # Return estimated values
    return estimated_wall_time_minutes, estimated_memory_gb
