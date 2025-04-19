#!/bin/bash
# Add the OpenAI API key to the environment
source addOpenAI.sh
# Build the container
podman build -t gravebot-aipy311 .

# Run the container with audio device access
podman run -it --privileged --rm \
    --device /dev/snd \
    --group-add keep-groups \
    -e PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native \
    -v ${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR}/pulse/native \
    -v ~/.config/pulse/cookie:/root/.config/pulse/cookie \
    -v $(pwd):/app \
    -e OPENAI_API_KEY="${OPENAI_API_KEY}" \
    gravebot-aipy311
