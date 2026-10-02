#!/bin/bash
# Remove the four lab clusters.
set -euo pipefail
for c in mgmt dev staging prod; do kind delete cluster --name "$c" || true; done
