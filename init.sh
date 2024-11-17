#!/bin/bash

# 1. Oh My Zsh 설치
echo "Installing Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# 2. 플러그인 설치
echo "Cloning Zsh plugins..."
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-history-substring-search ~/.oh-my-zsh/custom/plugins/zsh-history-substring-search
git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions

# 3. Powerlevel10k 테마 설치
echo "Installing Powerlevel10k theme..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# 4. .zshrc 파일 수정
echo "Configuring .zshrc..."
grep -q '^ZSH_THEME=' ~/.zshrc || echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> ~/.zshrc
grep -q '^plugins=' ~/.zshrc || echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search zsh-completions)' >> ~/.zshrc

# SSH 설치
echo "Installing OpenSSH server..."
sudo apt-get update -y
sudo apt-get install -y openssh-server

# UFW 방화벽에서 SSH 포트 허용
echo "Allowing SSH through the firewall..."
sudo ufw allow ssh
sudo ufw enable

# SSH 설정 변경: 공개 키 인증 활성화, 비밀번호 인증 비활성화
echo "Configuring SSH settings..."
sudo sed -i '/^#PubkeyAuthentication yes/s/^#//' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# SSH 서비스 재시작
echo "Restarting SSH service..."
sudo systemctl restart sshd

# SSH 서비스 상태 확인
echo "Checking SSH service status..."
sudo systemctl status sshd --no-pager

echo "SSH setup completed successfully."
