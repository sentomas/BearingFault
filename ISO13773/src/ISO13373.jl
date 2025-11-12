module ISO13373

using DSP
using Plots
using FFTW
using Statistics
using CSV
using DataFrames

# --- HELPER FUNCTIONS ---

function cosd(deg)
    return cos(deg2rad(deg))
end

function prompt_input(prompt_text, default_val)
    print("$prompt_text [$default_val]: ")
    input_str = readline()
    if input_str == ""
        return default_val
    else
        try
            if isa(default_val, Int)
                return parse(Int, input_str)
            elseif isa(default_val, String)
                return input_str
            else
                return parse(Float64, input_str)
            end
        catch
            println("Invalid input. Using default value.")
            return default_val
        end
    end
end

# --- CORE ENGINE: ANALYZE AND PLOT ---
function perform_envelope_analysis(t, signal, fs, bpfo, f_r)
    
    println("\n--- Processing Signal ---")
    N = length(signal)
    
    # 1. Automatic Filter Selection (Focus on high freq resonance)
    nyquist = fs / 2
    center_freq = fs * 0.25 
    f_low = center_freq - 1000
    f_high = center_freq + 1000
    
    println("Applying Bandpass Filter: $(round(f_low)) Hz - $(round(f_high)) Hz")
    
    filter_design = digitalfilter(Bandpass(f_low / nyquist, f_high / nyquist), Butterworth(4))
    signal_filtered = filtfilt(filter_design, signal)

    # 2. Envelope (Hilbert)
    analytic_signal = hilbert(signal_filtered)
    envelope = abs.(analytic_signal)
    envelope_demeaned = envelope .- mean(envelope)

    # 3. FFT
    win = hanning(N)
    env_fft_complex = fft(envelope_demeaned .* win)
    env_fft_mag = abs.(env_fft_complex)[1:div(N, 2) + 1]
    fft_freqs = fftfreq(N, fs)[1:div(N, 2) + 1]

    # 4. Plotting
    p1 = plot(t, signal, 
              title="1. Time Waveform", 
              xlabel="Time (s)", ylabel="Amplitude", 
              legend=false, xlims=(0, min(0.5, t[end])))

    p2 = plot(fft_freqs, env_fft_mag, 
              title="2. Envelope Spectrum", 
              xlabel="Frequency (Hz)", ylabel="Magnitude", 
              legend=false, xlims=(0, 5 * bpfo))

    # Add Fault Markers
    vline!(p2, [bpfo], label="BPFO", color=:red, linestyle=:dash, linewidth=2)
    vline!(p2, [2*bpfo], label="2x BPFO", color=:red, linestyle=:dot)
    vline!(p2, [f_r], label="1x RPM", color=:blue, linestyle=:dash)

    display(plot(p1, p2, layout=(2, 1), size=(800, 600)))
    println("Analysis Complete. BPFO marked at $(round(bpfo, digits=2)) Hz.")
end

# --- DATA SOURCE: SIMULATION ---
function generate_simulation(fs, bpfo, f_r)
    println("\nGenerating simulated fault data...")
    T = 5.0
    N = Int(T * fs)
    t = (0:N-1) / fs

    # 1x RPM + Noise
    signal = 1.0 * sin.(2 * π * f_r * t) + 0.5 * randn(N)
    
    # Add Impacts
    resonance_freq = fs * 0.25 
    impact_train = zeros(N)
    period_samples = fs / bpfo
    
    for i in 1:floor(Int, T * bpfo)
        idx = floor(Int, i * period_samples)
        if idx <= N && idx > 0
            impact_train[idx] = 1.5 # Strong impacts
        end
    end

    decay = exp.(-t[1:div(Int(fs), 10)] .* 200)
    ringing = sin.(2 * π * resonance_freq * t[1:length(decay)]) .* decay
    fault_sig = conv(impact_train, ringing)[1:N]
    
    return t, (signal + fault_sig)
end

# --- DATA SOURCE: CSV FILE ---
function load_csv_file()
    println("\n--- File Upload ---")
    path = prompt_input("Enter full file path (e.g., C:/data/vib.csv)", "data.csv")
    
    if !isfile(path)
        println("Error: File not found!")
        return nothing, nothing, nothing
    end

    df = CSV.read(path, DataFrame)
    println("\nColumns found: ", names(df))
    
    col_time = prompt_input("Enter Time column name", names(df)[1])
    col_sig = prompt_input("Enter Signal column name", names(df)[2])
    
    t = df[!, col_time]
    signal = df[!, col_sig]
    
    # Calculate Sampling Frequency from Time Vector
    dt = t[2] - t[1]
    fs_calc = 1 / dt
    println("Calculated Sampling Frequency: $(round(fs_calc, digits=2)) Hz")
    
    return t, signal, fs_calc
end

# --- MAIN CONTROLLER ---
function run_analysis()
    println("========================================")
    println("   ISO 13373 VIBRATION ANALYZER         ")
    println("========================================")

    # 1. Get Bearing & Speed Info
    println("\n[Step 1] Machine Configuration")
    rpm = prompt_input("Machine Speed (RPM)", 1780.0)
    f_r = rpm / 60
    
    N_b = prompt_input("Number of Balls", 9)
    D_b = prompt_input("Ball Diameter (mm)", 12.0)
    D_p = prompt_input("Pitch Diameter (mm)", 75.0)
    β = prompt_input("Contact Angle (degrees)", 15.0)
    
    # --- CALCULATE ALL FREQUENCIES ---
    geom_factor = (D_b / D_p) * cosd(β)

    ftf = (f_r / 2) * (1 - geom_factor)
    bpfo = (N_b / 2) * f_r * (1 - geom_factor)
    bpfi = (N_b / 2) * f_r * (1 + geom_factor)
    bsf = (D_p / (2 * D_b)) * f_r * (1 - geom_factor^2)

    # --- DISPLAY FREQUENCIES ---
    println("\n--- Calculated Frequencies ---")
    println("Shaft Speed (f_r):  ", round(f_r, digits=2), " Hz")
    println("BPFO (Outer Race):  ", round(bpfo, digits=2), " Hz")
    println("BPFI (Inner Race):  ", round(bpfi, digits=2), " Hz")
    println("BSF (Ball Spin):    ", round(bsf, digits=2), " Hz")
    println("FTF (Cage):         ", round(ftf, digits=2), " Hz")
    println("--------------------------------")

    # 2. Choose Data Source
    println("\n[Step 2] Select Data Source")
    println("1. Simulate a Fault (BPFO)")
    println("2. Upload CSV File")
    mode = prompt_input("Selection", 1)

    t = nothing
    signal = nothing
    fs = nothing

    if mode == 1
        fs = prompt_input("Simulation Sampling Freq (Hz)", 20000.0)
        t, signal = generate_simulation(fs, bpfo, f_r)
    elseif mode == 2
        t, signal, fs = load_csv_file()
        if t === nothing
            return 
        end
    else
        println("Invalid selection.")
        return
    end

    # 3. Execute Analysis
    perform_envelope_analysis(t, signal, fs, bpfo, f_r)
end

export run_analysis

end # module