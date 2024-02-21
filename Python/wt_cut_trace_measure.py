# This script first cuts video in half vertically at the midline and flip right side along vertical axis 
# then call Whiskiwrap to trace and measure whiskers.

import argparse
import os, sys
import pickle
import WhiskiWrap
from WhiskiWrap import FFmpegReader
from . import whiskerpad
from .whiskerpad import WhiskerPad
import ffmpeg
import json
import numpy as np
import time

# if __debug__:
#     print("Running in debug mode")
#     import sys
#     input_file = sys.argv[1]
#     base_name = sys.argv[2]
#     output_dir = sys.argv[3]
#     nproc = int(sys.argv[4])
# else:
# print("Not running in debug mode")

# Parse command-line arguments
parser = argparse.ArgumentParser()
parser.add_argument('--input', help='Path to input video file', required=True)
parser.add_argument('--base', help='Base name for output files', required=True)
parser.add_argument('--nproc', help='Number of trace processes', type=int, default=40)
parser.add_argument("--splitUp", action="store_true", help="Flag to split the video")
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
log_file = open(os.path.join(input_dir, f'cut_trace_measure_{base_name}_log.txt'), 'w')
sys.stdout = log_file

# Time the script
start_time = time.time()
print('Start time:', time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(start_time)))

# Create whiskerpad parameters file. 
# The file has the same name as the input video file, but with the extension .json, and prefixed with whiskerpad_

whiskerpad_file = os.path.join(input_dir, f'whiskerpad_{os.path.basename(input_file).split(".")[0]}.json')
# if file already exists, skip this step
if not os.path.exists(whiskerpad_file):
    print('Creating whiskerpad parameters file.')
    wp=whiskerpad.Params(input_file, args.splitUp)
    # Get whiskerpad parameters
    whiskerpadParams, splitUp = WhiskerPad.get_whiskerpad_params(wp)
    # Save whisking parameters to json file
    WhiskerPad.save_whiskerpad_params(wp, whiskerpadParams)

# Load whiskerpad json file
with open(whiskerpad_file, 'r') as f:
    whiskerpad_params = json.load(f)

# Check that left and right whiskerpad parameters are defined
if np.size(whiskerpad_params['whiskerpads'])<2:
    raise Exception('Missing whiskerpad parameters in whiskerpad json file.')

# Get side types (left / right or top / bottom)
side_types = [whiskerpad['FaceSide'].lower() for whiskerpad in whiskerpad_params['whiskerpads']]

# Crop video
# Time the cropping
start_time_crop = time.time()
for side in side_types:
    # if video already exists, skip this step
    side_output = os.path.join(os.path.dirname(input_file), f'{base_name}_{side}.mp4')
    if not os.path.exists(side_output):
        print(f'Cropping {side} face side video...')
        # Get the side's whiskerpad params
        side_whiskerpad = next((whiskerpad for whiskerpad in whiskerpad_params['whiskerpads'] if whiskerpad['FaceSide'].lower() == side), None)
        if side_whiskerpad is None:
            raise ValueError(f'Could not find {side} whiskerpad in whiskerpad_params')

        try:
            coord_x = side_whiskerpad['ImageCoordinates'][0]
            coord_y = side_whiskerpad['ImageCoordinates'][1]
            coord_width = side_whiskerpad['ImageCoordinates'][2]
            coord_height = side_whiskerpad['ImageCoordinates'][3]
            # if first two coordinates (x, y) are 0, 0, just crop at the image coordinates specified
            if coord_x == 0 and coord_y == 0:
                ffmpeg.input(input_file).filter('crop', coord_width, coord_height, coord_x, coord_y).output(side_output).run(overwrite_output=True)
                # add two fields to the whiskerpad_params file, in the relevant 'whiskerpads': Flip (false / true) and Flipped_ImageBorderAxis ('right', when ImageBorderAxis is 'left', and vice versa)
                side_whiskerpad['Flip'] = False

            # otherwise, crop and flip the video
            elif coord_x > 0: 
                ffmpeg.input(input_file).filter('crop', coord_width, coord_height, coord_x, coord_y).filter('hflip').output(side_output).run(overwrite_output=True)
                # add two fields to the whiskerpad_params file, in the relevant 'whiskerpads': Flip (false / true) and Flipped_ImageBorderAxis ('right', when ImageBorderAxis is 'left', and vice versa)
                side_whiskerpad['Flip'] = True
                if side_whiskerpad['ImageBorderAxis'].lower() == 'left':
                    side_whiskerpad['Flipped_ImageBorderAxis'] = 'right'
                elif side_whiskerpad['ImageBorderAxis'].lower() == 'right':
                    side_whiskerpad['Flipped_ImageBorderAxis'] = 'left'
                else:
                    raise ValueError('ImageBorderAxis must be either "left" or "right"')

            elif coord_y > 0:
                ffmpeg.input(input_file).filter('crop', coord_width, coord_height, coord_x, coord_y).filter('vflip').output(side_output).run(overwrite_output=True)
                # add two fields to the whiskerpad_params file, in the relevant 'whiskerpads': Flip (false / true) and Flipped_ImageBorderAxis ('top', when ImageBorderAxis is 'bottom', and vice versa)
                side_whiskerpad['Flip'] = True
                if side_whiskerpad['ImageBorderAxis'].lower() == 'bottom':
                    side_whiskerpad['Flipped_ImageBorderAxis'] = 'top'
                elif side_whiskerpad['ImageBorderAxis'].lower() == 'top':
                    side_whiskerpad['Flipped_ImageBorderAxis'] = 'bottom'
                else:
                    raise ValueError('ImageBorderAxis must be either "top" or "bottom"')
                
            # update the current whiskerpads field in whiskerpad_params with side_whiskerpad
            # get index of side_whiskerpad in whiskerpad_params
            side_whiskerpad_index = next((index for (index, d) in enumerate(whiskerpad_params['whiskerpads']) if d["FaceSide"].lower() == side), None)
            # update whiskerpad_params
            whiskerpad_params['whiskerpads'][side_whiskerpad_index] = side_whiskerpad
                
            # save whiskerpad_params to json file
            # create wp object if it doesn't exist
            if not 'wp' in locals():
                wp=whiskerpad.Params(input_file, args.splitUp)
            WhiskerPad.save_whiskerpad_params(wp, whiskerpad_params['whiskerpads'])

            print(f'Done for {side} face side.')
        except ffmpeg.Error as e:
            print('Error occurred while cropping video: {}'.format(e.stderr))
    else:
        print(f'{side} face side video already exists. Skipping cropping.')
time_crop = time.time() - start_time_crop
print(f'Cropping took {time_crop} seconds.')

########################
### Run whisker tracking
########################

# Time the tracking
start_time_track = time.time()

for side in side_types:
    print(f'Running whisker tracking for {side} face side video')

    cropped_video = os.path.join(os.path.dirname(input_file), f'{base_name}_{side}.mp4')
    h5_filename = os.path.join(os.path.dirname(input_file), f'{base_name}_{side}.hdf5')
    chunk_name_pattern = f'{base_name}_{side}_%08d.tif'

    # The `face` argument here is the side of the video frame where the face is located. 
    # That tells `measure` which side of traced objects should be considered the follicle.

    # get the ImageBorderAxis or Flipped_ImageBorderAxis for the side
    side_whiskerpad_index = next((index for (index, d) in enumerate(whiskerpad_params['whiskerpads']) if d["FaceSide"].lower() == side), None)
    if 'Flip' in whiskerpad_params['whiskerpads'][side_whiskerpad_index] and whiskerpad_params['whiskerpads'][side_whiskerpad_index]['Flip'] == True:
        im_side=next((whiskerpad['Flipped_ImageBorderAxis'] for whiskerpad in whiskerpad_params['whiskerpads'] if whiskerpad['FaceSide'].lower() == side), None)
    else:
        im_side=next((whiskerpad['ImageBorderAxis'] for whiskerpad in whiskerpad_params['whiskerpads'] if whiskerpad['FaceSide'].lower() == side), None)

    result_dict = WhiskiWrap.interleaved_read_trace_and_measure(            
        FFmpegReader(cropped_video),
        output_dir,
        chunk_name_pattern=chunk_name_pattern,
        chunk_size=200,
        h5_filename=h5_filename,
        n_trace_processes=nproc, face=im_side
    )

time_track = time.time() - start_time_track
print(f'Tracking took {time_track} seconds.')

    ## Read hdf5 file
    # from WhiskiWrap.base import read_whiskers_hdf5_summary
    # h5_filename='/data/dev/sc014_0315_001_left.hdf5'
    # table = read_whiskers_hdf5_summary(h5_filename)
    # print(table.head())

    # import pandas
    # import tables

    # with tables.open_file(h5_filename) as fi:
    #     summary = pandas.DataFrame.from_records(fi.root.summary.read())

    # print(summary.head())

    # fi=tables.open_file(h5_filename)

# Overall time elapsed
time_elapsed = time.time() - start_time
print(f'Time for whole script: {time_elapsed} seconds')

# Close the log file
sys.stdout.close()
sys.stdout = sys.__stdout__
