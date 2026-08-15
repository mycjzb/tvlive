#!/bin/sh
set -eu
cd /data
if [ ! -f ./cms-pub.json ]; then
  echo "tvlive: writing default cms-pub.json"
  cms-pub -config ./cms-pub.json || true
fi
exec cms-pub -config ./cms-pub.json
