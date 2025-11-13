# Multi-stage Docker build: pure go-trust binary with dependencies controlled by  docker-go-trust
# No cmd/ directory needed - we build the actual go-trust binary with controlled dependencies

FROM golang:latest AS dependencies

# Install system dependencies needed for Go modules  
RUN apt-get update && apt-get install -y \
    ca-certificates \
    git \
    build-essential \
    pkg-config \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Stage to download controlled dependencies
WORKDIR /deps

# Copy  docker-go-trust dependency management files for dependency control
COPY  docker-go-trust/go.mod  docker-go-trust/go.sum ./

# Download dependencies according to  docker-go-trust specifications
RUN go mod download

# Source stage - get go-trust source code
FROM golang:latest AS source

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Clone go-trust source code
WORKDIR /src
RUN git clone https://github.com/SUNET/go-trust.git .

# Build stage - combine controlled dependencies with go-trust source  
FROM golang:latest AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy go-trust source
COPY --from=source /src/ ./

# Copy your controlled dependencies from  docker-go-trust
COPY  ./go.mod ./go.sum /tmp/controlled-deps/

# Create a hybrid go.mod: go-trust module name + controlled dependencies
RUN echo 'module github.com/SUNET/go-trust' > go.mod.new && \
    echo '' >> go.mod.new && \
    echo 'go 1.23' >> go.mod.new && \
    echo '' >> go.mod.new && \
    # Copy require blocks from  controlled dependencies
    sed -n '/^require (/,/^)/{p}' /tmp/controlled-deps/go.mod >> go.mod.new && \
    echo '' >> go.mod.new && \
    # Copy replace directives
    grep '^replace ' /tmp/controlled-deps/go.mod >> go.mod.new || true && \
    # Apply the new go.mod
    mv go.mod.new go.mod

# Use your controlled go.sum
COPY  ./go.sum ./

# Download dependencies with  controlled versions
RUN go mod tidy && go mod download && go mod verify

# Build the go-trust binary using controlled dependencies
RUN CGO_ENABLED=1 GOOS=linux go build -a \
    -ldflags='-w -s -extldflags "-static"' \
    -o go-trust ./cmd

# Final runtime stage - minimal image for running go-trust
FROM debian:bullseye-slim AS runtime

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libxml2 \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

# Create non-root user for security
RUN useradd -r -u 1001 -g 0 gotrust

# Create necessary directories with proper permissions
RUN mkdir -p /app /etc/go-trust /var/log/go-trust && \
    chown -R gotrust:root /app /etc/go-trust /var/log/go-trust && \
    chmod -R g=u /app /etc/go-trust /var/log/go-trust

WORKDIR /app

# Copy the go-trust binary built with controlled dependencies
COPY --from=builder /build/go-trust .

# Copy your service-specific configuration
COPY  ./config/ /etc/go-trust/
COPY  ./test-tl-setup/pipeline.yaml ./pipeline.yaml
COPY  ./start.sh ./start.sh

# Make binary and script executable
USER root
RUN chmod +x go-trust start.sh
USER gotrust

# Expose the service port
EXPOSE 6001

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://127.0.0.1:6001/healthz || exit 1

# Run go-trust using start script with environment variables
CMD ["./start.sh"]
