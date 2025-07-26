#!/bin/bash

# Update package lists
echo "Updating package lists..."
sudo apt update

# Install Neovim
echo "Installing Neovim..."
sudo apt install -y neovim

# Create the configuration directory if it doesn't exist
CONFIG_DIR="$HOME/.config/nvim"
mkdir -p "$CONFIG_DIR"

# Create the init.vim configuration file with the specified settings
INIT_VIM="$CONFIG_DIR/init.vim"
echo "Creating init.vim configuration..."

cat > "$INIT_VIM" <<EOL
" Enable mouse support
set mouse=a

" Enable line numbers
set number

" Enable relative line numbers
set relativenumber

" Configure tab settings
set smarttab
set tabstop=2
set shiftwidth=2
set softtabstop=2
set autoindent

" Configure color settings for diff mode
highlight DiffAdd    ctermfg=White ctermbg=DarkGreen
highlight DiffChange ctermfg=White ctermbg=DarkBlue
highlight DiffDelete ctermfg=White ctermbg=DarkGrey
highlight DiffText   ctermfg=White ctermbg=DarkGrey

" Additional basic settings (optional)
set clipboard=unnamedplus    " Use system clipboard
set ignorecase               " Case insensitive searching
set smartcase                " Case sensitive if capital letter is used
set incsearch                " Incremental search
set hlsearch                 " Highlight search results
set expandtab                " Convert tabs to spaces
set cursorline               " Highlight the current line
set wrap                     " Enable line wrapping

" Enable syntax highlighting
syntax on

" Set a default colorscheme (optional)
colorscheme desert           " You can change 'desert' to any colorscheme you prefer
EOL

echo "Neovim setup complete. Configuration written to $INIT_VIM"
