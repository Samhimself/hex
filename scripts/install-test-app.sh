#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
HEX_TEST_BUILD=1 exec "$root/scripts/install-app.sh"
