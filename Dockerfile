FROM rust:alpine

WORKDIR /app

# Install necessary tools
RUN apk add --no-cache \ 
    python3 \
    py3-pip \
    curl \
    git \
    bash

# Install Starknet Foundry
RUN curl -L \
    https://github.com/foundry-rs/starknet-foundry/releases/download/v0.25.0/starknet-foundry-v0.25.0-x86_64-unknown-linux-musl.tar.gz \
    -o starknet-foundry-v0.25.0.tar.gz && \
    tar -xzf starknet-foundry-v0.25.0.tar.gz && \
    mv starknet-foundry-v0.25.0-x86_64-unknown-linux-musl/bin/snforge /usr/local/bin/ && \
    mv starknet-foundry-v0.25.0-x86_64-unknown-linux-musl/bin/sncast /usr/local/bin/ && \
    rm -rf starknet-foundry-v0.25.0.tar.gz starknet-foundry-v0.25.0-x86_64-unknown-linux-musl

# Install Universal Sierra Compiler
RUN curl -L https://raw.githubusercontent.com/software-mansion/universal-sierra-compiler/master/scripts/install.sh | sh


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