#!/bin/bash

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
