# Use an official Ubuntu runtime as a parent image
FROM ubuntu:20.04

# Set the working directory in the container to /app
WORKDIR /app

# Install necessary tools
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    python3.8 \
    python3-pip \
   git 

# Copy the current directory contents into the container at /app
COPY . /app

# Install Scarb
RUN curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | bash -s -- -v 0.6.2

# Add Scarb to PATH
ENV PATH="/root/.local/bin:${PATH}"

# Install project dependencies
RUN scarb build

# Run the tests
CMD ["scarb", "test"]