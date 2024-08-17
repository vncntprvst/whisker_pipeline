"""
This script creates and/or loads whiskerpad parameters, and calls WhiskiWrap to trace and measure whiskers.  
Unlike cut_trace_measure.py, this script does not crop the video.

Example usage:
```bash
python wt_trace_measure_no_stitch.py /path/to/video.mp4 -b base_name -o /path/to/output_dir -p 40
```
"""

import argparse
import os, sys
import json
import numpy as np
import time

import WhiskiWrap as ww
from WhiskiWrap import load_whisker_data as lwd
import whiskerpad as wp
import wt_single_frame as wtsf

# Check that whisk binaries are executables and update permissions if necessary
from wwutils.whisk_permissions import update_permissions
update_permissions()

def estimate_num_whiskers(whisker_scores, whisker_lengths, side_types):
    # Find how many whiskers with scores above 0.5 on each side of the face
    num_whiskers = {}
    for side in side_types:
        print(f'Number of whiskers with scores above 0.2 on {side} side: {np.sum(whisker_scores[side]>0.2)}')
        print(f'Number of whiskers with lengths above 50% of the maximum length on {side} side: {np.sum(whisker_lengths[side]>0.5*np.max(whisker_lengths[side]))}')
        num_whiskers[side] = np.sum((whisker_scores[side]>0.2) & (whisker_lengths[side]>0.5*np.max(whisker_lengths[side])))
        
    return num_whiskers

def estimate_px2mm(whisker_ids, whisker_scores, whisker_lengths, follicle_x, follicle_y, whiskerpad_params, side_types):
    """
    Estimate the px2mm conversion factor using the distance between the follicle of the first two whiskers
    """
    # Keep whisker_ids with score > 0.5 
    keep_whisker_idx = {side: (whisker_scores[side] > 0.2) & (whisker_lengths[side] > 0.5*np.max(whisker_lengths[side])) for side in side_types}
    keep_whisker_ids = {side: whisker_ids[side][keep_whisker_idx[side]] for side in side_types}
    keep_whisker_scores = {side: whisker_scores[side][keep_whisker_idx[side]] for side in side_types}
    keep_whisker_lengths = {side: np.array(whisker_lengths[side])[keep_whisker_idx[side]] for side in side_types}
    keep_follicle_x = {side: np.array(follicle_x[side])[keep_whisker_ids[side]] for side in side_types}
    keep_follicle_y = {side: np.array(follicle_y[side])[keep_whisker_ids[side]] for side in side_types}
        
    # Order them by follicle position from caudal to rostral, using either follicle_x or follicle_y depending on the face orientation and axis
    ordered_whisker_ids = {}
    for side in side_types:
        if whiskerpad_params['whiskerpads'][0]['FaceAxis'] == 'horizontal':
            if whiskerpad_params['whiskerpads'][0]['FaceOrientation'] == 'right':
                ordered_whisker_ids[side] = np.argsort(keep_follicle_x[side])
            else:
                ordered_whisker_ids[side] = np.argsort(keep_follicle_x[side])[::-1]
        else:
            if whiskerpad_params['whiskerpads'][0]['FaceOrientation'] == 'down':
                ordered_whisker_ids[side] = np.argsort(keep_follicle_y[side])
            else:
                ordered_whisker_ids[side] = np.argsort(keep_follicle_y[side])[::-1]

    # Compute the absolute distance between the follicles of the first two whiskers on each side
    distances = {side: np.abs(keep_follicle_x[side][ordered_whisker_ids[side]][1] - keep_follicle_x[side][ordered_whisker_ids[side]][0]) 
                 if whiskerpad_params['whiskerpads'][0]['FaceAxis'] == 'horizontal' 
                 else np.abs(keep_follicle_y[side][ordered_whisker_ids[side]][1] - keep_follicle_y[side][ordered_whisker_ids[side]][0]) 
                 for side in side_types}
    
    # Compute the px2mm conversion factor using the distance and the image coordinates in pixels. 
    # Assume ~1.5mm distance between the two whisker follicles. Use the mean of the two sides.
    fol_dist_mm = 1.5
    fol_dist_px = np.mean([distances[side] for side in side_types])
    # round to 2 decimals
    px2mm = round(fol_dist_mm / fol_dist_px, 2)
    # If the px2mm conversion factor is too high or too low, use default 0.04
    if px2mm < 0.01 or px2mm > 0.15:
        px2mm = 0.04
        print(f'Pixel to mm conversion factor set to default: {px2mm}')
    else:
        print(f'Pixel to mm conversion factor estimated: {px2mm}')
    
    return px2mm

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
    
    # Track whiskers on first frame
    whisker_ids, whisker_lengths, whisker_scores, follicle_x, follicle_y = wtsf.track_whiskers(input_file, whiskerpad_params, splitUp, base_name, output_dir)
    
    # Estimate the number of whiskers to track
    # num_whiskers = estimate_num_whiskers(whisker_scores, whisker_lengths, side_types)
    # Set it to -1 
    num_whiskers = -1 # {side: -1 for side in side_types}
    # Estimate the px2mm conversion factor
    px2mm = estimate_px2mm(whisker_ids, whisker_scores, whisker_lengths, follicle_x, follicle_y, whiskerpad_params, side_types)
    # Classify arguments
    classify_args = {'px2mm': str(px2mm), 'n_whiskers': str(num_whiskers)}
    
    ########################
    ### Run whisker tracking
    ########################

    chunk_size = 200
    
    for side in side_types:
        print(f'Running whisker tracking for {side} face side video')

        # Time the tracking
        start_time_track = time.time()

        # h5_filename = os.path.join(os.path.dirname(input_file), f'{base_name}_{side}.hdf5')
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
                            ww.FFmpegReader(input_file, 
                                            crop = side_im_coord),
                            output_dir,
                            chunk_name_pattern = chunk_name_pattern,
                            chunk_size = chunk_size,
                            output_filename = None,
                            n_trace_processes = nproc, 
                            expected_rows = chunk_size * 15,
                            frame_func = 'crop',
                            skip_stitch = True,
                            face = im_side,
                            # Pass arguments for the classify call
                            classify = classify_args,
                            summary_only = True,
                            skip_existing = True
                        )      

        time_track = time.time() - start_time_track
        print(f'Tracking took {time_track} seconds.')

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