# 1. Start from the official Julia base image
FROM julia:1.10

# 2. Set the working directory inside the container
WORKDIR /app

# 3. Copy all application files (including your local Manifest.toml)
COPY . .

# 4. DELETE the local Manifest.toml
# This forces Julia to resolve dependencies fresh for the Docker environment,
# fixing the "failed to find source" path errors.
RUN rm -f Manifest.toml

# 5. Install/Instantiate
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# 6. Expose the port
EXPOSE 8000

# 7. Run command
CMD ["julia", "--project=.", "api.jl"]