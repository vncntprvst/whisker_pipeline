import glob
import os
import sys
import argparse
import deeplabcut

def main(config_file, video_dir, dest_dir=None, video_type='mp4', shuffle_num='1', gpu_id='0'):
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
        print("No video files found matching the specified extensions.")
        sys.exit(1)

    print(f"Found video files:\n{video_files}")

    # Run DeepLabCut analysis
    deeplabcut.analyze_videos(config_file, video_files, videotype=video_type, shuffle=shuffle_num, save_as_csv=True, destfolder=dest_dir)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run DeepLabCut analysis on videos.")
    parser.add_argument('--config', required=True, help="Path to the DeepLabCut config.yaml file.")
    parser.add_argument('--videos', required=True, help="Directory containing the videos to analyze.")
    parser.add_argument('--dest_dir', help="Directory to save the output files (default: same as video directory).")
    parser.add_argument('--videotype', default='mp4', help="Type of video files to analyze (default: mp4).")
    parser.add_argument('--shuffle_num', default='1', help="Shuffle number for analysis")
    parser.add_argument('--gpu', default='0', help="GPU ID to use (default: 0).")

    args = parser.parse_args()

    # If dest_dir is not specified, assign it to the video directory
    if args.dest_dir is None:
        args.dest_dir = args.videos

    # Create dest_dir if it does not exist
    os.makedirs(args.dest_dir, exist_ok=True)
    
    main(config_file=args.config, video_dir=args.videos, dest_dir=args.dest_dir, video_type=args.videotype, shuffle_num=args.shuffle_num, gpu_id=args.gpu)
