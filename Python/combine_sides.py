import os
import glob
import re
import argparse
import pandas
import numpy as np
import tables
from typing import List, Optional
import WhiskiWrap
from WhiskiWrap.base import read_whiskers_hdf5_summary
from WhiskiWrap import load_whisker_data as lwd

def get_files(input_dir: str):
    # Initialize list of whiskers and measurement files
    whiskers_files = []
    measurement_files = []
    hdf5_files = []

    # Define sides
    sides = ['left', 'right', 'top', 'bottom']
    
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
        # WhiskiWrap.setup_hdf5(output_hdf5_file, 1000000, measure=True)

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

    return filtered_whiskers_files, filtered_measurement_files, hdf5_files

def get_chunk_start(filename: str) -> int:
    match = re.search(r'\d{8}', os.path.basename(filename))
    return int(match.group()) if match else 0

def combine_measurement_files(filtered_whiskers_files: List[str], filtered_measurement_files: List[str], output_hdf5_file: str, output_csv_file: str, video_filename: Optional[str]=None):
    # print(f"Output CSV file: {output_csv_file}")
    for (whiskers_file, measurement_file) in enumerate(zip(filtered_whiskers_files, filtered_measurement_files)):
        chunk_start = get_chunk_start(whiskers_file)
        
        WhiskiWrap.base.append_whiskers_to_hdf5(
            whisk_filename=whiskers_file,
            measurements_filename=measurement_file,
            h5_filename=output_hdf5_file,
            chunk_start=chunk_start)

def combine_hdf5(h5_files: List[str], output_file: str = 'combined.csv') -> None:
    """ Combine hdf5 files into a single hdf5 or csv file.
    """

    # Initialize table to concantenate tables
    combined_table = pandas.DataFrame()
    num_wids = 0

    # Loop through hdf5 files
    for h5_file in h5_files:
        table = read_whiskers_hdf5_summary(h5_file)
        # print(table.head())
        # size = table.shape[0]

        # Add num_wids to wid column
        table['wid'] = table['wid'] + num_wids

        # Add table to combined table
        combined_table = pandas.concat([combined_table, table], ignore_index=True)

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
        
def sort_table(combined_table: pandas.DataFrame):
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
    combined_summary = pandas.concat(summary.values(), ignore_index=True)
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
    # For each frame, find the median angle for each frame
    median_angles = summary.groupby('fid')['angle'].median()

    return median_angles


# Create main function 
if __name__ == "__main__":  # : -> None

    # Define argument parser
    parser = argparse.ArgumentParser(description="Combine whiskers files and measurement files into a single HDF5 file.")
    parser.add_argument("input_dir", help="Path to the directory containing the whiskers and measurement files.")
    parser.add_argument("video_filename", help="video file name")
    parser.add_argument("format", help="output format", default="csv")
    parser.add_argument("-o", "--output_dir", help="Path to the directory to save the output file.")
    parser.add_argument("-f", "--feature", help="feature to extract", default="midpoint")
    
    args = parser.parse_args()

    video_filename = args.video_filename
    if video_filename is None:
        print("No video file provided to substract midline")
    else:
        print("Video file:", video_filename)

    input_dir = args.input_dir
    if args.output_dir is None:
        output_dir = input_dir 
    else:
        output_dir = args.output_dir
    format = args.format

    # Define output file, based on video filename and format
    if args.feature is None:
        output_file = os.path.join(output_dir, f"{os.path.splitext(video_filename)[0]}.{format}")
    else:
        output_file = os.path.join(output_dir, f"{os.path.splitext(video_filename)[0]}_{args.feature}.{format}")

    print(f"Output file: {output_file}")

    # Get whiskers and measurement files
    whiskers_files, measurement_files, hdf5_files = get_files(input_dir)

    # if measurement_files is empty, combine hdf5 files
    if len(measurement_files) == 0:
        # if files have been updated, only combine updated files.
        if any('updated' in f for f in hdf5_files):
            hdf5_files = [f for f in hdf5_files if 'updated' in f]
        
        combine_hdf5(hdf5_files, output_file)
    else:
        # if -f is not provided, combine whiskers and measurement files and save to output file
        if args.feature is None:
            combine_measurement_files(whiskers_files, measurement_files, output_file, video_filename=video_filename)
        else:
            # if -f is provided, extract feature and save to output file
            # first reassess whisker ids for each side
            sides = ['left', 'right']
            side_whiskers_files = {side: [f for f in whiskers_files if side in f] for side in sides}
            updated_summary = {}
            midpoints = {}
            for side, files in side_whiskers_files.items():
                # If the list is not empty, get the summary
                if files:
                    updated_summary[side] = lwd.get_summary(files, filter = True)
                    if args.feature == "midpoint":
                    # get midpoints
                        midpoints[side] = get_midpoints(updated_summary[side])

            # then combine data
            # combined_summary = combine_sides(updated_summary)
            # Save midpoints to output_file, according to format
            if format == "csv":
                midpoints.to_csv(output_file, index=True)
            elif format == "hdf5":
                midpoints.to_hdf(output_file, key='midpoints', mode='w')
            elif format == "npy":
                np.save(output_file, midpoints.values)
            else:
                print("Format not supported")
            
                
            