# Install ZSH
mkdir -p "$HOME/tools" && wget https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.install_zsh -O "$HOME/tools/.install_zsh" && chmod +x "$HOME/tools/.install_zsh" && "$HOME/tools/.install_zsh"
# Install systemd-managment-tui
mkdir -p "$HOME/tools" && wget https://github.com/matheus-git/systemd-manager-tui/releases/download/v1.0.8/systemd-manager-tui_1.0.8-1_amd64.deb -O "$HOME/tools/systemd-manager-tui_1.0.8-1_amd64.deb" && sudo dpkg -i /tools/systemd-manager-tui_1.0.8-1_amd64.deb && sudo systemd-manager-tui
# Install Lazy Journal
mkdir -p "$HOME/tools" && wget https://github.com/Lifailon/lazyjournal/releases/download/0.7.9/lazyjournal-0.7.9-amd64.deb -O $HOME/tools/lazyjournal.deb && sudo dpkg -i $HOME/tools/lazyjournal.deb && sudo apt-get install -f
# Install nvim
mkdir -p "$HOME/tools" && wget https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.nvim.sh -O "$HOME/tools/.install_nvim" && chmod +x "$HOME/tools/.nvim" && "$HOME/tools/.install_nvim"
# Backup configs
mkdir -p "$HOME/tools" && wget https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.backup_configs.sh -O "$HOME/tools/.backup_configs.sh" && chmod +x "$HOME/tools/.backup_configs.sh" && sudo cp "$HOME/tools/.backup_configs.sh" /usr/lib/ && sudo /usr/lib/.backup_configs.sh && ln -s /usr/lib/.backup_configs.sh $HOME/backup_configs.sh


# Add alias
wget https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.bash_alias -O ~/.bash_aliases && echo "if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi" >> ~/.bashrc && echo "if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi" >> ~/.zshrc

