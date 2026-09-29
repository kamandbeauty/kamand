#!/usr/bin/env bash
# Lumi: Bubblewood Chronicle — Local Game Launcher
echo "Starting Lumi Game Server on http://localhost:8080 ..."
python3 -m http.server 8080 --directory "$(dirname "$0")/web"
