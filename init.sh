#!/bin/sh

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # 색상 초기화

# 메시지 출력 함수
print_step() { echo -e "${CYAN}$1${NC}"; sleep 1; }
print_success() { echo -e "${GREEN}$1${NC}"; sleep 1; }
print_error() { echo -e "${RED}Error: $1${NC}" >&2; exit 1; }

PUBLIC_KEY_URL="https://raw.githubusercontent.com/hoban4336/ubuntu/main/id_rsa.pub_hoban4336"

add_public_key_from_url() {
  user_home=$1
  print_step "Fetching public key from URL for user home: $user_home..."

  [ ! -d "$user_home/.ssh" ] && sudo mkdir -p "$user_home/.ssh" && sudo chmod 700 "$user_home/.ssh"
  pub_key=$(curl -fsSL "$PUBLIC_KEY_URL") || print_error "Failed to fetch public key from URL"

  # authorized_keys 파일에 키 추가
  if ! grep -q "$pub_key" "$user_home/.ssh/authorized_keys" 2>/dev/null; then
    echo "$pub_key" | sudo tee -a "$user_home/.ssh/authorized_keys" > /dev/null || print_error "Failed to add public key"
    sudo chmod 600 "$user_home/.ssh/authorized_keys"
    sudo chown -R "$NEW_USER:$NEW_USER" "$user_home/.ssh"
    print_success "Public key added to $user_home/.ssh/authorized_keys successfully"
  else
    print_step "Public key already exists in $user_home/.ssh/authorized_keys"
  fi
}

add_public_key() {
  add_public_key_from_url "$HOME"
}

create_user() {
  print_step "Creating a new user for Terraform..."
  echo -n "Enter the username to create (default: terraformuser): "
  read NEW_USER < /dev/tty
  [ -z "$NEW_USER" ] && NEW_USER="terraformuser"
  
  if id "$NEW_USER" >/dev/null 2>&1; then
    print_step "User $NEW_USER already exists, adding SSH key only..."
    add_public_key_from_url "/home/$NEW_USER"
  else
    print_step "Creating user $NEW_USER..."
    sudo adduser "$NEW_USER" --gecos "" --disabled-password || print_error "Failed to create $NEW_USER"
    echo "$NEW_USER:password" | sudo chpasswd || print_error "Failed to set password for $NEW_USER"
    sudo usermod -aG sudo "$NEW_USER" || print_error "Failed to add $NEW_USER to sudo group"
    echo "$NEW_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/"$NEW_USER" > /dev/null
    print_success "User $NEW_USER created and configured successfully"
    add_public_key_from_url "/home/$NEW_USER"
  fi
  sudo chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"

  echo "$NEW_USER"
}

configure_firewall() {
  print_step "Configuring firewall for SSH..."
  #SSH 포트
  sudo ufw allow ssh    
  sudo ufw --force enable
  print_success "Firewall configured successfully"
}

configure_ssh() {
  print_step "Configuring SSH settings..."
  sudo sed -i '/^#PubkeyAuthentication yes/s/^#//' /etc/ssh/sshd_config || print_error "Failed to enable PubkeyAuthentication"
  sudo sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || print_error "Failed to disable PasswordAuthentication"
  print_success "SSH settings configured successfully"
  
  print_step "Restarting SSH service..."
  sudo systemctl restart sshd || print_error "Failed to restart SSH service"
  sudo systemctl status sshd --no-pager
  print_success "SSH service restarted successfully"
}

install_oh_my_zsh() {
  print_step "Installing Oh My Zsh..."
  rm -rf ~/.oh-my-zsh ~/.zsh* || print_error "Failed to clean up existing Zsh installations"
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" || print_error "Failed to install Oh My Zsh"
  
  print_step "Cloning Zsh plugins..."
  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-history-substring-search ~/.oh-my-zsh/custom/plugins/zsh-history-substring-search
  git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions
  print_success "Oh My Zsh and plugins installed"
}

install_powerlevel10k() {
  print_step "Installing Powerlevel10k font..."
  wget https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf
  wget https://github.com/powerline/powerline/raw/develop/font/10-powerline-symbols.conf
  mkdir -p ~/.fonts/ ~/.config/fontconfig/conf.d
  mv 10-powerline-symbols.conf ~/.config/fontconfig/conf.d/
  mv PowerlineSymbols.otf ~/.fonts/
  fc-cache -vf ~/.fonts/
  
  print_step "Installing Powerlevel10k theme..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" || print_error "Failed to install Powerlevel10k"
  print_success "Powerlevel10k theme installed successfully"
  
  print_step "Configuring Powerlevel10k .zshrc file ..."
  sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
  sed -i '/^plugins=(/c\plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search zsh-completions)' ~/.zshrc
  
  print_success ".zshrc configured successfully"
}

configure_docker() {
    NEW_USER=$1
    DOCKER_MNT="/mnt/storage"

    command -v docker &> /dev/null || print_error "Docker가 설치되지 않았습니다."
    print_step "Setting Permission for Docker..."
    ## Permission
    sudo usermod -aG docker $(whoami)
    sudo usermod -aG docker "$NEW_USER"
    print_success "Permission configured $(whoami), $NEW_USER successfully"

    [ -d "$DOCKER_MNT" ] || print_error "$DOCKER_MNT 디렉토리가 존재하지 않습니다. 먼저 디렉토리를 생성하세요."
    print_step "Setting Storage for Docker..."
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "data-root": "/mnt/storage/docker"
}
EOF

    print_step "Reloading Docker..."
    sudo systemctl daemon-reload
    sudo systemctl restart docker

    echo -e "\n\n"
    docker info
    print_success "Storage for Docker $DOCKER_MNT configured successfully"
}

install_dependencies() {
  print_step "Installing dependencies..."
  sudo apt-get update -y
  sudo apt-get install -y openssh-server git curl vim zsh htop docker.io docker-compose
  print "\n"
  print "\n"
  
  # Prerequisite 설정
  print_step "Setting up default editor to vim..."
  grep -q 'export EDITOR=vim' ~/.bashrc || echo 'export EDITOR=vim' >> ~/.bashrc
  git config --global core.editor "vim"
  print_success "Default editor set to vim"
}

main() {
  install_dependencies
  install_oh_my_zsh
  install_powerlevel10k
  add_public_key "$HOME"
  NEW_USER=$(create_user)
  configure_ssh
  configure_docker "$NEW_USER"
  configure_firewall
  print_success "All tasks completed!"
}

main
