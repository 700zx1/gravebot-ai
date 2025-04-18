#!/bin/bash

podman run -it --rm --name gravebot-aipy311 \
  --network host \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  --entrypoint /bin/bash \
  gravebot-aipy311:latest
