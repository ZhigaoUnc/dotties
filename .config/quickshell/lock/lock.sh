#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export QML2_IMPORT_PATH="$DIR/imports:$QML2_IMPORT_PATH"
export QML_XHR_ALLOW_FILE_READ=1

for pid in $(pgrep -f 'quickshell.*--config lock'); do
    kill "$pid" 2>/dev/null
done

exec quickshell --no-duplicate --config lock
