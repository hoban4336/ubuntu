#!/bin/sh

install() {
  sudo snap remove --purge microk8s
  sudo snap install microk8s --classic --channel=1.28/stable
  sudo snap refresh microk8s --channel 1.30/stable
}

if [ "$#" -gt 0 ]; then
  for FUNC in "$@"; do
    if type "$FUNC" 2>/dev/null | grep -q 'function'; then
      print_step "Running function: $FUNC"
      "$FUNC"
    else
      print_step "Function '$FUNC' not found."
    fi
  done
  exit 0
else
  main
fi
