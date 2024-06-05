import multiprocessing as mp
import logging

# Setup logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

def process_task(task_id, results_list):
    logging.debug(f"Processing task {task_id}")
    result = task_id + 1
    results_list.append((task_id, result))  # Store task_id along with the result
    logging.debug(f"Task {task_id} put result {result} in results_list")

def run_parallel_tasks(num_tasks):
    manager = mp.Manager()
    results_list = manager.list()

    # Process tasks in parallel using multiprocessing.Pool
    pool = mp.Pool()
    results = []
    for task_id in range(num_tasks):
        result = pool.apply_async(process_task, args=(task_id, results_list))
        results.append(result)

    pool.close()
    pool.join()

    # Ensure all tasks are done
    for result in results:
        logging.debug(f"Waiting for result {result}")
        result.wait()

    # Sort results based on task_id
    sorted_results = sorted(results_list, key=lambda x: x[0])
    final_results = [result for task_id, result in sorted_results]
    
    logging.debug(f"Final state of results_list: {final_results}")
    return final_results

if __name__ == "__main__":
    num_tasks = 3  # Adjust the number of tasks for testing
    results = run_parallel_tasks(num_tasks)
    print("Results collected:")
    print(results)
