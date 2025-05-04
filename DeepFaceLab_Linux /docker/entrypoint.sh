#!/usr/bin/env bash
set -e

# If the current UID/GID are missing inside the container, add them.
if ! getent passwd "${UID}" > /dev/null 2>&1; then
    echo "fix-uid | adding passwd entry for UID=${UID}, GID=${GID} ..."
    echo "user:x:${UID}:${GID}:added by fix-uid:/workspace:/bin/bash" \
        >> /etc/passwd
fi
if ! getent group "${GID}" > /dev/null 2>&1; then
    echo "group:x:${GID}:" >> /etc/group
fi

exec "$@"

