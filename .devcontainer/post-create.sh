#!/bin/bash
set -e

echo "Upgrading Azure CLI to latest version..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "Installing Python dependencies ..."
pip install --upgrade pip
pip install -r requirements-dev.txt --quiet

echo "Post-create setup complete."