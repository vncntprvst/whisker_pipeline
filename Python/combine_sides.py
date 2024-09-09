"""
This script combines whiskers and measurement files into a single file (formats: csv, parquet, hdf5, zarr).

Example usage:
python combine_sides.py /path/to/input_dir -b base_name -f csv -od /path/to/output_dir
python combine_sides.py /home/wanglab/data/whisker_asym/sc012/test/WT -b sc012_0119_001 -f zarr -od /home/wanglab/data/whisker_asym/sc012/test
"""
    
import os
import glob
import re
import argparse
import pandas as pd
import numpy as np
import tables
import pyarrow.parquet as pq
import h5py
import json
from typing import List 
import WhiskiWrap as ww
import multiprocessing as mp
import logging

# Set up logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

import time
        
# Define sides
default_sides = ['left', 'right', 'top', 'bottom']

def get_files(input_dir: str):
    """
    Get whisker tracking files (e.g., whiskers and measurement) from input directory.
    Find which sides are present in the whiskers files.
    """
    
    wt_formats = ['whiskers', 'hdf5', 'parquet']

    # Check for files in the directory with available formats
    wt_files = []
    for wt_format in wt_formats:
        wt_files = glob.glob(os.path.join(input_dir, f'*.{wt_format}'))
        if wt_files:
            break

    if not wt_files:
        print("No whiskers files found in input directory")
        return [], [], []
    
    # Find which sides are present in the whisker tracking files
    sides = [side for side in default_sides if any(side in f for f in wt_files)]

    if wt_format == 'whiskers':
        # Initialize list of measurement files
        measurement_files = []

        # Loop through sides to gather measurements
        for side in sides:
            measurement_files += sorted(glob.glob(os.path.join(input_dir, f'*{side}*.measurements')))

        # Get base names and filter matching whiskers and measurement files
        whiskers_base_names = {os.path.splitext(os.path.basename(f))[0] for f in wt_files}
        measurement_base_names = {os.path.splitext(os.path.basename(f))[0] for f in measurement_files}
        matching_base_names = whiskers_base_names.intersection(measurement_base_names)

        # Filter and sort whiskers and measurement files
        filtered_whiskers_files = sorted(f for f in wt_files if os.path.splitext(os.path.basename(f))[0] in matching_base_names)
        filtered_measurement_files = sorted(f for f in measurement_files if os.path.splitext(os.path.basename(f))[0] in matching_base_names)

        return filtered_whiskers_files, sides, filtered_measurement_files

    # For 'hdf5' or 'parquet', return the file list and sides
    return wt_files, sides

    
def get_chunk_start(filename: str) -> int:
    match = re.search(r'\d{8}', os.path.basename(filename))
    return int(match.group()) if match else 0
    
def inspect_queue(queue):
    items = []
    while True:
        try:
            item = queue.get_nowait()
            items.append(item)
        except mp.queues.Empty:
            break
    return items

def process_whiskers_files(params, output_file, sides, chunk_size, queue):
    """
    Process whiskers files in parallel.
    """
    print(f"Processing whiskers files with params: {params}")
    whiskers_file, measurement_file = params
    side = [side for side in sides if side in whiskers_file][0]
    chunk_start = get_chunk_start(whiskers_file)
    result = ww.base.append_whiskers_to_zarr(whiskers_file, output_file, chunk_start, measurement_file, side, (chunk_size,), True)
    print(f"Result prepared for {whiskers_file}")
    queue.put(result)
    print(f"Result put in queue")
    
def writer_process(queue, output_file, chunk_size):
    """
    Write data to Zarr file.
    """    
    logging.debug(f"Opening Zarr file: {output_file}")
    zarr_file = ww.base.initialize_zarr(output_file, chunk_size)
    while True:
        logging.debug(f"Waiting for message")
        message = queue.get()
        logging.debug(f"Received message")
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
            
        # Process files sequentially
        for params in zip(whiskers_files, measurement_files):
            process_whiskers_files(params, output_file, sides, chunk_size, queue)
            
        # Signal the writer process to finish
        # logging.debug(f"Final state of the queue: {inspect_queue(queue)}")
        queue.put('DONE')
        logging.debug(f"Signalling writer process to finish")
        writer.join()
                

def combine_hdf5(h5_files: List[str], output_file: str = 'combined.csv') -> None:
    """ 
    Combine hdf5 files into a single hdf5 or csv file.
    """

    # Initialize table to concatenate tables
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
    """ 
    Sort combined table by frame id and whisker id.
    """
    # Sort combined table by frame id and whisker id
    combined_table = combined_table.sort_values(by=['fid', 'wid'])

    # reorder columns 
    combined_table = combined_table[['fid', 'wid', 'label', 'face_x', 'face_y',
                                    'length', 'pixel_length', 'score', 'angle',
                                    'curvature', 'follicle_x', 'follicle_y',
                                    'tip_x', 'tip_y', 'chunk_start']]
    
    return combined_table
    
# def combine_sides(summary):
#     """ 
#     Combine left and right sides of the face.
#     """
#     # Concatenate all sides
#     combined_summary = pd.concat(summary.values(), ignore_index=True)
#     # Sort combined table by frame id and whisker id
#     combined_summary = combined_summary.sort_values(by=['fid', 'wid'])

#     return combined_summary

def read_parquet_file(file):
    """ Helper function to read a Parquet file into a Pandas DataFrame """
    return pq.read_table(file).to_pandas()

def read_hdf5_file(file):
    """ Helper function to read an HDF5 file into a Pandas DataFrame """
    with h5py.File(file, 'r') as f:
        # Assuming the HDF5 file contains a single dataset named 'data'
        data = f['data'][:]
        df = pd.DataFrame(data)
    return df

def adjust_coordinates(summary, whiskerpad_params):
    """
    Adjust the _x and _y fields in the summary DataFrame 
    by adding the image coordinates from the whiskerpad_params.
    """
    for side, df in summary.items():
        # Find the corresponding whiskerpad information for the side
        whiskerpad_info = next((pad for pad in whiskerpad_params['whiskerpads'] if pad['FaceSide'].lower() == side), None)
        
        if whiskerpad_info:
            image_coord = whiskerpad_info['ImageCoordinates']
            
            # Apply the image coordinate offsets to _x and _y fields
            df['pixels_x'] = df['pixels_x'].apply(lambda x: np.array(x) + image_coord[0])
            df['pixels_y'] = df['pixels_y'].apply(lambda y: np.array(y) + image_coord[1])
            df['face_x'] += image_coord[0]
            df['face_y'] += image_coord[1]
            df['follicle_x'] += image_coord[0]
            df['follicle_y'] += image_coord[1]
            df['tip_x'] += image_coord[0]
            df['tip_y'] += image_coord[1]            

    return summary

def combine_sides(wt_files, whiskerpad_file):
    """ 
    Combine left and right whisker tracking data from Parquet or HDF5 files 
    by adjusting whisker IDs.
    
    Parameters:
    - wt_files: A list of whisker tracking files (left and right).
    
    Returns:
    - combined_summary: A DataFrame with adjusted whisker IDs and combined data.
    """
    summary = {}
    whiskerpad_params = None
    
    # If whiskerpad file is found, load it
    if whiskerpad_file is not None:
        # Use json.load to load the whiskerpad file. There should be only one whiskerpad file. In it, there are two whiskerpads, one for each side.
        with open(whiskerpad_file, 'r') as f:
            whiskerpad_params = json.load(f)           
    
    # Get sides from whisker tracking file names
    sides = [side for file in wt_files for side in default_sides if side in file]
    
    # Load each file and store in a dictionary based on format (parquet or hdf5)    
    for file, side in zip(wt_files, sides):
        if file.endswith('.parquet'):
            summary[side] = read_parquet_file(file)
        elif file.endswith('.hdf5'):
            summary[side] = read_hdf5_file(file)
        else:
            raise ValueError(f"Unsupported file format: {file}")
        
    # Adjust coordinates based on the whiskerpad params if available
    if whiskerpad_params is not None:
        summary = adjust_coordinates(summary, whiskerpad_params)

    # Get the maximum whisker ID from the first side
    max_wid_first_side = summary[sides[0]]['wid'].max()
    
    # Adjust the whisker IDs for the right side
    if len(sides) > 1:
        summary[sides[1]]['wid'] += max_wid_first_side + 1

    # Concatenate all sides
    combined_summary = pd.concat(summary.values(), ignore_index=True)
    
    # Sort combined table by frame id (fid) and whisker id (wid)
    combined_summary = combined_summary.sort_values(by=['fid', 'wid'])

    return combined_summary

if __name__ == "__main__":  # : -> None
    # Define argument parser
    parser = argparse.ArgumentParser(description="Combine whiskers files and measurement files into a single HDF5 file.")
    parser.add_argument("input_dir", help="Path to the directory containing the whiskers and measurement files.")
    parser.add_argument("-b", "--base", help='Base name for output files', type=str)
    parser.add_argument("-f", "--format", help="output format, among 'csv', 'parquet', 'hdf5', 'zarr'. Default is the same format as the whiskers files.")
    parser.add_argument("-od", "--output_dir", help="Path to the directory to save the output file.")
    parser.add_argument("-k", "--keep", help="Keep the whisker tracking files after combining them.", action="store_true")
    
    args = parser.parse_args()
    
    # Get input and output directories, and file format 
    input_dir = args.input_dir
            
    if args.output_dir is None:
        output_dir = input_dir 
    else:
        output_dir = args.output_dir
        
    # Get whisker tracking files
    files_result = get_files(input_dir)
    if len(files_result) == 3:
        # Got whiskers and measurement files from the whisker tracking directory
        wt_files, sides, measurement_files = files_result
    elif len(files_result) == 2:
        # Got whisker tracking files from the main directory
        wt_files, sides = files_result
    else:
        raise ValueError("Unexpected number of return values from get_files")
    
    if args.base is None:
        # Get the common file name part from the whiskers files
        base_name = os.path.commonprefix([os.path.basename(f) for f in wt_files])
        # Remove any trailing underscores
        base_name = base_name.rstrip('_')
    else:
        base_name = args.base 
        
    # Look for the whiskerpad file in the input's parent directory and its subdirectories
    whiskerpad_file = glob.glob(os.path.join(input_dir, f"whiskerpad_{base_name}.json")) + \
                    glob.glob(os.path.join(os.path.dirname(input_dir), f"whiskerpad_{base_name}.json"))
    whiskerpad_file = whiskerpad_file[0] if whiskerpad_file else None
        
    if args.format is None:
        # Use the same format as the whiskers files
        file_format = wt_files[0].split('.')[-1]
    
    output_file = os.path.join(output_dir, f"{base_name}.{file_format}")

    print(f"Output file: {output_file}")
    
    # Time the process
    start = time.time() 
        
    if len(files_result) == 2:
        # If chunks have been stitched, combine sides and save to output file
        # if wt_files[0].endswith('.hdf5'):
        #     # if files have been updated, only combine updated files.
        #     if any('updated' in f for f in wt_files):
        #         wt_files = [f for f in wt_files if 'updated' in f]
        #     combine_hdf5(wt_files, output_file)
        # elif wt_files[0].endswith('.parquet'):
        
        combined_summary = combine_sides(wt_files, whiskerpad_file)
        
        # Then save to file in the specified format
        if file_format == 'csv':
            combined_summary.to_csv(output_file, index=False)
        elif file_format == 'parquet':
            combined_summary.to_parquet(output_file, index=False)
        elif file_format == 'hdf5':
            # Save to hdf5 file
            with tables.open_file(output_file, mode='w') as f:
                f.create_table('/', 'summary', obj=combined_summary.to_records(index=False))
        elif file_format == 'zarr':
            # Save to zarr file
            combined_summary.to_zarr(output_file)            
                       
    else:
        # If whiskers and measurement files are present (meaning chunks haven't been stitched), combine those files
        combine_measurement_files(wt_files, measurement_files, sides, output_file)
        
    if not args.keep:
        # Remove whisker tracking files after combining them
        if len(files_result) == 2:
            for f in wt_files:
                os.remove(f)
        else:
            # remove the entire directory
            os.rmdir(input_dir)    
                
    print(f"Time taken: {time.time() - start}")

            