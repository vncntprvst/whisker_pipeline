import glob
import os
import sys
import argparse
import deeplabcut

def main(config_file, video_dir, video_type='mp4', gpu_id='0'):
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
    deeplabcut.analyze_videos(config_file, video_files, videotype=video_type)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run DeepLabCut analysis on videos.")
    parser.add_argument('--config', required=True, help="Path to the DeepLabCut config.yaml file.")
    parser.add_argument('--videos', required=True, help="Directory containing the videos to analyze.")
    parser.add_argument('--videotype', default='mp4', help="Type of video files to analyze (default: mp4).")
    parser.add_argument('--gpu', default='0', help="GPU ID to use (default: 0).")

    args = parser.parse_args()

    main(config_file=args.config, video_dir=args.videos, video_type=args.videotype, gpu_id=args.gpu)
