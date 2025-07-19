# Install ZSH
mkdir -p "$HOME/tools" && wget https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.install_zsh -O "$HOME/tools/.install_zsh" && chmod +x "$HOME/tools/.install_zsh" && "$HOME/tools/.install_zsh"
# Install Lazy Journal
mkdir -p "$HOME/tools" && wget https://github.com/Lifailon/lazyjournal/releases/download/0.7.9/lazyjournal-0.7.9-amd64.deb -O $HOME/tools/lazyjournal.deb && sudo dpkg -i $HOME/tools/lazyjournal.deb && sudo apt-get install -f

# Add alias
wget https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.bash_alias -O ~/.bash_aliases && echo "if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi" >> ~/.bashrc && echo "if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi" >> ~/.zshrc

