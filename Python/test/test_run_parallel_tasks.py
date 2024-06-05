import multiprocessing as mp
import logging
import glob
import os
import time

# Setup logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

# Placeholder for the function to process whiskers files
def process_whiskers_files(params, output_file, sides, chunk_size, results_list):
    whiskers_file, measurement_file = params
    logging.debug(f"Processing whiskers file: {whiskers_file}, measurement file: {measurement_file}")
    
    # Simulated processing
    result = f"Processed {whiskers_file} and {measurement_file}"
    
    # Append result to the shared list
    results_list.append(result)
    logging.debug(f"Appended result: {result}")

# Function to run parallel tasks
def run_parallel_tasks(whiskers_files, measurement_files, output_file, sides, chunk_size):
    manager = mp.Manager()
    results_list = manager.list()

    # Process tasks in parallel using multiprocessing.Pool
    pool = mp.Pool()
    results = []
    for params in zip(whiskers_files, measurement_files):
        result = pool.apply_async(process_whiskers_files, args=(params, output_file, sides, chunk_size, results_list))
        results.append(result)

    pool.close()
    pool.join()

    # Ensure all tasks are done
    for result in results:
        logging.debug(f"Waiting for result {result}")
        result.wait()

    logging.debug(f"Final state of results_list: {list(results_list)}")
    return list(results_list)

if __name__ == "__main__":
    # Example arguments, replace with actual values as needed
    input_dir = "/path/to/input_dir"
    output_file = "/path/to/output_file"
    sides = ['left', 'right']
    chunk_size = 1000
    
    # Get whiskers and measurement files (placeholder function)
    def get_files(input_dir):
        # Simulated file lists
        whiskers_files = [f"{input_dir}/file_{i}.whiskers" for i in range(3)]
        measurement_files = [f"{input_dir}/file_{i}.measurements" for i in range(3)]
        return whiskers_files, measurement_files, sides

    whiskers_files, measurement_files, sides = get_files(input_dir)
    
    results = run_parallel_tasks(whiskers_files, measurement_files, output_file, sides, chunk_size)
    
    print("Results collected:")
    print(results)
