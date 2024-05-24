"""
Script to track and plot whiskers on the first frame of a video.

Example usage:
input_dir=Path('/data')
video_name='sc016_0630_001_30sWhisking.mp4'
input_file = input_dir / video_name
base_name='sc016_0630_001'
splitUp=True
nproc=40

python wt_single_frame.py input_file --splitUp True --base_name sc016_0630_001

import wt_single_frame as wtsf
wtsf.track_whiskers(input_file, whiskerpad_params, splitUp)

"""
import argparse
# import os, sys
# import json
from pathlib import Path
import numpy as np
import pandas as pd
import cv2
import matplotlib.pyplot as plt
import WhiskiWrap as ww
import whiskerpad as wp

def save_image_halves(image_halves, image_side, face_side, base_name, input_dir, direction, output_dir=None):
    """
    Save image halves as tif files
    """

    # print each image halves side by side
    fig, ax = plt.subplots(1, 2, figsize=(10, 5))
    ax[0].imshow(image_halves[0], cmap='gray')
    ax[0].axis('off')
    ax[0].set_title(f"Face axis: {face_side[0]}, Image side: {image_side[0]}")
    ax[1].imshow(image_halves[1], cmap='gray')
    ax[1].axis('off')
    ax[1].set_title(f"Face axis: {face_side[1]}, Image side: {image_side[1]}")
    plt.show()

    # Save each side as tif
    if output_dir is None:
        output_dir = input_dir / f"frame_0_whiskers"
    output_dir.mkdir(exist_ok=True)
    for i, side in enumerate(image_side):
        output_file = output_dir / f'{base_name}_first_frame_{side}.tif'
        cv2.imwrite(str(output_file), image_halves[i])

    side_types = image_side

    print(f"Side types: {side_types}, direction: {direction}")


def run_whisker_tracking(image_halves, side_types, base_name, output_dir):

    for im_side in side_types:
        # print(f'Running whisker tracking for {im_side} image side video')
        # plt.imshow(image_halves[image_side.index(im_side)], cmap='gray')
        # # plt.imshow(image_halves_rotated[
        # #     rotated_face_side.index(side)], cmap='gray')
        # plt.axis('off')
        # plt.title(f"Face image side: {im_side}")
        # plt.show()

        image_filename = output_dir / f'{base_name}_first_frame_{im_side}.tif' 
        tracking_results = ww.trace_and_measure_chunk(image_filename,
                                                delete_when_done=False,
                                                face=im_side)
        # ,
                                                # classify={'px2mm': '0.04', 'n_whiskers': '3'})
    
    return tracking_results

def load_whisker_data(side_types, base_name, output_dir, save_to_csv=False):
    """
    Load whisker data from whisker files.
    "whiskers" is a list of dictionaries, each dictionary is a frame, each frame has a dictionary of whiskers.
    """
    # Initialize the dictionary to store the whisker data for each side
    whisker_data = {}

    for im_side in side_types:
        print(f'Loading whiskers for {im_side} face side video')
        whisk_filename = output_dir / f'{base_name}_first_frame_{im_side}.whiskers'
        # Load whiskers
        whiskers = ww.wfile_io.Load_Whiskers(str(whisk_filename))
        whisker_data[im_side] = whiskers

    print(f"Whisker data for {len(whisker_data)} sides loaded.")
                
    # Load whisker measurements from measurements file
    wmeas = load_whisker_measurements(output_dir, base_name, side_types)

    # Initialize the dictionaries to store the whisker pixel values for each side
    xpixels, ypixels = {}, {}
    # whisker_ids = {}

    for im_side, whiskers in whisker_data.items():
        # Initialize lists for this side if they don't exist yet
        if im_side not in xpixels:
            xpixels[im_side] = []
        if im_side not in ypixels:
            ypixels[im_side] = []
        # if side not in whisker_ids:
        #     whisker_ids[side] = []
        
        for frame, frame_whiskers in list(whiskers.items()):
            for whisker_id, wseg in list(frame_whiskers.items()):
                # Write whisker contour x and y pixel values
                xpixels[im_side].append(wseg.x)
                ypixels[im_side].append(wseg.y)
                # whisker_ids[side].append(wseg.id)

    # Check how many whiskers were detected for each side
    n_whiskers = {side: len(xpixels[side]) for side in side_types}
    print(f"Number of whiskers detected: {n_whiskers}")
    # print(f"Whisker IDs for each sides: {whisker_ids}")

    # Get unique whisker IDs
    whisker_ids = {side: np.unique([wseg.id for frame_whiskers in whisker_data[side].values() for wseg in frame_whiskers.values()]) for side in side_types}
    print(f"Unique whisker IDs: {whisker_ids}")
    
    # Get whisker lengths
    whisker_lengths, whisker_lengths_meas = compare_whisker_lengths(whisker_data, wmeas, side_types)
    
    # Get whisker scores
    whisker_scores = get_whisker_scores(wmeas, side_types, whisker_lengths)
       
    # Get follicles
    im_orientation = define_image_orientation(side_types)
    follicle_x, follicle_y = get_follicles(wmeas, side_types, im_orientation)
    
    # Create set of colors for each whisker ID
    colors = {side: plt.cm.viridis(np.linspace(0, 1, len(whisker_ids[side]))) for side in side_types}

    for whisker_id, color in zip(whisker_ids[im_side], colors[im_side]):
        print(f"Whisker ID: {whisker_id}, color: {color}")
        
    # Save whisker lengths and scores to csv
    if save_to_csv:
        save_to_csv(output_dir, base_name, side_types, whisker_lengths, whisker_scores)
        
    return xpixels, ypixels, whisker_ids, colors, whisker_lengths, whisker_scores, follicle_x, follicle_y

def load_whisker_measurements(output_dir, base_name, side_types):
    """
    Load whisker measurements from measurements file
    """

    #  Check if measurement file exists
    measurement_file = output_dir / f'{base_name}_first_frame_{im_side}.measurements'
    if measurement_file.exists():
        wmeas = {}

        for im_side in side_types:
            print(f'Loading whisker measurements for {im_side} image side video')
            whisk_filename = output_dir / f'{base_name}_first_frame_{im_side}.whiskers'
            # Load whiskers
            wmeas[im_side] =ww.read_whisker_data(str(whisk_filename))

    print(f"Whisker measurements for {im_side} image side: {wmeas[im_side]}")
    
    return wmeas

def plot_whiskers_on_half_images(image_halves, side_types, whisker_ids, xpixels, ypixels, colors):
    """
    Plot whiskers on each image side
    """
    
    # Plot whiskers on each image

    # define image orientation
    if 'top' in side_types or 'bottom' in side_types:
        im_orientation = 'horizontal'
    elif 'left' in side_types or 'right' in side_types:
        im_orientation = 'vertical'

    if im_orientation == 'horizontal':
        fig, ax = plt.subplots(2, 1, figsize=(10, 5))
        # Remove space between subplots
        plt.subplots_adjust(wspace=0, hspace=-0.05)
    elif im_orientation == 'vertical':
        fig, ax = plt.subplots(1, 2, figsize=(10, 5))
        # Remove space between subplots
        plt.subplots_adjust(wspace=-0.51, hspace=0)

    for i, im_side in enumerate(side_types):
        if im_orientation == 'vertical':
            ax[-(i+1)].imshow(image_halves[i], cmap='gray')
        elif im_orientation == 'horizontal':
            # ax[i].imshow(image_halves_rotated[i], cmap='gray')
            ax[i].imshow(image_halves[i], cmap='gray')
        # for whisker_id, color in zip(whisker_ids[im_side], colors[im_side]):
        for idx, (whisker_id, color) in enumerate(zip(whisker_ids[im_side], colors[im_side])):
            # Get the whisker pixel values for this whisker ID from xpixels and ypixels
            whisker_x = xpixels[im_side][idx] # whisker_id
            whisker_y = ypixels[im_side][idx] # whisker_id
            if im_orientation == 'vertical':
                ax[-(i+1)].plot(whisker_x, whisker_y, color=color)
            elif im_orientation == 'horizontal':
                ax[i].plot(whisker_x, whisker_y, color=color)
        if im_orientation == 'vertical':
            ax[-(i+1)].axis('off')
            ax[-(i+1)].set_title(f"Face image side: {im_side}")
        elif im_orientation == 'horizontal':    
            ax[i].axis('off')
            if i == 0:
                ax[i].set_title(f"Face image side: {im_side}")
            elif i == 1:
                ax[i].text(0.5, -0.1, f"Face image side: {im_side}", size=12, ha="center", transform=ax[i].transAxes)
                        
    plt.show()

def compare_whisker_lengths(whisker_data, wmeas, side_types):
    """
    Compare whisker lengths from whisker data and measurements file
    """
    # as sanity check, for each whisker, (on each side), compute whisker length and compare to the length in the measurements file
    # Initialize the dictionaries to store the whisker lengths for each side
    whisker_lengths, whisker_lengths_meas = {}, {}
    for im_side in side_types:
        # Initialize lists for this side if they don't exist yet
        if im_side not in whisker_lengths:
            whisker_lengths[im_side] = []
        
        for frame, frame_whiskers in list(whisker_data[im_side].items()):
            for whisker_id, wseg in list(frame_whiskers.items()):
                # Compute whisker length
                whisker_length = np.sqrt((wseg.x[-1] - wseg.x[0])**2 + (wseg.y[-1] - wseg.y[0])**2)
                whisker_lengths[im_side].append(whisker_length)

    # Compare whisker lengths to lengths in measurements file
    whisker_lengths_diff={}
    for im_side in side_types:
        if im_side not in whisker_lengths_meas:
            whisker_lengths_meas[im_side] = []
        # Get whisker lengths from measurements file 
        # Sort the whisker lengths according to the sorted indices
        sorted_indices = np.argsort(wmeas[im_side]['label'])
        whisker_lengths_meas[im_side].append(np.array(wmeas[im_side]['length'])[sorted_indices])
        
        # Compare whisker lengths
        whisker_lengths_diff[im_side] = np.array(whisker_lengths[im_side]) - np.array(whisker_lengths_meas[im_side])
                
        # print(f"Mean difference in whisker lengths for {im_side} face side: {np.mean(whisker_lengths_diff)}")
        # print(f"Max difference in whisker lengths for {im_side} face side: {np.max(np.abs(whisker_lengths_diff))}")
        
    # if mean diff is >1 for either side, raise an error
    for im_side in side_types:
        if np.mean(np.abs(whisker_lengths_diff[im_side])) > 1:
            raise ValueError(f"Mean difference between .whisker and .measurement files' whisker lengths for {im_side} face side is greater than 1 pixel.")
        
    # Print arrays
    # print(np.array(whisker_lengths[im_side]))
    # print( np.array(whisker_lengths_meas[im_side]))
    
    return whisker_lengths, whisker_lengths_meas

def get_whisker_scores(wmeas, side_types, whisker_lengths):
    """
    Get whisker scores from whisker measurements
    """
    #  print 'score' for each whisker from measurements data (wmeas), for each side. again, resort by labels
    # Initialize the dictionaries to store the whisker scores for each side
    whisker_scores = {}
    for im_side in side_types:
        # Initialize lists for this side if they don't exist yet
        if im_side not in whisker_scores:
            whisker_scores[im_side] = []
        
        sorted_indices = np.argsort(wmeas[im_side]['label'])
        whisker_scores[im_side].append(np.array(wmeas[im_side]['score'])[sorted_indices])

    # Print whisker scores
    for im_side in side_types:
        print(f"Whisker lengths and scores for {im_side} image side:")
        
        for length, score in zip(whisker_lengths[im_side], whisker_scores[im_side][0]):
            print(f"{length}, {score}")

    # Normalize the scores to be between 0 and 1
    for im_side in side_types:
        whisker_scores[im_side] = np.array(whisker_scores[im_side][0])
        whisker_scores[im_side] = (whisker_scores[im_side] - np.min(whisker_scores[im_side])) / (np.max(whisker_scores[im_side]) - np.min(whisker_scores[im_side]))
        
    return whisker_scores

def define_image_orientation(side_types):
    """
    Define the image orientation based on the side types
    """
    # define image orientation
    if 'top' in side_types or 'bottom' in side_types:
        im_orientation = 'horizontal'
    elif 'left' in side_types or 'right' in side_types:
        im_orientation = 'vertical'
        
    return im_orientation

def get_follicles(wmeas, side_types, im_orientation):
    """
    Get follicles from whisker measurements
    """
    # Get follicles

    follicle_x, follicle_y = {}, {}
    for im_side in side_types:
        # Initialize lists for this side if they don't exist yet
        if im_side not in follicle_x:
            follicle_x[im_side] = []
            follicle_y[im_side] = []
        
        sorted_indices = np.argsort(wmeas[im_side]['label'])
        if im_orientation == 'horizontal':
            follicle_x[im_side].append(np.array(wmeas[im_side]['follicle_x'])[sorted_indices]) #tip_x
            follicle_y[im_side].append(np.array(wmeas[im_side]['follicle_y'])[sorted_indices]) #tip_y
        elif im_orientation == 'vertical':
            follicle_x[im_side].append(np.array(wmeas[im_side]['follicle_x'])[sorted_indices])
            follicle_y[im_side].append(np.array(wmeas[im_side]['follicle_y'])[sorted_indices])

    # Flatten the lists
    for im_side in side_types:
        follicle_x[im_side] = np.concatenate(follicle_x[im_side])
        follicle_y[im_side] = np.concatenate(follicle_y[im_side])
        
    return follicle_x, follicle_y

def save_to_csv(output_dir, base_name, side_types, whisker_lengths, whisker_scores):

    # Save whisker lengths and scores to csv
    for im_side in side_types:
        output_file = output_dir / f'{base_name}_first_frame_{im_side}_whisker_lengths_scores.csv'
        # Convert whisker lengths and scores to dataframe and save
        data = {'length': whisker_lengths[im_side], 'score': whisker_scores[im_side]}
        df = pd.DataFrame(data)
        df.to_csv(output_file, index=False)
        
def plot_whiskers_on_image(image_halves, side_types, direction, follicle_x, follicle_y, whisker_ids, whisker_scores, xpixels, ypixels, colors, base_name, output_dir):
    """
    Plot whiskers for each side on the whole image
    """

    # define image orientation
    if 'top' in side_types or 'bottom' in side_types:
        im_orientation = 'horizontal'
    elif 'left' in side_types or 'right' in side_types:
        im_orientation = 'vertical'

    # Plot whiskers on each image
    if im_orientation == 'vertical':
        fig, ax = plt.subplots(1, 2, figsize=(10, 5))
        # Remove space between subplots
        plt.subplots_adjust(wspace=-0.51, hspace=0)
    elif im_orientation == 'horizontal':
        fig, ax = plt.subplots(2, 1, figsize=(10, 5))
        # Remove space between subplots
        plt.subplots_adjust(wspace=0, hspace=-0.05)

    for i, im_side in enumerate(side_types):
        if im_orientation == 'vertical':
            if direction == 'north':
                ax[i].imshow(image_halves[i], cmap='gray')
            elif direction == 'south':
                ax[-(i+1)].imshow(image_halves[i], cmap='gray')
        elif im_orientation == 'horizontal':
            # ax[i].imshow(image_halves_rotated[i], cmap='gray')
            if direction == 'east':
                ax[i].imshow(image_halves[i], cmap='gray')
            elif direction == 'west':
                ax[-(i+1)].imshow(image_halves[i], cmap='gray')

        # Plot the follicles (follicle_x, follicle_y) as circles of the same color as 
        # the corresponding whisker, with intensity defined by whisker scores
        for fx, fy, score, color in zip(follicle_x[im_side],
                                        follicle_y[im_side],
                                        whisker_scores[im_side],
                                        colors[im_side]):
            # If the score is below 0.5, set the color to red
            if score < 0.5:
                color = 'red'
                alpha_level = 0.1
            else:
                alpha_level = score
            if im_orientation == 'vertical':
                if direction == 'north':
                    ax[i].scatter(fx, fy, s=100, c=[color], alpha=alpha_level)
                elif direction == 'south':
                    ax[-(i+1)].scatter(fx, fy, s=100, c=[color], alpha=alpha_level)
            elif im_orientation == 'horizontal':
                if direction == 'east':
                    ax[i].scatter(fx, fy, s=100, c=[color], alpha=alpha_level)
                if direction == 'west':
                    ax[-(i+1)].scatter(fx, fy, s=100, c=[color], alpha=alpha_level)

        # Plot the whiskers
        # for whisker_id, score, color in zip(whisker_ids[im_side],
        #                              whisker_scores[im_side],
        #                              colors[im_side]):
        for idx, (whisker_id, score, color) in enumerate(zip(whisker_ids[im_side],
                                                                whisker_scores[im_side],
                                                                colors[im_side])):
            # Get the whisker pixel values for this whisker ID from xpixels and ypixels
            whisker_x = xpixels[im_side][idx] #whisker_id
            whisker_y = ypixels[im_side][idx] #whisker_id
            # If the score is below 0.5, set the color to red
            if whisker_scores[im_side][idx] < 0.5:
                color = 'red'
                alpha_level = 0.1
                # print(f"Whisker ID {whisker_id} for {side} face side has a score of {whisker_scores[side][whisker_id]}.")
            else:
                alpha_level = score
            # alpha_level = 1
            if im_orientation == 'vertical':
                if direction == 'north':
                    ax[i].plot(whisker_x, whisker_y, color=color, alpha=alpha_level)
                elif direction == 'south':
                    ax[-(i+1)].plot(whisker_x, whisker_y, color=color, alpha=alpha_level)
            elif im_orientation == 'horizontal':
                if direction == 'east':
                    ax[i].plot(whisker_x, whisker_y, color=color, alpha=alpha_level)
                elif direction == 'west':
                    ax[-(i+1)].plot(whisker_x, whisker_y, color=color, alpha=alpha_level)

        if im_orientation == 'vertical':
            ax[-(i+1)].axis('off')
            ax[-(i+1)].set_title(f"Face image side: {im_side}")
        elif im_orientation == 'horizontal':
            # ax[i].axis('off')
            ax[-(i+1)].axis('off')
            if i == 1:
                # ax[i].set_title(f"Face image side: {im_side}")
                ax[-(i+1)].set_title(f"Face image side: {im_side}")
            elif i == 0:
                # ax[i].text(0.5, -0.1, f"Face side: {im_side}", size=12, ha="center", transform=ax[i].transAxes)
                ax[-(i+1)].text(0.5, -0.1, f"Face side: {im_side}", size=12, ha="center", transform=ax[-(i+1)].transAxes)
            
    plt.show()

    # save the figure
    output_file = output_dir / f'{base_name}_first_frame_{im_side}_{direction}_whiskers_scores.png'
    fig.savefig(output_file, bbox_inches='tight', dpi=300)


def track_whiskers(input_file, whiskerpad_params, splitUp, base_name=None, output_dir=None):
    """
    Track whiskers on the first frame of a video
    """

    input_dir = Path(input_file).parent

    if base_name is None:
        base_name = Path(input_file).stem

    # Save image halves as tif files
    image_halves, image_sides, face_side, fp = wp.get_side_image(str(input_file), splitUp)
    if fp.FaceOrientation == 'down':
        direction='south'
    elif fp.FaceOrientation == 'up':
        direction='north'
    elif fp.FaceOrientation == 'left':
        direction='west'
    elif fp.FaceOrientation == 'right':
        direction='east'

    face_side = whiskerpad_params.ImageBorderAxis

    save_image_halves(image_halves, image_sides, face_side, base_name, input_dir, direction, output_dir)
    
    # Run the whisker tracking
    run_whisker_tracking(image_halves, image_sides, base_name, output_dir)
    
    # Load the whisker data
    xpix, ypix, whisker_ids, colors, whisker_lengths, whisker_scores, follicle_x, follicle_y = load_whisker_data(image_sides, base_name, output_dir, save_to_csv=True)
    
    # Plot whiskers over the image for each side 
    plot_whiskers_on_image(image_halves, image_sides, direction, follicle_x, follicle_y, whisker_ids, whisker_scores, xpix, ypix, colors, base_name, output_dir)
    

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Track whiskers on first frame of video')
    parser.add_argument('input_file', type=str, help='Input video file')
    parser.add_argument('whiskerpad_params', type=str, help='Whiskerpad parameters json file')
    parser.add_argument('-s','--splitUp', type=bool, default=False, help='Whether to split up the video')
    parser.add_argument('-b','--base_name', type=str, default=None, help='Base name for the output files')
    parser.add_argument('-o', '--output_dir', type=str, default=None, help='Output directory')
    args = parser.parse_args()

    track_whiskers(args.input_file, args.whiskerpad_params, args.splitUp, args.base_name, args.output_dir)