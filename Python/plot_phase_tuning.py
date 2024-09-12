import numpy as np
import matplotlib.pyplot as plt

def plot_phase_tuning(phase, spike_times, spike_times_index, b_timestamps, phase_tuning, phase_stats, num_bins=32):
    """
    Plot phase tuning curves for all units using phase data and spike times.
    
    Parameters:
    - phase: np.ndarray
        The phase of the behavior signal (radians).
    - spike_times: np.ndarray
        The spike times for all units.
    - spike_times_index: np.ndarray
        Index pointing to the spikes for each unit.
    - b_timestamps: np.ndarray
        The timestamps of the behavioral data, needed for spike time alignment.
    - phase_tuning: list
        Tuning properties for each unit.
    - phase_stats: list
        Phase statistics (mean, variance, p-values).
    - num_bins: int
        Number of phase bins to plot.
    """
    
    # Define colors for units
    cmap = plt.cm.get_cmap("viridis", len(spike_times_index) - 1)
    
    # Loop through each unit and plot
    for unit_num in range(len(spike_times_index) - 1):
        unit_spike_times = spike_times[spike_times_index[unit_num]:spike_times_index[unit_num + 1]]
        if len(unit_spike_times) < 10:  # Ignore units with very few spikes
            continue
        
        unit_tuning = phase_tuning[unit_num]
        mean_phase = phase_stats[unit_num][0]  # Extract mean phase
        p_value = phase_stats[unit_num][2]  # p-value
        
        # Bin edges and centers for the phase histogram
        edges = np.linspace(-np.pi, np.pi, num_bins + 1)
        centers = (edges[:-1] + edges[1:]) / 2
        
        # Create a figure for each unit
        fig, axs = plt.subplots(2, 2, figsize=(12, 10))
        ax_pdf = axs[1, 1]  # PDF plot
        ax_rate = axs[1, 0]  # Spike rate plot
        ax_polar = plt.subplot2grid((2, 2), (0, 0), colspan=2, projection='polar')  # Polar histogram plot
        
        # Plot PDF of phase for spiking events
        spike_phase_pdf, _ = np.histogram(unit_tuning, bins=edges, density=False)
        phase_pdf, _ = np.histogram(phase, bins=edges, density=False)

        # Normalize PDFs (avoid division by zero)
        if np.sum(spike_phase_pdf) > 0:
            spike_phase_pdf = spike_phase_pdf / np.sum(spike_phase_pdf)
        if np.sum(phase_pdf) > 0:
            phase_pdf = phase_pdf / np.sum(phase_pdf)

        # Plot PDFs if they are not empty
        if np.any(spike_phase_pdf):
            ax_pdf.plot(centers, spike_phase_pdf, color=cmap(unit_num), linewidth=1.2, label=f'Unit {unit_num}')
        if np.any(phase_pdf):
            ax_pdf.plot(centers, phase_pdf, '--', color='gray', linewidth=1.2)

        # Plot average spike rate for each phase bin
        mean_spike_rate = spike_phase_pdf * 1000  # Convert to rate in Hz
        if np.any(mean_spike_rate):
            ax_rate.plot(centers, mean_spike_rate, color=cmap(unit_num), label=f'Unit {unit_num}')
        
        # Polar histogram (if significant phase tuning)
        if p_value < 0.05 and np.any(spike_phase_pdf):
            ax_polar.plot(centers, spike_phase_pdf, label=f'Unit {unit_num}')

        # Customize and display plots
        ax_pdf.set_title('Probability Density Function of Phase for Spiking Events')
        ax_pdf.set_xlabel('Phase (radians)')
        ax_pdf.set_ylabel('Probability Density')
        ax_pdf.legend()
        
        ax_rate.set_title('Average Spike Rate across Phase')
        ax_rate.set_xlabel('Phase (radians)')
        ax_rate.set_ylabel('Spike Rate (Hz)')
        
        ax_polar.set_title(f'Phase Tuning Polar Histogram - Unit {unit_num}')
        
        plt.tight_layout()
        
        # Save the figure
        plt.savefig(f'unit_{unit_num}_phase_tuning.png')
        
        plt.close(fig)