#!/usr/bin/env bash

# -- Correct Python
export DFL_PYTHON="python3"

# -- Correct absolute paths
export DFL_WORKSPACE="/workspace"
export DFL_ROOT="/workspace"
export DFL_SRC="/workspace/DeepFaceLab"

# -- Create workspace folders if missing
if [ ! -d "$DFL_WORKSPACE" ]; then
    mkdir -p "$DFL_WORKSPACE"
fi

for folder in data_src data_src/aligned data_src/aligned_d
