# 1. Start from the official Julia base image
FROM julia:1.10

# 2. Set the working directory inside the container
WORKDIR /app

# 3. Copy the Project.toml file FIRST
# This lets Docker cache the installed packages, making future builds faster
COPY Project.toml .

# 4. Install all the Julia packages from Project.toml
# RUN julia -e 'using Pkg; Pkg.add(url="https://github.com/GenieFramework/Genie.jl", rev="v6.3.0"); Pkg.instantiate()'
Pkg.instantiate()

# 5. Copy all your application files into the container
# This includes api.jl, index.html, and the src/ folder
COPY . .

# 6. Tell Docker that your app listens on port 8000
EXPOSE 8000

# 7. The command to run when the container starts
# This will execute your api.jl script
CMD ["julia", "api.jl"]