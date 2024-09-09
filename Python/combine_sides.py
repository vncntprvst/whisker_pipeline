"""
This script combines whiskers and measurement files into a single file (formats: csv, parquet, hdf5, zarr).

Example usage:
python combine_sides.py /path/to/input_dir -b base_name -f csv -od /path/to/output_dir
python combine_sides.py /home/wanglab/data/whisker_asym/sc012/test/WT -b sc012_0119_001 -f zarr -od /home/wanglab/data/whisker_asym/sc012/test
"""
    
import os
import glob
# import re
import argparse
import pandas as pd
import numpy as np
import tables
import pyarrow.parquet as pq
import h5py
import json
import time
import logging
from typing import List

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Define sides
default_sides = ['left', 'right', 'top', 'bottom']

def get_files(input_dir: str):
    """
    Get whisker tracking files from the input directory.
    Return the whiskers and measurement files with identified sides.
    """
    wt_formats = ['whiskers', 'hdf5', 'parquet']
    wt_files = []

    # Search for files in the available formats
    for wt_format in wt_formats:
        wt_files = glob.glob(os.path.join(input_dir, f'*.{wt_format}'))
        if wt_files:
            break

    if not wt_files:
        logging.error("No whiskers files found in input directory")
        return [], [], []

    # Identify the sides from the file names
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
        
def read_parquet_file(file):
    """Helper function to read a Parquet file into a Pandas DataFrame"""
    return pq.read_table(file).to_pandas()

def read_hdf5_file(file):
    """Helper function to read an HDF5 file into a Pandas DataFrame"""
    with h5py.File(file, 'r') as f:
        data = f['data'][:]
        df = pd.DataFrame(data)
    return df

def adjust_coordinates(summary, whiskerpad_params):
    """Adjust x and y coordinates using the whiskerpad params."""
    for side, df in summary.items():
        whiskerpad_info = next((pad for pad in whiskerpad_params['whiskerpads'] if pad['FaceSide'].lower() == side), None)
        if whiskerpad_info:
            image_coord = whiskerpad_info['ImageCoordinates']
            # Adjust coordinates for x and y fields
            df['pixels_x'] = df['pixels_x'].apply(lambda x: np.array(x) + image_coord[0])
            df['pixels_y'] = df['pixels_y'].apply(lambda y: np.array(y) + image_coord[1])
            df[['face_x', 'follicle_x', 'tip_x']] += image_coord[0]
            df[['face_y', 'follicle_y', 'tip_y']] += image_coord[1]
    return summary

def combine_sides(wt_files, whiskerpad_file):
    """Combine left and right whisker tracking data by adjusting whisker IDs."""
    summary = {}
    whiskerpad_params = None
    
    if whiskerpad_file:
        with open(whiskerpad_file, 'r') as f:
            whiskerpad_params = json.load(f)

    # Get sides from the whisker tracking files
    sides = [side for file in wt_files for side in default_sides if side in file]
    
    for file, side in zip(wt_files, sides):
        if file.endswith('.parquet'):
            summary[side] = read_parquet_file(file)
        elif file.endswith('.hdf5'):
            summary[side] = read_hdf5_file(file)
        else:
            raise ValueError(f"Unsupported file format: {file}")
    
    if whiskerpad_params:
        summary = adjust_coordinates(summary, whiskerpad_params)

    # Adjust the whisker IDs for the second side
    max_wid_first_side = summary[sides[0]]['wid'].max()
    if len(sides) > 1:
        summary[sides[1]]['wid'] += max_wid_first_side + 1

    # Concatenate all sides
    combined_summary = pd.concat(summary.values(), ignore_index=True)
    
    # Sort combined table by frame id (fid) and whisker id (wid)
    combined_summary = combined_summary.sort_values(by=['fid', 'wid'])

    return combined_summary

def combine_to_file(wt_files, whiskerpad_file, output_file=None, keep_wt_files=False):
    """Combine whisker tracking files and save to the specified format."""
            
    # If output_file is None, use common prefix of the whisker tracking files, and file format of the whisker tracking files
    if output_file is None:
        base_name = os.path.commonprefix([os.path.basename(f) for f in wt_files]).rstrip('_')     
        output_file = os.path.join(os.path.dirname(wt_files[0]), base_name + '.' + wt_files[0].split('.')[-1])
        
    file_format = output_file.split('.')[-1]
        
    # Combine whisker tracking files
    start_time = time.time()
    combined_summary = combine_sides(wt_files, whiskerpad_file)
    
    # Save the combined summary to the output file
    if file_format == 'csv':
        combined_summary.to_csv(output_file, index=False)
    elif file_format == 'parquet':
        combined_summary.to_parquet(output_file, index=False)
    elif file_format == 'hdf5':
        with tables.open_file(output_file, mode='w') as f:
            f.create_table('/', 'summary', obj=combined_summary.to_records(index=False))
    elif file_format == 'zarr':
        combined_summary.to_zarr(output_file)

    # Remove whisker tracking files if keep_wt_files is False
    if not keep_wt_files:
        for f in wt_files:
            os.remove(f)

    logging.info(f"File saved to {output_file}")
    logging.info(f"Time taken: {time.time() - start_time} seconds")

def main():
    """Main function to parse arguments and combine whisker tracking files."""
    parser = argparse.ArgumentParser(description="Combine whiskers files and measurement files into a single file.")
    parser.add_argument("input_dir", help="Path to the directory containing the whiskers and measurement files.")
    parser.add_argument("-b", "--base", help="Base name for output files", type=str)
    parser.add_argument("-f", "--format", help="Output format: 'csv', 'parquet', 'hdf5', 'zarr'.")
    parser.add_argument("-od", "--output_dir", help="Path to save the output file.")
    parser.add_argument("-k", "--keep", help="Keep the whisker tracking files after combining.", action="store_true")
    
    args = parser.parse_args()

    input_dir = args.input_dir
    output_dir = args.output_dir if args.output_dir else input_dir
    
    wt_files, _ = get_files(input_dir)
    if not wt_files:
        raise ValueError("No valid whisker tracking files found.")
    
    base_name = args.base if args.base else os.path.commonprefix([os.path.basename(f) for f in wt_files]).rstrip('_')
    whiskerpad_file = glob.glob(os.path.join(input_dir, f"whiskerpad_{base_name}.json")) + \
                      glob.glob(os.path.join(os.path.dirname(input_dir), f"whiskerpad_{base_name}.json"))
    whiskerpad_file = whiskerpad_file[0] if whiskerpad_file else None
    
    if not args.format:
        args.format = wt_files[0].split('.')[-1]

    output_file = os.path.join(output_dir, f"{base_name}.{args.format}")
    logging.info(f"Output file: {output_file}")

    combine_to_file(wt_files, whiskerpad_file, output_file, args.keep)

if __name__ == "__main__":
    main()
