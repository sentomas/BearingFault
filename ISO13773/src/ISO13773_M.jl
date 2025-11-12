module M13773

using DSP
using FFTW
using Statistics
using CSV
using DataFrames

# --- HELPER FUNCTION ---

function cosd(deg)
    return cos(deg2rad(deg))
end

# --- CORE LOGIC 1: CALCULATE FREQUENCIES ---
"""
    calculate_all_frequencies(rpm, N_b, D_b, D_p, β)

Calculates all bearing fault frequencies and returns them in a Dictionary.
"""
function calculate_all_frequencies(rpm, N_b, D_b, D_p, β)
    f_r = rpm / 60
    geom_factor = (D_b / D_p) * cosd(β)

    ftf = (f_r / 2) * (1 - geom_factor)
    bpfo = (N_b / 2) * f_r * (1 - geom_factor)
    bpfi = (N_b / 2) * f_r * (1 + geom_factor)
    bsf = (D_p / (2 * D_b)) * f_r * (1 - geom_factor^2)

    return Dict(
        "f_r" => f_r,
        "bpfo" => bpfo,
        "bpfi" => bpfi,
        "bsf" => bsf,
        "ftf" => ftf
    )
end

# --- CORE LOGIC 2: PARSE CSV DATA ---
"""
    parse_csv_data(io::IO, time_col, signal_col)

Reads CSV data from an IO stream and returns (t, signal, fs).
"""
function parse_csv_data(io::IO, time_col_name, signal_col_name)
    df = CSV.read(io, DataFrame)
    
    # Check if provided column names exist
    if !(time_col_name in names(df))
        throw(ArgumentError("Time column '$time_col_name' not found in CSV."))
    end
    if !(signal_col_name in names(df))
        throw(ArgumentError("Signal column '$signal_col_name' not found in CSV."))
    end

    t = df[!, time_col_name]
    signal = df[!, signal_col_name]
    
    dt = t[2] - t[1]
    fs_calc = 1 / dt
    
    return t, signal, fs_calc
end

# --- CORE LOGIC 3: PERFORM ANALYSIS ---
"""
    perform_envelope_analysis(t, signal, fs)

Runs the core analysis and returns the (frequencies, magnitudes) of the envelope spectrum.
"""
function perform_envelope_analysis(t, signal, fs)
    N = length(signal)
    
    # 1. Automatic Filter Selection
    nyquist = fs / 2
    center_freq = fs * 0.25 
    f_low = center_freq - 1000
    f_high = center_freq + 1000
    
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

    # 4. Return the data (NO PLOTTING)
    return fft_freqs, env_fft_mag
end

end # module M13773