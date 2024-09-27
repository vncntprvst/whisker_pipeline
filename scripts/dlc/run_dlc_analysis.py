"""
Script to run DeepLabCut analysis on videos, and optionally filter labels, plot trajectories, and create labeled videos.

Usage:
python run_dlc_analysis.py --config /path/to/config.yaml --videos /path/to/videos --dest_dir /path/to/output --videotype mp4 --shuffle_num 1 --gpu 0 --filter --plot --labeled_video

Arguments:
- config: Path to the DeepLabCut config.yaml file.
- videos: Directory containing the videos to analyze.
- dest_dir: Directory to save the output files (default: same as video directory).
- videotype: Type of video files to analyze (default: mp4).
- shuffle_num: Shuffle number for analysis.
- gpu: GPU ID to use (default: 0).
- filter: Filter the labels after analysis.
- plot: Plot the trajectories after analysis.
- labeled_video: Create labeled videos after analysis.
"""


import glob
import os
import sys
import argparse
import deeplabcut
import time

# TODO: Removed passing kwargs to deeplabcut functions for now, as they are all lumped together in the 'kwargs' dictionary. Would need to check which kwargs are valid for each function and pass them accordingly.

def analyze_videos(config_file, video_files, **kwargs):
    """
    Run DeepLabCut analysis on the provided video files.

    Parameters:
    - config_file: Path to the DeepLabCut config file.
    - video_files: List of video file paths to analyze.
    - **kwargs: Additional keyword arguments including 'videotype', 'shuffle', 'save_as_csv', and 'destfolder'.
    """
    
    # Extract specific arguments from kwargs if available
    video_type = kwargs.pop('videotype', 'mp4')
    shuffle_num = kwargs.pop('shuffle', 1)
    csv_export = kwargs.pop('save_as_csv', False)
    dest_dir = kwargs.pop('destfolder', None)
    skipexisting = kwargs.pop('skipexisting', False)
    
    if skipexisting:
        # Check if the analysis has already been performed on the videos        
        video_files_to_analyze = []
        for video in video_files:
            video_name = os.path.splitext(os.path.basename(video))[0]
            h5_pattern = os.path.join(dest_dir, f"{video_name}DLC_resnet50*.h5")
            if not glob.glob(h5_pattern):
                video_files_to_analyze.append(video)
            else:
                print(f"Skipping analysis for {video} as matching .h5 files already exist.")
    else:
        video_files_to_analyze = video_files
        
    
    # Run DeepLabCut analysis using the required parameters and passing remaining kwargs
    deeplabcut.analyze_videos(config_file, video_files, 
                              videotype=video_type, 
                              shuffle=shuffle_num, 
                              save_as_csv=csv_export, 
                              destfolder=dest_dir, 
                              )
    
def filter_labels(config_file, video_files, **kwargs):
    """
    Filter the labels from the DeepLabCut analysis.

    Parameters:
    - config_file: Path to the DeepLabCut config file.
    - video_files: List of video file paths to analyze.
    - **kwargs: Additional keyword arguments including 'videotype', 'shuffle', 'save_as_csv', and 'destfolder'.
    """
    
    # Extract specific arguments from kwargs if available
    video_type = kwargs.pop('videotype', 'mp4')
    shuffle_num = kwargs.pop('shuffle', 1)
    csv_export = kwargs.pop('save_as_csv', False)
    dest_dir = kwargs.pop('destfolder', None)
    
    # Run filterpredictions using the required parameters and passing remaining kwargs
    deeplabcut.filterpredictions(config_file, video_files, 
                                 videotype=video_type, 
                                 shuffle=shuffle_num, 
                                 save_as_csv=csv_export, 
                                 destfolder=dest_dir, 
                                 )
    
def plot_trajectories(config_file, video_files, **kwargs):
    """
    Plot the trajectories from the DeepLabCut analysis.

    Parameters:
    - config_file: Path to the DeepLabCut config file.
    - video_files: List of video file paths to analyze.
    - **kwargs: Additional keyword arguments including 'videotype', 'shuffle', 'save_as_csv', and 'destfolder'.
    """
    
    # Extract specific arguments from kwargs if available
    video_type = kwargs.pop('videotype', 'mp4')
    shuffle_num = kwargs.pop('shuffle', 1)
    filtered_labels = kwargs.pop('filtered', False)
    dest_dir = kwargs.pop('destfolder', None)
    
    # Run plot_trajectories using the required parameters and passing remaining kwargs
    deeplabcut.plot_trajectories(config_file, video_files, 
                                 videotype=video_type, 
                                 shuffle=shuffle_num, 
                                 filtered=filtered_labels, 
                                 destfolder=dest_dir,
                                 )

def create_labeled_video(config_file, video_files, **kwargs):
    """
    Create labeled videos from the DeepLabCut analysis.

    Parameters:
    - config_file: Path to the DeepLabCut config file.
    - video_files: List of video file paths to analyze.
    - **kwargs: Additional keyword arguments including 'videotype', 'shuffle', 'save_as_csv', and 'destfolder'.
    """
    
    # Extract specific arguments from kwargs if available
    video_type = kwargs.pop('videotype', 'mp4')
    shuffle_num = kwargs.pop('shuffle', 1)
    filtered_labels = kwargs.pop('filtered', False)
    dest_dir = kwargs.pop('destfolder', None)
    
    # Run create_labeled_video using the required parameters and passing remaining kwargs
    deeplabcut.create_labeled_video(config_file, video_files, 
                                    videotype=video_type, 
                                    shuffle=shuffle_num, 
                                    filtered=filtered_labels, 
                                    destfolder=dest_dir, 
                                    )
def get_frame_count(video_path):
    """
    Get the total number of frames in a video file.
    """
    import cv2
    cap = cv2.VideoCapture(video_path)
    frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    cap.release()
    return frame_count

def main(config_file, video_dir, dest_dir=None, video_type='mp4', shuffle_num=1, gpu_id='0', **kwargs):
    """
    Main function to analyze videos using DeepLabCut.

    Parameters:
    - config_file: Path to the DeepLabCut config file.
    - video_dir: Directory containing video files to analyze.
    - dest_dir: Directory to save the output (if not provided, uses video_dir).
    - video_type: Type of video files to process (default 'mp4').
    - shuffle_num: Shuffle index for DeepLabCut model (default 1).
    - gpu_id: ID of the GPU to use (default '0').
    - **kwargs: Additional keyword arguments to pass to analyze_videos.
    """
    
    # If no destination directory is specified, use the video directory
    if dest_dir is None:
        dest_dir = video_dir
    
    # Set the GPU to use
    os.environ['CUDA_VISIBLE_DEVICES'] = gpu_id

    # Check the config file
    with open(config_file, 'r') as file:
        print(f"Using config file:\n{file.read()}")

    # Use glob to find all video files in the directory
    video_files = glob.glob(os.path.join(video_dir, '*.*'))

    # Filter for accepted video file extensions
    video_extensions = ('.mp4', '.avi', '.mov')
    video_files = [file for file in video_files if file.lower().endswith(video_extensions)]

    if not video_files:
        print(f"No video files found matching the specified extensions in {video_dir}.")
        sys.exit(1)

    print(f"Found video files:\n{video_files}")
    
    # Analyze the videos and pass additional kwargs
    print(f"Analyzing videos in {video_dir} and saving output to {dest_dir}...")
    
    # Start the timer
    start_time = time.time()

    analyze_videos(config_file, 
                   video_files, 
                   videotype=video_type, 
                   shuffle=shuffle_num, 
                   destfolder=dest_dir, 
                   skipexisting=True)
    
    # End the timer
    end_time = time.time()

    # Calculate the elapsed time
    elapsed_time = end_time - start_time
    
    print(f"Total time spent on analyzing videos: {elapsed_time:.2f} seconds")

    # Calculate the total number of frames in all videos
    total_frames = sum(get_frame_count(video) for video in video_files)

    # Calculate the ratio of time spent to number of frames
    if total_frames > 0:
        time_per_frame = elapsed_time / total_frames
        print(f"Total number of frames: {total_frames}")
        print(f"Time spent per frame: {time_per_frame:.6f} seconds/frame")
    else:
        print("No frames found in the provided videos.")
        
    # If the 'filter' flag is set, filter the labels
    if kwargs.get('filter', False):
        print("Filtering labels...")
        filter_labels(config_file, video_files, videotype=video_type, shuffle=shuffle_num, destfolder=dest_dir, **kwargs)

    # If the 'plot' flag is set, plot the trajectories
    if kwargs.get('plot', False):
        print("Plotting trajectories...")
        plot_trajectories(config_file, video_files, videotype=video_type, shuffle=shuffle_num, destfolder=dest_dir, **kwargs)

    # If the 'labeled_video' flag is set, create labeled videos
    if kwargs.get('labeled_video', False):
        print("Creating labeled videos...")
        create_labeled_video(config_file, video_files, videotype=video_type, shuffle=shuffle_num, destfolder=dest_dir, **kwargs)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run DeepLabCut analysis on videos.")
    parser.add_argument('--config', required=True, help="Path to the DeepLabCut config.yaml file.")
    parser.add_argument('--videos', required=True, help="Directory containing the videos to analyze.")
    parser.add_argument('--dest_dir', help="Directory to save the output files (default: same as video directory).")
    parser.add_argument('--videotype', default='mp4', help="Type of video files to analyze (default: mp4).")
    parser.add_argument('--shuffle_num', default='1', help="Shuffle number for analysis")
    parser.add_argument('--gpu', default='0', help="GPU ID to use (default: 0).")
    parser.add_argument('--save_as_csv', default=True, help="Save the output as CSV files.")
    parser.add_argument('--filter_labels', action='store_true', help="Filter the labels after analysis.")
    parser.add_argument('--plot_trajectories', action='store_true', help="Plot the trajectories after analysis.")
    parser.add_argument('--create_labeled_video', action='store_true', help="Create labeled videos after analysis.")

    args = parser.parse_args()

    # If dest_dir is not specified, assign it to the video directory
    if args.dest_dir is None:
        args.dest_dir = args.videos

    # Create dest_dir if it does not exist
    try:
        os.makedirs(args.dest_dir, exist_ok=True)
    except OSError as e:
        print(f"Error creating destination directory {args.dest_dir}: {e}")
        sys.exit(1)
    
    main(config_file=args.config, video_dir=args.videos, dest_dir=args.dest_dir,
         video_type=args.videotype, shuffle_num=args.shuffle_num, gpu_id=args.gpu, 
         save_as_csv=args.save_as_csv, filter=args.filter_labels, plot=args.plot_trajectories, labeled_video=args.create_labeled_video)
