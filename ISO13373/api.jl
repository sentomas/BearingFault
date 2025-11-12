using Genie, Genie.Router, Genie.Renderer.Json, Genie.Requests
# Import GeniePlugins to handle CORS
using GeniePlugins

# Load the logic from your module
include("src/ISO13773_M.jl")
using .ISO13773

# --- CORS Configuration ---
# This is the critical security part.
# It tells your backend to trust your frontend.
cors_origins = ["https://serinthomas.co.in"]
cors_headers = ["Content-Type", "Authorization"]
cors_methods = ["GET", "POST", "OPTIONS"]

Genie.config.cors_headers = cors_headers
Genie.config.cors_allowed_origins = cors_origins
Genie.config.cors_allowed_methods = cors_methods
# Apply the CORS settings
Genie.Plugins.cors()
# --- End CORS ---


# === API Endpoint 1: Calculate Frequencies ===
# Responds to: GET /calculate_frequencies?rpm=...&n_b=... etc.
route("/calculate_frequencies") do
  try
    # Use Genie.Requests.params to get query parameters
    rpm = parse(Float64, Genie.Requests.params(:rpm, "1780.0"))
    n_b = parse(Int, Genie.Requests.params(:n_b, "9"))
    d_b = parse(Float64, Genie.Requests.params(:d_b, "12.0"))
    d_p = parse(Float64, Genie.Requests.params(:d_p, "75.0"))
    beta = parse(Float64, Genie.Requests.params(:beta, "15.0"))

    # Call the logic function from your module
    freqs = ISO13373.calculate_all_frequencies(rpm, n_b, d_b, d_p, beta)
    
    # Return the result as JSON
    # Use Genie.Renderer.Json.json explicitly
    return Genie.Renderer.Json.json(freqs)
  catch ex
    # Return an error if parsing fails
    return Genie.Renderer.Json.json(Dict("error" => "Invalid parameters: $(ex.msg)"), status = 400)
  end
end


# === API Endpoint 2: Full Analysis from File Upload ===
# Responds to: POST /analyze/upload
route("/analyze/upload", method = POST) do
  try
    # 1. Get uploaded file
    # Use Genie.Requests.files to get the file object
    if !haskey(Genie.Requests.files(), "file")
      return Genie.Renderer.Json.json(Dict("error" => "No 'file' part in upload."), status = 400)
    end
    uploaded_file = Genie.Requests.files("file")
    
    # 2. Get form data (payload)
    # Use Genie.Requests.payload to get the other form fields
    rpm = parse(Float64, Genie.Requests.payload(:rpm, "1780.0"))
    n_b = parse(Int, Genie.Requests.payload(:n_b, "9"))
    d_b = parse(Float64, Genie.Requests.payload(:d_b, "12.0"))
    d_p = parse(Float64, Genie.Requests.payload(:d_p, "75.0"))
    beta = parse(Float64, Genie.Requests.payload(:beta, "15.0"))
    time_col = Genie.Requests.payload(:time_col, "Time")
    signal_col = Genie.Requests.payload(:signal_col, "Amplitude")

    # 3. Calculate frequencies
    freq_data = ISO13373.calculate_all_frequencies(rpm, n_b, d_b, d_p, beta)

    # 4. Parse CSV data
    # Pass the IO stream from the uploaded file directly
    t, signal, fs = ISO13373.parse_csv_data(IOBuffer(uploaded_file.data), time_col, signal_col)

    # 5. Perform envelope analysis
    fft_freqs, fft_mags = ISO13373.perform_envelope_analysis(t, signal, fs)

    # 6. Prepare JSON response
    response_data = Dict(
      "metadata" => Dict(
        "sampling_frequency_hz" => fs,
        "total_samples" => length(t),
        "duration_s" => t[end]
      ),
      "fault_frequencies" => freq_data,
      "envelope_spectrum" => Dict(
        "frequencies" => fft_freqs,
        "magnitudes" => fft_mags
      )
    )
    
    return Genie.Renderer.Json.json(response_data)
  
  catch ex
    # Handle any error during processing
    if ex isa ArgumentError
      return Genie.Renderer.Json.json(Dict("error" => "Argument Error: $(ex.msg)"), status = 400)
    else
      return Genie.Renderer.Json.json(Dict("error" => "Internal Server Error: $(sprint(showerror, ex))"), status = 500)
    end
  end
end

# --- Start the Server ---
Genie.startup(8000, "0.0.0.0", async=false)