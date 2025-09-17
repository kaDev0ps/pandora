# Install ZSH
mkdir -p "$HOME/tools" && wget https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.install_zsh -O "$HOME/tools/.install_zsh" && chmod +x "$HOME/tools/.install_zsh" && "$HOME/tools/.install_zsh"
# Install nvim
mkdir -p "$HOME/tools" && wget https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.nvim.sh -O "$HOME/tools/.install_nvim" && chmod +x "$HOME/tools/.nvim" && "$HOME/tools/.install_nvim"
# Backup configs
mkdir -p "$HOME/tools" && wget -q --show-progress https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.backup_configs.sh -O "$HOME/tools/.backup_configs.sh" && chmod +x "$HOME/tools/.backup_configs.sh" && sudo cp "$HOME/tools/.backup_configs.sh" /usr/lib/ && sudo /usr/lib/.backup_configs.sh && ln -sf /usr/lib/.backup_configs.sh "$HOME/backup_configs.sh" || true && ln -sfn /data/backup/services/ "$HOME/backups"
# Ranger in ENV
mkdir -p "$HOME/tools" && wget -q --show-progress https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.env_ranger.sh -O "$HOME/tools/.env_ranger.sh" && chmod +x "$HOME/tools/.env_ranger.sh" && "$HOME/tools/.env_ranger.sh"
# Add alias
wget https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.bash_alias -O ~/.bash_aliases && echo "if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi" >> ~/.bashrc && echo "if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi" >> ~/.zshrc

