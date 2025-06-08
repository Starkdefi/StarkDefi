# Use an official Python runtime as a parent image
FROM python:3.8-alpine

# Set the working directory in the container to /app
WORKDIR /app

# Install necessary tools
RUN apk add --no-cache \
    curl \
    build-base \
    git \
    bash

# Copy the current directory contents into the container at /app
COPY . /app

# Install Scarb
RUN curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | bash -s -- -v 0.6.2 || true

# Add Scarb to PATH
ENV PATH="/root/.local/bin:${PATH}"

# Install project dependencies
RUN scarb build

# Run the tests
CMD ["scarb", "test"]