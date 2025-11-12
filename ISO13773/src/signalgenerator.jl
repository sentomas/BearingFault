using CSV
using DataFrames
using Random

# --- CONFIGURATION (Matches your ISO13373 defaults) ---
fs = 20000.0       # Sampling Hz
T = 2.0            # Duration (seconds)
rpm = 1780.0       # Speed
f_r = rpm / 60     # 29.67 Hz
bpfo_target = 88.5 # This is roughly the BPFO for 9 balls, 1780 RPM
resonance = 4000.0 # Resonance frequency (Hz)

# --- GENERATE DATA ---
N = Int(T * fs)
t = range(0, stop=T, length=N)

# 1. Background Shaft Rotation (Sine wave)
sig_1x = 0.5 .* sin.(2 * π * f_r .* t)

# 2. Fault Impacts (Impulses at BPFO)
impact_train = zeros(N)
samples_per_impact = fs / bpfo_target
for i in 1:floor(Int, T * bpfo_target)
    idx = floor(Int, i * samples_per_impact)
    if idx > 0 && idx <= N
        impact_train[idx] = 1.0
    end
end

# 3. Ringing (Convolve impacts with resonance)
# This simulates the "ping" sound of the bearing hitting the defect
decay_time = 0.005 # 5ms decay
decay_samples = Int(decay_time * fs)
t_decay = (0:decay_samples-1) / fs
ringing_pulse = exp.(-t_decay .* 800) .* sin.(2 * π * resonance .* t_decay)

# Perform convolution (this makes the impacts look like vibration)
import DSP
sig_fault = DSP.conv(impact_train, ringing_pulse)[1:N]
sig_fault = sig_fault ./ maximum(abs.(sig_fault)) # Normalize to 1.0

# 4. Add Noise
noise = 0.3 .* randn(N)

# 5. Combine
final_signal = sig_1x .+ (0.4 .* sig_fault) .+ noise

# --- SAVE TO CSV ---
df = DataFrame(Time = t, Amplitude = final_signal)
file_path = "bearing_fault_test.csv"
CSV.write(file_path, df)

println("File generated successfully: $file_path")
println("You can now upload this file using your analysis tool.")