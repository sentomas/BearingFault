# 1. Start from the official Julia base image
FROM julia:1.10

# 2. Set the working directory inside the container
WORKDIR /app

# 3. Copy the Project/Manifest files
COPY Project.toml .
COPY Manifest.toml .

# 4. Copy all your application files
COPY . .
# 5. Install all the Julia packages *for the current project*
# THIS IS THE FIX: Added --project=.
RUN julia --project=. -e 'using Pkg; Pkg.instantiate()'



# 6. Expose the port your Genie server runs on
EXPOSE 8000

# 7. The command to run when the server starts
CMD ["julia", "--project=.", "api.jl"]