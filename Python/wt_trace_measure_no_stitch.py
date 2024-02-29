# This script creates and/or loads whiskerpad parameters, and calls WhiskiWrap to trace and measure whiskers.  
# Unlike cut_trace_measure.py, this script does not crop the video.

import argparse
import os, sys
import json
import numpy as np
import time

import WhiskiWrap as ww
from WhiskiWrap import load_whisker_data as lwd
import whiskerpad as wp
# Check that whisk binaries are executables and update permissions if necessary
from wwutils.whisk_permissions import update_permissions
update_permissions()

def trace_measure(input_file, base_name, output_dir, nproc, splitUp):
        
    # if output directory doesn't exist, create it
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    input_dir = os.path.dirname(input_file)

    # Write all print statements to a log file
    log_file = open(os.path.join(input_dir, f'trace_measure_{base_name}_log.txt'), 'w')
    sys.stdout = log_file

    # Time the script
    start_time = time.time()
    print('Start time:', time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(start_time)))

    # Load whiskerpad json file
    whiskerpad_file = os.path.join(input_dir, f'whiskerpad_{base_name}.json')
    # whiskerpad_file = os.path.join(input_dir, f'whiskerpad_{os.path.basename(input_file).split(".")[0]}.json')
    
    if not os.path.exists(whiskerpad_file):
    # If whiskerpad file does not exist, create it
        print('Creating whiskerpad parameters file.')
        whiskerpad=wp.Params(input_file, splitUp, base_name)
        # Get whiskerpad parameters
        whiskerpadParams, splitUp = wp.WhiskerPad.get_whiskerpad_params(whiskerpad)
        # Save whisking parameters to json file
        wp.WhiskerPad.save_whiskerpad_params(whiskerpad, whiskerpadParams)

    with open(whiskerpad_file, 'r') as f:
        whiskerpad_params = json.load(f)

    # Check that left and right whiskerpad parameters are defined
    if np.size(whiskerpad_params['whiskerpads'])<2:
        raise Exception('Missing whiskerpad parameters in whiskerpad json file.')

    # Get side types (left / right or top / bottom)
    side_types = [whiskerpad['FaceSide'].lower() for whiskerpad in whiskerpad_params['whiskerpads']]

    ########################
    ### Run whisker tracking
    ########################

    for side in side_types:
        print(f'Running whisker tracking for {side} face side video')

        # Time the tracking
        start_time_track = time.time()

        h5_filename = os.path.join(os.path.dirname(input_file), f'{base_name}_{side}.hdf5')
        chunk_name_pattern = f'{base_name}_{side}_%08d.tif'

        # get the ImageBorderAxis for the side
        im_side=next((whiskerpad['ImageBorderAxis'] for whiskerpad in whiskerpad_params['whiskerpads'] if whiskerpad['FaceSide'].lower() == side), None)
        if im_side is None:
            raise ValueError(f'Could not find {side} whiskerpad ImageBorderAxis in whiskerpad_params')
        
        # Get image coordinates
        side_im_coord = next((whiskerpad['ImageCoordinates'] for whiskerpad in whiskerpad_params['whiskerpads'] if whiskerpad['FaceSide'].lower() == side), None)
        # reorder side_im_coord to fit -vf crop format width:height:x:y
        side_im_coord = [side_im_coord[2], side_im_coord[3], side_im_coord[0], side_im_coord[1]]
        
        # The `face` argument below is the side of the video frame where the face is located. 
        # That tells `measure` which side of traced objects should be considered the follicle.
        result_dict = ww.interleaved_split_trace_and_measure(            
            ww.FFmpegReader(input_file, crop=side_im_coord),
            output_dir,
            chunk_name_pattern=chunk_name_pattern,
            chunk_size=200,
            h5_filename=h5_filename,
            n_trace_processes=nproc, 
            frame_func='crop',
            skip_stitch=True,
            face=im_side,
            # Pass arguments for the classify call
            classify={'px2mm': '0.04', 'n_whiskers': '3'},
            summary_only = True,
            skip_existing=True
        )      

        time_track = time.time() - start_time_track
        print(f'Tracking took {time_track} seconds.')

        # Reassess whisker IDs
        # lwd.update_wids(h5_filename) -- no need, and can't work because relies on hdf5 summary table

        ## Read hdf5 file
        # from ww.base import read_whiskers_hdf5_summary
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

def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('input', help='Path to input video file')
    parser.add_argument('-b', '--base', type=str, help='Base name for output files')
    parser.add_argument('-s', '--splitUp', action="store_true", help="Flag to split the video")
    parser.add_argument('-p', '--nproc', type=int, default=40, help='Number of trace processes')
    parser.add_argument('-o', '--output_dir', type=str, help='Output directory. Default is the same directory as the input file + WT')
    args = parser.parse_args()

    # Set input and output file paths
    input_file = args.input

    if args.output_dir is None:
    # If output directory is not provided, use the same directory as the input file + WT
        output_dir = os.path.join(os.path.dirname(input_file), 'WT')
    else:
        output_dir = args.output_dir

    if args.base is None:
    # If base name is not provided, use the input file name without the extension
        base_name = os.path.basename(input_file).split('.')[0]
    else:
        base_name = args.base

    if args.splitUp is None:
    # If splitUp is not provided, set it to False
        splitUp = False
    else:
        splitUp = args.splitUp

    nproc = args.nproc

    trace_measure(input_file, base_name, output_dir, nproc, splitUp)

if __name__ == '__main__':
    main()