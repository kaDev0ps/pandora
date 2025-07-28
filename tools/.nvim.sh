#!/bin/bash

set -e  # Stop execution of the script when an error occurs

# Check for administrator privileges
if [[ $(id -u) != 0 ]]; then
    echo "This script must be run with root privileges."
    exit 1
fi

# Function to output messages in the format "Step: message"
function step() {
    echo -e "\n\033[1;34m$1\033[0m"
}

# Update the package list
step "Updating package list..."
sudo apt update || { echo "Error updating package list."; exit 1; }

# Install necessary dependencies
step "Installing dependencies..."
sudo apt install -y build-essential libtool autotools-dev autoconf automake cmake ninja-build gcc \
    pkg-config luajit libluajit-5.1-dev lua5.1 liblua5.1-dev libunibilium-dev libtermkey-dev \
    libvterm-dev libmsgpack-dev libuv1-dev libwebsockets-dev python3-dev python3-pip python3-setuptools \
    python3-wheel || { echo "Error installing dependencies."; exit 1; }

# Clone the Neovim repository
step "Cloning the Neovim repository..."
NEOVIM_DIR="/home/netrika_ka/tools/neovim_build"
git clone https://github.com/neovim/neovim.git "$NEOVIM_DIR" || { echo "Error cloning the Neovim repository."; exit 1; }

# Change to the project directory
cd "$NEOVIM_DIR" || { echo "Error changing to the Neovim directory."; exit 1; }

# Build Neovim
step "Building Neovim..."
make CMAKE_BUILD_TYPE=RelWithDebInfo || { echo "Error building Neovim."; exit 1; }

# Install Neovim
step "Installing Neovim..."
sudo make install || { echo "Error installing Neovim."; exit 1; }

# Remove the temporary directory
rm -rf "$NEOVIM_DIR"

# Create the configuration directory if it does not exist
CONFIG_DIR="$HOME/.config/nvim"
mkdir -p "$CONFIG_DIR" || { echo "Error creating configuration directory."; exit 1; }

# Create the init.lua configuration file
INIT_LUA="$CONFIG_DIR/init.lua"
cat > "$INIT_LUA" <<EOF
-- Basic Neovim configuration
vim.opt.mouse = 'a'
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.smarttab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.autoindent = true
vim.opt.clipboard = 'unnamedplus'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.hlsearch = true
vim.opt.expandtab = true
vim.opt.cursorline = true
vim.opt.wrap = false
vim.cmd('syntax enable')
vim.cmd('colorscheme desert') -- You can change 'desert' to your preferred theme
EOF

echo "Neovim setup is complete. Configuration saved to: $INIT_LUA"

exit 0
