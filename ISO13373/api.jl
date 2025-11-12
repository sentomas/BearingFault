# This is the main API server file
using Genie
using JSON3
include("src/ISO13773_M.jl")

# Bring our logic functions into scope
using .ISO13773

# --- API ENDPOINT 1: Calculate Frequencies ---
# Responds to GET requests like:
# /calculate_frequencies?rpm=1780&n_b=9&d_b=12.0&d_p=75.0&beta=15.0
route("/calculate_frequencies", method = GET) do
    try
        # Parse query parameters from the URL
        rpm = parse(Float64, params(:rpm, "1780.0"))
        n_b = parse(Int, params(:n_b, "9"))
        d_b = parse(Float64, params(:d_b, "12.0"))
        d_p = parse(Float64, params(:d_p, "75.0"))
        beta = parse(Float64, params(:beta, "15.0"))

        # Call our logic function
        freqs = ISO13773.calculate_all_frequencies(rpm, n_b, d_b, d_p, beta)
        
        # Return the result as JSON
        return json(freqs)
        
    catch ex
        return json(Dict("error" => string(ex)), status=400)
    end
end

# --- API ENDPOINT 2: Analyze Uploaded CSV ---
# Responds to POST requests with multipart/form-data
# FORM FIELDS:
# - file (the CSV)
# - rpm, n_b, d_b, d_p, beta
# - time_col (e.g., "Time")
# - signal_col (e.g., "Amplitude")
route("/analyze/upload", method = POST) do
    if !haskey(files, "file")
        return json(Dict("error" => "No 'file' provided in upload."), status=400)
    end

    try
        # 1. Get bearing parameters from the form data
        rpm = parse(Float64, payload(:rpm, "1780.0"))
        n_b = parse(Int, payload(:n_b, "9"))
        d_b = parse(Float64, payload(:d_b, "12.0"))
        d_p = parse(Float64, payload(:d_p, "75.0"))
        beta = parse(Float64, payload(:beta, "15.0"))
        
        # 2. Get CSV column names
        time_col = payload(:time_col, "Time")
        signal_col = payload(:signal_col, "Amplitude")

        # 3. Read the uploaded file's data
        uploaded_file = files["file"]
        file_data = IOBuffer(uploaded_file.data) # Read file into memory
        
        # 4. Parse the CSV
        (t, signal, fs) = M13773.parse_csv_data(file_data, time_col, signal_col)
        
        # 5. Get fault frequencies
        fault_freqs = M13773.calculate_all_frequencies(rpm, n_b, d_b, d_p, beta)

        # 6. Run the analysis
        (fft_freqs, fft_mags) = M13773.perform_envelope_analysis(t, signal, fs)

        # 7. Package and return the results as JSON
        # We round data for a cleaner JSON payload
        result = Dict(
            "metadata" => Dict(
                "filename" => uploaded_file.name,
                "fs" => fs,
                "fault_frequencies" => fault_freqs
            ),
            "envelope_spectrum" => Dict(
                "frequencies" => round.(fft_freqs, digits=2),
                "magnitudes" => round.(fft_mags, digits=5)
            )
        )
        return json(result)

    catch ex
        @error "Analysis failed" exception=(ex, catch_backtrace())
        return json(Dict("error" => string(ex)), status=500)
    end
end

# --- Start the Server ---
Genie.up(port=8000, async=false)