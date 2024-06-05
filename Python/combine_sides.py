"""
This script combines whiskers and measurement files into a single file (formats: csv, hdf5, npy).

Example usage:
python combine_sides.py /path/to/input_dir -b base_name -ff csv -od /path/to/output_dir -ft midpoint
python combine_sides.py /home/wanglab/data/whisker_asym/sc012/test/WT -b sc012_0119_001 -ff zarr -od /home/wanglab/data/whisker_asym/sc012/test
"""
    
import os
import glob
import re
import argparse
import pandas as pd
import numpy as np
import tables
import zarr
from typing import List, Optional

import WhiskiWrap as ww
from WhiskiWrap import load_whisker_data as lwd
from WhiskiWrap import wfile_io
from WhiskiWrap.mfile_io import MeasurementsTable

import multiprocessing as mp
from joblib import Parallel, delayed
# from threading import Lock
from concurrent.futures import ProcessPoolExecutor
# from filelock import FileLock
import logging

# Set up logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

import time
        
# Define sides
default_sides = ['left', 'right', 'top', 'bottom']

def get_files(input_dir: str):
    """
    Get whiskers and measurement files from input directory. Find which sides are present in the whiskers files.    
    """
    
    whiskers_files = glob.glob(os.path.join(input_dir, '*.whiskers'))
    # Find which sides are present in the whiskers files
    sides = [side for side in default_sides if any(side in f for f in whiskers_files)]
    
    # Initialize list of whiskers and measurement files
    whiskers_files = []
    measurement_files = []
    hdf5_files = []
    
    # Loop through sides
    for side in sides:
        # Add to list of whiskers files and sort them
        whiskers_files = whiskers_files + sorted(glob.glob(os.path.join(input_dir, f'*{side}*.whiskers')))
        # Get measurements files
        measurement_files = measurement_files + sorted(glob.glob(os.path.join(input_dir, f'*{side}*.measurements')))
        # Get hdf5 files
        hdf5_files = hdf5_files + sorted(glob.glob(os.path.join(input_dir, f'*{side}*.hdf5')))

        # print(f"whiskers files: {whiskers_files}")
        # print(f"measurements files: {measurement_files}")

        # Delete the existing output_{side}.h5 file if it exists
        # output_hdf5_file = os.path.join(output_dir, f"output_{side}.hdf5")
        # if os.path.exists(output_hdf5_file):
        #     os.remove(output_hdf5_file)
        # ww.setup_hdf5(output_hdf5_file, 1000000, measure=True)

    # Get base names of whiskers and measurement files
    whiskers_base_names = {os.path.splitext(os.path.basename(f))[0] for f in whiskers_files}
    measurement_base_names = {os.path.splitext(os.path.basename(f))[0] for f in measurement_files}
    # Get matching base names
    matching_base_names = whiskers_base_names.intersection(measurement_base_names)
    # Filter whiskers and measurement files
    filtered_whiskers_files = [f for f in whiskers_files if os.path.splitext(os.path.basename(f))[0] in matching_base_names]
    filtered_measurement_files = [f for f in measurement_files if os.path.splitext(os.path.basename(f))[0] in matching_base_names]
    # Sort filtered whiskers and measurement files
    filtered_whiskers_files = sorted(filtered_whiskers_files)
    filtered_measurement_files = sorted(filtered_measurement_files)

    return filtered_whiskers_files, filtered_measurement_files, hdf5_files, sides

def get_chunk_start(filename: str) -> int:
    match = re.search(r'\d{8}', os.path.basename(filename))
    return int(match.group()) if match else 0
    
# def process_whiskers_files(params, output_file, sides, chunk_size):
#     whiskers_file, measurement_file = params
#     side = [side for side in sides if side in whiskers_file][0]
#     chunk_start = get_chunk_start(whiskers_file)
#     ww.base.append_whiskers_to_zarr(
#         whisk_filename=whiskers_file,
#         zarr_filename=output_file,
#         chunk_start=chunk_start,
#         measurements_filename=measurement_file,
#         face_side=side,
#         chunk_size=(chunk_size,)
#     )


# def process_whiskers_files(params, output_file, sides, chunk_size, queue):
#     whiskers_file, measurement_file = params
#     side = [side for side in sides if side in whiskers_file][0]
#     chunk_start = get_chunk_start(whiskers_file)
#     ww.base.append_whiskers_to_zarr(whiskers_file, output_file, chunk_start, measurement_file, side, (chunk_size,), queue)
def inspect_queue(queue):
    items = []
    while True:
        try:
            item = queue.get_nowait()
            items.append(item)
        except mp.queues.Empty:
            break
    return items

# def process_whiskers_files(params, output_file, sides, chunk_size, queue):
#     logging.debug(f"Processing whiskers files with params: {params}")
#     whiskers_file, measurement_file = params
#     side = [side for side in sides if side in whiskers_file][0]
#     chunk_start = get_chunk_start(whiskers_file)
#     result = ww.base.append_whiskers_to_zarr(whiskers_file, output_file, chunk_start, measurement_file, side, (chunk_size,), True)
#     logging.debug(f"Result prepared: {result}")
#     queue.put(result)
#     logging.debug(f"Result put in queue")

def process_whiskers_files(params, output_file, sides, chunk_size, queue):
    print(f"Processing whiskers files with params: {params}")
    whiskers_file, measurement_file = params
    side = [side for side in sides if side in whiskers_file][0]
    chunk_start = get_chunk_start(whiskers_file)
    result = ww.base.append_whiskers_to_zarr(whiskers_file, output_file, chunk_start, measurement_file, side, (chunk_size,), True)
    print(f"Result prepared: {result}")
    queue.put(result)
    print(f"Result put in queue")
    
def writer_process(queue, output_file, chunk_size):
    logging.debug(f"Opening Zarr file: {output_file}")
    zarr_file = ww.base.initialize_zarr(output_file, chunk_size)
    while True:
        logging.debug(f"Waiting for message")
        message = queue.get()
        logging.debug(f"Received message: {message}")
        if message == 'DONE':
            logging.debug(f"Closing Zarr file: {output_file}")
            break
        summary_data_list, pixels_x_list, pixels_x_indices_list, pixels_y_list, pixels_y_indices_list = message
        
        logging.debug(f"Writing data to Zarr file: {len(summary_data_list)} summary records, {len(pixels_x_list)} pixels_x, {len(pixels_y_list)} pixels_y")
        try:
            if summary_data_list:
                summary_array = np.fromiter((tuple(d.values()) for d in summary_data_list), dtype=zarr_file['summary'].dtype)
                zarr_file['summary'].append(summary_array)
            if pixels_x_list:
                zarr_file['pixels_x'].append(pixels_x_list)
                zarr_file['pixels_x_indices'].append(pixels_x_indices_list)
            if pixels_y_list:
                zarr_file['pixels_y'].append(pixels_y_list)
                zarr_file['pixels_y_indices'].append(pixels_y_indices_list)
                
            # Log current state of the Zarr file
            logging.debug(f"Zarr file summary dataset length: {len(zarr_file['summary'])}")
            logging.debug(f"Zarr file pixels_x dataset length: {len(zarr_file['pixels_x'])}")
            logging.debug(f"Zarr file pixels_y dataset length: {len(zarr_file['pixels_y'])}")
        except Exception as e:
            logging.error(f"Error writing to Zarr file: {e}")
            raise e

def process_wrapper(params, output_file, sides, chunk_size, queue):
    # logging.debug(f"Calling process_whiskers_files with params: {params}")
    print(f"Calling process_whiskers_files with params: {params}")
    process_whiskers_files(params, output_file, sides, chunk_size, queue)
               
def combine_measurement_files(whiskers_files: List[str], measurement_files: List[str], sides: List[str], output_file: str):       
    """ 
    Combine whiskers and measurement files and save to output file.
    """                            

    if output_file.endswith('.hdf5'):
        if os.path.exists(output_file):
            os.remove(output_file)
        ww.setup_hdf5(output_file, 1000000, measure=True)
        
        for whiskers_file, measurement_file in zip(whiskers_files, measurement_files):
            # Get which side the whiskers file is from
            side = [side for side in sides if side in whiskers_file][0]
            # Get chunk start
            chunk_start = get_chunk_start(whiskers_file)
            # Call append_whiskers_to_hdf5 function
            ww.base.append_whiskers_to_hdf5(
                whisk_filename=whiskers_file,
                measurements_filename=measurement_file,
                h5_filename=output_file,
                chunk_start=chunk_start,
                face_side=side)
    
        # Saving to hdf5 file using parallel processing:
        # hdf5 is not thread safe, but data can be processed to temporary files
        # in parallel and then written to the hdf5 file in a single thread.
        # See ww.base.write_whiskers_to_tmp
    
    elif output_file.endswith('.zarr'):
        
        # Get the chunk_size from the whiskers_files file name pattern
        chunk_size = get_chunk_start(whiskers_files[1]) - get_chunk_start(whiskers_files[0])
          
        # Save to zarr file, with regular loop
        # for whiskers_file, measurement_file in zip(whiskers_files, measurement_files):
        #     # Get which side the whiskers file is from
        #     side = [side for side in sides if side in whiskers_file][0]
        #     # Get chunk start
        #     chunk_start = get_chunk_start(whiskers_file)
        #     # Call append_whiskers_to_zarr function
        #     ww.base.append_whiskers_to_zarr(
        #         whiskers_file, output_file, chunk_start, measurement_file, side, (chunk_size,))
                        
        # Save to zarr file, using parallel processing.
        # Warning: for a small number of files, this is much slower than a regular loop. 
        # TODO: find threshold for when to use parallel processing
        # with ProcessPoolExecutor() as executor:
        #     executor.map(lambda params: process_whiskers_files(params, output_file, sides, chunk_size),
        #         zip(whiskers_files, measurement_files)
        #     )
        
        logging.debug(f"Creating writer process")
        queue = mp.Queue()
        
        # Start the writer process
        writer = mp.Process(target=writer_process, args=(queue, output_file, chunk_size))
        writer.start()
        
        # # Process files in parallel
        # with ProcessPoolExecutor() as executor:
        #     executor.map(lambda params: process_whiskers_files(params, output_file, sides, chunk_size, queue),
        #                  zip(whiskers_files, measurement_files))
        # Process files in parallel
        with ProcessPoolExecutor() as executor:
            executor.map(lambda params: process_wrapper(params, output_file, sides, chunk_size, queue),
                         zip(whiskers_files, measurement_files))
            
        # # Process files sequentially
        # for params in zip(whiskers_files, measurement_files):
        #     process_whiskers_files(params, output_file, sides, chunk_size, queue)
            
        # Signal the writer process to finish
        logging.debug(f"Final state of the queue: {inspect_queue(queue)}")
        queue.put('DONE')
        logging.debug(f"Signalling writer process to finish")
        writer.join()
        
        # queue = mp.Queue()
        
        # # Start the writer process
        # writer = mp.Process(target=writer_process, args=(queue, output_file, chunk_size))
        # writer.start()
        
        # # Parallel processing
        # Parallel(n_jobs=-1)(delayed(ww.base.append_whiskers_to_zarr)(
        #     whiskers_file, output_file, get_chunk_start(whiskers_file), measurement_file, 
        #     [side for side in sides if side in whiskers_file][0], (chunk_size,), queue)
        #     for whiskers_file, measurement_file in zip(whiskers_files, measurement_files)
        # )

        # # Signal the writer process to finish
        # queue.put('DONE')
        # writer.join()
        

def combine_hdf5(h5_files: List[str], output_file: str = 'combined.csv') -> None:
    """ Combine hdf5 files into a single hdf5 or csv file.
    """

    # Initialize table to concantenate tables
    combined_table = pd.DataFrame()
    num_wids = 0

    # Loop through hdf5 files
    for h5_file in h5_files:
        table = ww.base.read_whiskers_hdf5_summary(h5_file)
        # print(table.head())
        # size = table.shape[0]

        # Add num_wids to wid column
        table['wid'] = table['wid'] + num_wids

        # Add table to combined table
        combined_table = pd.concat([combined_table, table], ignore_index=True)

        # Find number of unique whisker ids
        unique_wids = combined_table['wid'].unique() 
        num_wids = len(unique_wids)
        print(f"Number of unique whisker ids: {num_wids}")

    # Display unique times
    unique_times = combined_table['fid'].unique()
    num_times = len(unique_times)
    print(f"Number of unique times: {num_times}")

    # Sort combined table by frame id and whisker id
    combined_table = sort_table(combined_table)

    # If output file is hdf5 format, save combined table to hdf5 file
    if output_file.endswith('.hdf5'):
        # Open output hdf5 file
        output_hdf5 = tables.open_file(output_file, mode='w')
        # Create table
        output_hdf5.create_table('/', 'summary', obj=combined_table.to_records(index=False))
        # Close output hdf5 file
        output_hdf5.close()
    elif output_file.endswith('.csv'):
        # Save combined table to csv file
        combined_table.to_csv(output_file, index=False)
        
def sort_table(combined_table: pd.DataFrame):
    """ Sort combined table by frame id and whisker id.
    """
    # Sort combined table by frame id and whisker id
    combined_table = combined_table.sort_values(by=['fid', 'wid'])

    # reorder columns 
    combined_table = combined_table[['fid', 'wid', 'label', 'face_x', 'face_y',
                                    'length', 'pixel_length', 'score', 'angle',
                                    'curvature', 'follicle_x', 'follicle_y',
                                    'tip_x', 'tip_y', 'chunk_start']]
    
    return combined_table
    
def combine_sides(summary):
    """ Combine left and right sides of the face.
    """
    # Concatenate all sides
    combined_summary = pd.concat(summary.values(), ignore_index=True)
    # Sort combined table by frame id and whisker id
    combined_summary = combined_summary.sort_values(by=['fid', 'wid'])

    return combined_summary

def get_midpoints(summary):
    """ Get midpoints of whiskers.
    Input:
    summary: pandas DataFrame
    Returns:
    midpoints: pandas DataFrame
    """
    # Sort summary by frame id and whisker id
    summary = sort_table(summary)
    # # For each frame, find the median angle for each frame
    # median_angles = summary.groupby('fid')['angle'].median()
    # # make it a dataframe with two columns: fid, angle
    # median_angles = median_angles.reset_index()
    # Find the median angle for each frame and keep the face coordinates
    median_angles = summary.groupby('fid').agg({
    'angle': 'median',
    'face_x': 'first',
    'face_y': 'first',
    'length': 'median',
    }).reset_index()
    
    return median_angles


if __name__ == "__main__":  # : -> None
    # Define argument parser
    parser = argparse.ArgumentParser(description="Combine whiskers files and measurement files into a single HDF5 file.")
    parser.add_argument("input_dir", help="Path to the directory containing the whiskers and measurement files.")
    parser.add_argument("-b", "--base", help='Base name for output files', type=str)
    parser.add_argument("-ff", "--format", help="output format", default="csv", choices=["csv", "feather", "hdf5", "zarr"])
    parser.add_argument("-od", "--output_dir", help="Path to the directory to save the output file.")
    parser.add_argument("-ft", "--feature", help="feature to extract", default=None, choices=["midpoint"])
    
    args = parser.parse_args()

    # video_filename = args.video_filename
    # if video_filename is None:
    #     print("No video file provided to substract midline")
    # else:
    #     print("Video file:", video_filename)
    
    # Get input and output directories, and file format 
    input_dir = args.input_dir
    if args.output_dir is None:
        output_dir = input_dir 
    else:
        output_dir = args.output_dir
    file_format = args.format

    # Get whiskers and measurement files
    whiskers_files, measurement_files, hdf5_files, sides = get_files(input_dir)
    
    if args.base is None:
        # Get the common file name part from the whiskers files
        base_name = os.path.commonprefix([os.path.basename(f) for f in whiskers_files])
    else:
        base_name = args.base 
    
    # Define output file, based on video filename and format
    if args.feature is None:
        output_file = os.path.join(output_dir, f"{base_name}.{file_format}")
    else:
        output_file = os.path.join(output_dir, f"{base_name}_{args.feature}.{file_format}")

    print(f"Output file: {output_file}")
    
    # if measurement_files is empty, combine hdf5 files
    if len(measurement_files) == 0:
        # if files have been updated, only combine updated files.
        if any('updated' in f for f in hdf5_files):
            hdf5_files = [f for f in hdf5_files if 'updated' in f]
        combine_hdf5(hdf5_files, output_file)
        
    else:
        if args.feature is None:
                    # Time the process
            start = time.time() 
          
            # If -f is not provided, combine whiskers and measurement files and save to output file
            combine_measurement_files(whiskers_files, measurement_files, sides, output_file)
                    
            print(f"Time taken: {time.time() - start}")
        else:
            # If -f is provided, extract feature and save to output file
            
            # first reassess whisker ids for each side
            side_whiskers_files = {side: [f for f in whiskers_files if side in f] for side in sides}
            
            # Initialize variables
            updated_summary = {}
            # midpoints = {}
            midpoints_df = pd.DataFrame()
            # Define the columns to rename
            cols_to_rename = ['angle', 'face_x', 'face_y', 'length']

            # Loop through sides
            for side, files in side_whiskers_files.items():
                # If the list is not empty, get the summary
                if files:
                    updated_summary[side] = lwd.get_summary(files, filter = True)
                    if args.feature == "midpoint":
                        # get midpoints
                        midpoints = get_midpoints(updated_summary[side])
                        # Rename column names to 'name_{side}'
                        # Create a dictionary mapping from old names to new names
                        rename_dict = {col: f'{col}_{side}' if col != 'angle' else f'midpoint_{side}' for col in cols_to_rename if col in midpoints.columns}
                        # Rename the columns
                        midpoints = midpoints.rename(columns=rename_dict)
                    
                        # Convert the midpoints to a DataFrame and join it with the existing DataFrame
                        if midpoints_df.empty:
                            midpoints_df = pd.DataFrame(midpoints)
                        else:
                            midpoints_df = midpoints_df.merge(pd.DataFrame(midpoints), on='fid', how='outer')

            # Save midpoints to output_file, according to format
            if file_format == "csv":
                midpoints_df.to_csv(output_file, index=False)
            elif file_format == "feather":
                midpoints_df.to_feather(output_file)
            else:
                print("Format not supported")
            
                
            