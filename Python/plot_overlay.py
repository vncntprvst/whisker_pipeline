import os
import cv2
from pathlib import Path
import tables
# import numpy as np
import pyarrow.parquet as pq
import pandas as pd
import matplotlib.pyplot as plt
import argparse

def load_whisker_data(base_name, data_dir):
    """Load whisker data from HDF5 or Parquet."""
    print(f"Loading whisker data from {data_dir}/{base_name}")
    if os.path.exists(f'{data_dir}/{base_name}.hdf5'):
        with tables.open_file(f'{data_dir}/{base_name}.hdf5', mode='r') as h5file:
            pixels_x = h5file.get_node('/pixels_x')
            pixels_y = h5file.get_node('/pixels_y')
            summary = h5file.get_node('/summary')
            df = pd.DataFrame(summary[:])
            df['pixels_x'] = [pixels_x[i] for i in df['wid']]
            df['pixels_y'] = [pixels_y[i] for i in df['wid']]
        return df
    
    elif os.path.exists(f'{data_dir}/{base_name}.parquet'):
        parquet_file = f'{base_name}.parquet'
        table = pq.read_table(f'{data_dir}/{parquet_file}')
        df = table.to_pandas()
        return df

    else:
        raise FileNotFoundError("No valid whisker data file found")

def get_longest_whiskers(df, fid_num):
    """Get the longest whiskers for the specified frame."""
    first_frame_df = df[df['fid'] == fid_num]
    sides = first_frame_df['face_side'].unique()

    longest_whiskers = []
    for side in sides:
        side_df = first_frame_df[first_frame_df['face_side'] == side]
        longest_whiskers.append(side_df.nlargest(3, 'pixel_length'))

    return longest_whiskers

def plot_whiskers_on_frame(longest_whiskers, frame):
    """Plot the whiskers on a video frame."""
    colors = [(255,0,0), (0,255,0), (0,0,255), (255,255,0), (255,0,255),
              (0,255,255), (128,0,0), (0,128,0), (0,0,128), (128,128,0),
              (128,0,128), (0,128,128), (64,0,0), (0,64,0), (0,0,64),
              (64,64,0), (64,0,64), (0,64,64), (192,0,0), (0,192,0)]

    for longest_whiskers_side in longest_whiskers:
        for index, whisker_data in longest_whiskers_side.iterrows():
            color_index = index % len(colors)
            color = colors[color_index]
            for j in range(whisker_data['pixels_x'].shape[0]):
                x = int(whisker_data['pixels_x'][j])
                y = int(whisker_data['pixels_y'][j])
                cv2.circle(frame, (x, y), 2, color, -1)
    
    return frame

def save_frame_with_overlay(frame, data_dir, base_name, fid_num):
    """Save the video frame with whisker overlay."""
    Path(f'{data_dir}/plots').mkdir(parents=True, exist_ok=True)
    plt.imshow(frame)
    plt.savefig(f'{data_dir}/plots/{base_name}_WhiskerOverlay_Frame_{fid_num}.png')
    plt.close()

def main(video_file, base_name, fid_num=0):
    """Main function to overlay whisker tracking on video."""
    data_dir = os.path.dirname(video_file)

    # Load whisker data
    df = load_whisker_data(base_name, data_dir)

    # Get the longest whiskers for the specified frame
    longest_whiskers = get_longest_whiskers(df, fid_num)

    # Read the corresponding video frame
    cap = cv2.VideoCapture(video_file)
    cap.set(cv2.CAP_PROP_POS_FRAMES, fid_num)
    ret, frame = cap.read()
    cap.release()

    if not ret:
        raise ValueError(f"Could not read frame {fid_num} from video")

    # Plot whiskers on the frame
    frame_with_overlay = plot_whiskers_on_frame(longest_whiskers, frame)

    # Save the frame with the whisker overlay
    save_frame_with_overlay(frame_with_overlay, data_dir, base_name, fid_num)

if __name__ == "__main__":
    # get the path to the video file from the arguments using argparse
    parser = argparse.ArgumentParser(description='Overlay whisker tracking on video.')
    parser.add_argument('video_file', type=str, help='Path to the video file')
    parser.add_argument('--base_name', type=str, default=None, help='Base name of the video file')
    parser.add_argument('--fid_num', type=int, default=0, help='Frame number to overlay whiskers on')
    args = parser.parse_args()    
    
    if args.base_name is None:
        args.base_name = os.path.basename(args.video_file).split(".")[0]
    
    # call the main function with the video file path
    print(f"Overlaying whisker tracking on video: {args.video_file}")
    main(args.video_file, args.base_name, args.fid_num)
