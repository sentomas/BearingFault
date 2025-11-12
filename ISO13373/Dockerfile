# 1. Use the official Julia Docker image
FROM julia:1.10

# 2. Set up the working directory
WORKDIR /app

# 3. Copy ONLY the project files to install dependencies
# This layer is cached and makes future builds faster
COPY Project.toml .
COPY Manifest.toml .

# 4. Install all Julia packages
RUN julia -e 'using Pkg; Pkg.instantiate()'

# 5. Copy the rest of your application code
COPY . .

# 6. Expose the port your Genie server runs on
EXPOSE 8000

# 7. The command to run when the server starts
# We use 0.0.0.0 to listen on all network interfaces, not just localhost
CMD ["julia", "--project=.", "api.jl", "s", "-b", "0.0.0.0"]