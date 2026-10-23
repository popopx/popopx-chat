#!/bin/bash

set -eu

if [[ ! -f /opt/popopx/do_initialize_server ]]; then
  touch /opt/popopx/do_initialize_server
elif [[ ! -f /etc/opt/popopx/smp-server.ini ]]; then
  chmod +x /opt/popopx/initialize_server.sh
  /opt/popopx/initialize_server.sh
else
  echo "SMP server already initialized"
fi
