#!/bin/sh
set -eu

mkdir -p /state/workspace
cp /config/openclaw.json /state/openclaw.json
chown -R 1000:1000 /state
chmod 700 /state /state/workspace
chmod 600 /state/openclaw.json
