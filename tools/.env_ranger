#!/bin/bash
ENV_DIR="$HOME/ranger-env"

# Update package lists
sudo apt update

# Install pip and venv support
sudo apt install -y python3-pip python3-venv

# Create virtual environment if it doesn't exist
if [ ! -d "$ENV_DIR" ]; then
    python3 -m venv "$ENV_DIR"
fi

# Activate the virtual environment
source "$ENV_DIR/bin/activate"

# Upgrade pip and install ranger
python3 -m pip install --upgrade pip
pip install ranger-fm

echo "Ranger installed in virtual environment $ENV_DIR"
echo "To start ranger, run: source $ENV_DIR/bin/activate && ranger"
echo "To exit the environment, use: deactivate"
