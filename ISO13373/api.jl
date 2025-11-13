# api.jl
ENV["OMP_PROC_BIND"] = "false"

using Genie, Genie.Renderer.Json, Genie.Requests, Genie.Renderer.Html
# Use the module file you have
include("src/ISO13773_M.jl") 
# Use the module name defined in that file
using .ISO13773 

cors_headers = Dict(
    "Access-Control-Allow-Origin" => "*",
    "Access-Control-Allow-Headers" => "Content-Type",
    "Access-Control-Allow-Methods" => "GET, POST, OPTIONS"
)
Genie.config.cors_headers = cors_headers

route("/") do
    serve_static_file("index.html")
end

route("/calculate_frequencies") do
    try
        rpm = parse(Float64, string(Genie.Requests.params(:rpm, "1780")))
        n_b = parse(Int, string(Genie.Requests.params(:n_b, "9")))
        d_b = parse(Float64, string(Genie.Requests.params(:d_b, "12.0")))
        d_p = parse(Float64, string(Genie.Requests.params(:d_p, "75.0")))
        beta = parse(Float64, string(Genie.Requests.params(:beta, "15.0")))

        freqs = ISO13773.calculate_all_frequencies(rpm, n_b, d_b, d_p, beta)
        return Genie.Renderer.Json.json(freqs)
    catch ex
        return Genie.Renderer.Json.json(Dict("error" => string(ex)), status = 400)
    end
end

route("/analyze/upload", method = POST) do
    try
        # FIX: Use the correct function `filespayload()`
        if isempty(Genie.Requests.filespayload())
             return Genie.Renderer.Json.json(Dict("error" => "No file uploaded."), status = 400)
        end
        
        # FIX: Use the correct function `filespayload()`
        file = first(Genie.Requests.filespayload())[2]
        
        rpm = parse(Float64, string(Genie.Requests.payload(:rpm, "1780")))
        n_b = parse(Int, string(Genie.Requests.payload(:n_b, "9")))
        d_b = parse(Float64, string(Genie.Requests.payload(:d_b, "12.0")))
        d_p = parse(Float64, string(Genie.Requests.payload(:d_p, "75.0")))
        beta = parse(Float64, string(Genie.Requests.payload(:beta, "15.0")))
        time_col = string(Genie.Requests.payload(:time_col, "Time"))
        signal_col = string(Genie.Requests.payload(:signal_col, "Amplitude"))

        # 1. Get Frequencies
        freqs = ISO13773.calculate_all_frequencies(rpm, n_b, d_b, d_p, beta)
        
        # 2. Process Data
        t, signal, fs_calc = ISO13773.parse_csv_data(IOBuffer(file.data), time_col, signal_col)
        fft_freqs, env_fft_mag = ISO13773.perform_envelope_analysis(t, signal, fs_calc)

        # 3. Slice Time Waveform (Max 2000 points)
        max_points = 2000
        
        # Use Base.div to avoid function name conflicts
        step = max(1, Base.div(length(t), max_points))
        
        t_view = collect(t[1:step:end])
        sig_view = collect(signal[1:step:end])

        response = Dict(
            "metadata" => Dict(
                "filename" => file.name,
                "sampling_frequency_hz" => fs_calc,
                "data_points" => length(t)
            ),
            "fault_frequencies" => freqs,
            "time_waveform" => Dict(
                "t" => t_view,
                "signal" => sig_view
            ),
            "envelope_spectrum" => Dict(
                "frequencies" => fft_freqs,
                "magnitudes" => env_fft_mag
            )
        )
        return Genie.Renderer.Json.json(response)

    catch ex
        @error "Analysis Error" exception=(ex, catch_backtrace())
        return Genie.Renderer.Json.json(Dict("error" => string(ex)), status = 500)
    end
end

println("Starting ISO 13373 Analyzer on port 8000...")
up(8000, "0.0.0.0", async=false)