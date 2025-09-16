#!/bin/bash

clear

chsh -s /bin/bash

echo "alias cls='clear'" >> ~/.bashrc
echo "alias clr='clear'" >> ~/.bashrc
echo "alias py='python3'" >> ~/.bashrc
echo "alias vi='nvim'" >> ~/.bashrc

sudo apt update
sudo apt full-upgrade -y
sudo apt install -y kali-linux-headless

# docker

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker --now
sudo usermod -aG docker $USER

# tools

sudo apt install remmina flameshot seclists neovim python3-pwntools freerdp3-x11 -y

echo "alias upd='sudo apt update'" >> ~/.bashrc
echo "alias upg='sudo apt upgrade'" >> ~/.bashrc
echo "alias fupg='sudo apt full-upgrade'" >> ~/.bashrc
echo "alias clean='sudo apt autoremove && sudo apt autoclean'" >> ~/.bashrc

source ~/.bashrc

searchsploit -u

curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
  && echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list \
  && sudo apt update \
  && sudo apt install ngrok -y

cd ~
git clone https://github.com/pwndbg/pwndbg.git
cd pwndbg
./setup.sh

sudo apt install snapd -y
sudo systemctl enable --now snapd
sudo systemctl enable --now snapd.apparmor
snap version
sudo snap install --classic code

sudo bash -c 'cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF'

sudo chattr +i /etc/resolv.conf

xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/Print" -r

xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/Print" -n -t string -s "flameshot gui"

cd ~/Download
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

sudo apt install terraform jq -y

pipx install git+https://github.com/RhinoSecurityLabs/cloudgoat.git

pipx install git+https://github.com/RhinoSecurityLabs/pacu.git

rm -f ~/.bash_history
ln -s /dev/null ~/.bash_history

sudo rm -f /root/.bash_history
sudo ln -s /dev/null /root/.bash_history