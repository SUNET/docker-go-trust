#!/usr/bin/env bash

# Start script for go-trust with environment variable support
set -e

echo "Starting Go-Trust Service..."

# Environment variables with defaults
SERVICE_PORT=${SERVICE_PORT:-6001}
SERVICE_HOST=${SERVICE_HOST:-0.0.0.0}
LOG_LEVEL=${LOG_LEVEL:-info}
CONFIG_FILE=${CONFIG_FILE:-/etc/go-trust/config.json}
PIPELINE_FILE=${PIPELINE_FILE:-/app/pipeline.yaml}
FREQUENCY=${FREQUENCY:-3600}
NO_SERVER=${NO_SERVER:-false}

# Create config directory if it doesn't exist
CONFIG_DIR=$(dirname "${CONFIG_FILE}")
if [ ! -d "${CONFIG_DIR}" ]; then
   mkdir -p "${CONFIG_DIR}"
fi

echo "Configuration:"
echo "  Port: ${SERVICE_PORT}"
echo "  Host: ${SERVICE_HOST}"
echo "  Log Level: ${LOG_LEVEL}"
echo "  Config File: ${CONFIG_FILE}"
echo "  Pipeline File: ${PIPELINE_FILE}"
echo "  Update Frequency: ${FREQUENCY}s"
echo "  No Server Mode: ${NO_SERVER}"
echo ""

# Build go-trust arguments
ARGS=""

# Add server configuration
ARGS="${ARGS} --host ${SERVICE_HOST}"
ARGS="${ARGS} --port ${SERVICE_PORT}"
ARGS="${ARGS} --log-level ${LOG_LEVEL}"
ARGS="${ARGS} --frequency ${FREQUENCY}"

# Add no-server flag for one-shot pipeline execution
if [ "${NO_SERVER}" = "true" ]; then
    ARGS="${ARGS} --no-server"
    echo "Running in one-shot mode (no API server)"
fi

# Add configuration file if it exists
if [ -f "${CONFIG_FILE}" ]; then
    ARGS="${ARGS} --config ${CONFIG_FILE}"
    echo "Using config: ${CONFIG_FILE}"
else
    echo "Warning: Config file ${CONFIG_FILE} not found, using defaults"
fi

# Add pipeline file (required)
if [ -f "${PIPELINE_FILE}" ]; then
    ARGS="${ARGS} ${PIPELINE_FILE}"
    echo "Using pipeline: ${PIPELINE_FILE}"
else
    echo "Error: Pipeline file ${PIPELINE_FILE} not found"
    echo "The go-trust service requires a pipeline configuration file"
    exit 1
fi

echo "Starting go-trust with arguments: ${ARGS}"
echo "---"

# Execute go-trust binary
exec ./go-trust ${ARGS}
