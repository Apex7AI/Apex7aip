#!/bin/bash

. "/ins/setup_venv.sh" "$@"
. "/ins/copy_A0.sh" "$@"

python /a0/prepare.py --dockerized=true
python /a0/preload.py --dockerized=true

echo "Starting SearXNG in background..."
/usr/local/searxng/bin/python /usr/local/searxng/searxng/webapp.py -c /etc/searxng/settings.yml &

echo "Waiting for SearXNG to initialize..."
sleep 5

echo "Starting A0..."
python /a0/run_ui.py \
    --dockerized=true \
    --port=80 \
    --host="0.0.0.0" \
    --code_exec_docker_enabled=false \
    --code_exec_ssh_enabled=true \
    # --code_exec_ssh_addr="localhost" \
    # --code_exec_ssh_port=22 \
    # --code_exec_ssh_user="root" \
    # --code_exec_ssh_pass="toor"
