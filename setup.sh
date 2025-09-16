#!/bin/bash

#================================================================================#
# Kali Linux Post-Install Setup Script
#
# Description: Automates the setup and configuration of a fresh Kali Linux install.
# Author:      Your Name
# Version:     1.3
#
# Usage:
#   1. Save the script as setup_kali.sh
#   2. Make it executable: chmod +x setup_kali.sh
#   3. Run with sudo:     sudo ./setup_kali.sh
#
#================================================================================#

# --- Variables and Logging ---


# Colors for logging messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to log informational messages
log_info() {
    echo -e "${BLUE}[*] $1${NC}"
}

# Function to log success messages
log_success() {
    echo -e "${GREEN}[+] $1${NC}"
}

# Function to log warning/skip messages
log_warn() {
    echo -e "${YELLOW}[!] $1${NC}"
}


# Function to log error messages (for real command failures)
log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# --- Pre-flight Checks ---

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please use sudo."
   exit 1
fi

# Get the username of the user who invoked sudo
if [[ -n "$SUDO_USER" ]]; then
    REAL_USER="$SUDO_USER"
else
    log_warn "Cannot determine the original user. Run with 'sudo'. Defaulting to user from /home."
    REAL_USER=$(ls /home | head -n 1) # Fallback for some environments
fi
USER_HOME=$(eval echo "~$REAL_USER")
BASHRC_PATH="$USER_HOME/.bashrc"

# --- Function Definitions ---

## 1. System Initialization and Updates
function system_init() {
    log_info "🚀 Starting initial system setup and updates..."
    log_info "Ensuring default shell for $REAL_USER is bash."
    # Ensure default shell for the user is bash
    chsh -s /bin/bash "$REAL_USER"
    log_info "Default shell set to bash for $REAL_USER."

    log_info "Updating package lists (apt-get update)..."
    apt-get update
    log_info "Performing full system upgrade (apt-get full-upgrade -y)..."
    apt-get full-upgrade -y

    # Install essential meta-package if it's not present
    log_info "Installing essential meta-packages: kali-linux-headless, curl, gpg..."
    apt-get install -y kali-linux-headless curl gpg
    log_success "System is up-to-date and essential packages are installed."
}

## 2. Configure DNS
function configure_dns() {
    log_info "🔒 Configuring DNS to use Google and Cloudflare..."
    log_info "Making /etc/resolv.conf mutable (removing immutable attribute if set)..."
    # Make the file mutable first in case the script was run before
    chattr -i /etc/resolv.conf 2>/dev/null

    log_info "Writing new DNS settings to /etc/resolv.conf..."
    # Write new DNS settings
    cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

    # Make the file immutable to prevent changes
    log_info "Making /etc/resolv.conf immutable."
    chattr +i /etc/resolv.conf
    log_success "DNS configuration secured and locked."
}

## 3. Install Core Tools via APT
function install_apt_tools() {
    log_info "🔧 Installing core tools from APT repository..."
    log_info "Installing: remmina, flameshot, seclists, neovim, python3-pwntools, freerdp3-x11, snapd, terraform, jq, ufw..."
    apt-get install -y \
        remmina \
        flameshot \
        seclists \
        neovim \
        python3-pwntools \
        freerdp3-x11 \
        snapd \
        terraform \
        jq \
        ufw

    log_info "Enabling Snapd service (systemctl enable --now snapd snapd.apparmor)..."
    systemctl enable --now snapd
    systemctl enable --now snapd.apparmor
    
    # FIX: Clear the shell's command cache so newly installed tools (like ufw) are found
    log_info "Clearing shell command cache (hash -r)..."
    hash -r
    
    log_success "Core APT tools and Snapd installed."
}

## 4. Install Third-Party Tools (Docker, Ngrok, etc.)
function install_third_party_tools() {
    log_info "📦 Installing third-party applications..."

    # --- Docker ---
    if ! command -v docker &> /dev/null; then
        log_info "Docker not found. Proceeding with Docker installation..."
    log_info "Creating /etc/apt/keyrings directory if not present..."
    install -m 0755 -d /etc/apt/keyrings
    log_info "Downloading Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    log_info "Setting permissions on Docker GPG key..."
    chmod a+r /etc/apt/keyrings/docker.gpg
    log_info "Adding Docker repository to sources.list..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list
    log_info "Updating package lists after adding Docker repo..."
    apt-get update
    log_info "Installing Docker packages: docker-ce, docker-ce-cli, containerd.io..."
    apt-get install -y docker-ce docker-ce-cli containerd.io
    log_info "Enabling and starting Docker service..."
    systemctl enable docker --now
    log_info "Adding $REAL_USER to docker group..."
    usermod -aG docker "$REAL_USER"
    log_success "Docker installed and user '$REAL_USER' added to the docker group."
    else
        log_warn "Docker is already installed. Skipping Docker installation."
    fi

    # --- Ngrok ---
    if ! command -v ngrok &> /dev/null; then
        log_info "Ngrok not found. Proceeding with Ngrok installation..."
    log_info "Downloading Ngrok GPG key..."
    curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    log_info "Adding Ngrok repository to sources.list..."
    echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" | tee /etc/apt/sources.list.d/ngrok.list >/dev/null
    log_info "Updating package lists after adding Ngrok repo..."
    apt-get update
    log_info "Installing Ngrok..."
    apt-get install -y ngrok
    log_success "Ngrok installed."
    else
        log_warn "Ngrok is already installed. Skipping Ngrok installation."
    fi

    # --- VS Code (via Snap) ---
    if ! command -v code &> /dev/null; then
        log_info "VS Code not found. Proceeding with VS Code installation via Snap..."
    log_info "Installing VS Code using snap..."
    snap install --classic code
    log_success "VS Code installed."
    else
        log_warn "VS Code is already installed. Skipping VS Code installation."
    fi

    # --- AWS CLI v2 ---
    if ! command -v aws &> /dev/null; then
        log_info "AWS CLI not found. Proceeding with AWS CLI v2 installation..."
    log_info "Downloading AWS CLI v2 installer..."
    cd "$USER_HOME/Downloads"
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    log_info "Unzipping AWS CLI v2 installer..."
    unzip -o awscliv2.zip # -o overwrites without prompting
    log_info "Running AWS CLI v2 installer..."
    ./aws/install
    log_info "Cleaning up AWS CLI v2 installer files..."
    rm -rf aws awscliv2.zip
    cd - > /dev/null # Go back to previous directory quietly
    log_success "AWS CLI v2 installed."
    else
        log_warn "AWS CLI is already installed. Skipping AWS CLI installation."
    fi
}

# 12. Install and Configure SSH Server
function install_ssh_server() {
    log_info "🔑 Installing and configuring OpenSSH server for password authentication..."
    apt-get install -y openssh-server
    log_info "Ensuring sshd_config allows password authentication..."
    # Backup config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    # Permit password authentication
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    log_info "Restarting ssh service..."
    systemctl enable --now ssh
    systemctl restart ssh
    log_success "OpenSSH server installed and configured for password authentication."
    log_info "You can now SSH into this machine using your username and password."
}

## 5. Install Pwning and Cloud Pentesting Tools
function install_pentest_tools() {
    log_info "💀 Installing specialized pentesting tools..."

    # --- Pwndbg ---
    if [ ! -d "$USER_HOME/pwndbg" ]; then
        log_info "Pwndbg not found in $USER_HOME. Proceeding with Pwndbg installation..."
        # Run git clone as the actual user
    log_info "Cloning Pwndbg repository..."
    sudo -u "$REAL_USER" git clone https://github.com/pwndbg/pwndbg.git "$USER_HOME/pwndbg"
    log_info "Running Pwndbg setup script..."
    (cd "$USER_HOME/pwndbg" && ./setup.sh)
    log_success "Pwndbg installed."
    else
        log_warn "Pwndbg directory already exists in $USER_HOME. Skipping Pwndbg installation."
    fi

    # --- CloudGoat & Pacu (via pipx) ---
    log_info "Checking and installing CloudGoat and Pacu via pipx..."
    # Ensure pipx path is available for the user
    log_info "Ensuring pipx path is set for $REAL_USER..."
    sudo -u "$REAL_USER" pipx ensurepath

    # Check if CloudGoat is already installed
    if sudo -u "$REAL_USER" pipx list | grep -q "cloudgoat"; then
        log_warn "CloudGoat is already installed via pipx for $REAL_USER. Skipping CloudGoat installation."
    else
        log_info "CloudGoat not found for $REAL_USER. Installing CloudGoat via pipx..."
        sudo -u "$REAL_USER" pipx install git+https://github.com/RhinoSecurityLabs/cloudgoat.git --force
        log_success "CloudGoat installed."
    fi

    # Check if Pacu is already installed
    if sudo -u "$REAL_USER" pipx list | grep -q "pacu"; then
        log_warn "Pacu is already installed via pipx for $REAL_USER. Skipping Pacu installation."
    else
        log_info "Pacu not found for $REAL_USER. Installing Pacu via pipx..."
        sudo -u "$REAL_USER" pipx install git+https://github.com/RhinoSecurityLabs/pacu.git --force
        log_success "Pacu installed."
    fi
}

## 6. Configure System Services (Bluetooth)
function configure_services() {
    log_info "🔵 Checking for Bluetooth devices..."
    log_info "Checking for Bluetooth hardware in /sys/class/bluetooth..."
    # Check for hardware in /sys/class
    if ls /sys/class/bluetooth/hci* &> /dev/null; then
        log_info "Bluetooth hardware detected. Installing bluez and blueman, enabling bluetooth service..."
        apt-get install -y bluez blueman
        systemctl enable --now bluetooth.service
    log_success "Bluetooth service has been enabled and started."
    else
        log_warn "No Bluetooth hardware detected. Skipping Bluetooth setup."
    fi
}

## 7. Configure Wordlists
function configure_wordlists() {
    log_info "🗂️  Checking wordlists..."
    log_info "Checking for rockyou.txt and rockyou.txt.gz in /usr/share/wordlists..."
    local rockyou_gz="/usr/share/wordlists/rockyou.txt.gz"
    local rockyou_txt="/usr/share/wordlists/rockyou.txt"

    if [ -f "$rockyou_txt" ]; then
        log_warn "rockyou.txt is already uncompressed in /usr/share/wordlists. Skipping decompression."
    elif [ -f "$rockyou_gz" ]; then
        log_info "rockyou.txt.gz found. Uncompressing..."
        gunzip "$rockyou_gz"
        log_success "rockyou.txt is now available in /usr/share/wordlists."
    else
        log_warn "Could not find rockyou.txt.gz in /usr/share/wordlists. Is 'seclists' package installed?"
    fi
}

## 8. Configure Shell and Aliases
function configure_shell() {
    log_info "✍️  Configuring shell with custom aliases and settings..."

    # Helper function to add alias if it doesn't exist
    add_alias() {
        if ! grep -q "alias $1=" "$BASHRC_PATH"; then
            log_info "Adding alias: $1='$2' to $BASHRC_PATH..."
            echo "alias $1='$2'" >> "$BASHRC_PATH"
            log_success "Alias '$1' added."
        else
            log_warn "Alias '$1' already exists in $BASHRC_PATH. Skipping."
        fi
    }

    add_alias "cls" "clear"
    add_alias "clr" "clear"
    add_alias "py" "python3"
    add_alias "vi" "nvim"
    add_alias "upd" "sudo apt-get update"
    add_alias "upg" "sudo apt-get upgrade -y"
    add_alias "fupg" "sudo apt-get full-upgrade -y"
    add_alias "clean" "sudo apt-get autoremove -y && sudo apt-get autoclean"

    # Set ownership of .bashrc to the user, just in case
    log_info "Setting ownership of $BASHRC_PATH to $REAL_USER..."
    chown "$REAL_USER":"$REAL_USER" "$BASHRC_PATH"

    # Add user's local bin to PATH if not already present
    log_info "Checking if $USER_HOME/.local/bin is in PATH in $BASHRC_PATH..."
    local_bin_path_str="export PATH=\"$USER_HOME/.local/bin:\$PATH\""
    if ! grep -qF "$local_bin_path_str" "$BASHRC_PATH"; then
        log_info "Adding $USER_HOME/.local/bin to PATH in $BASHRC_PATH..."
        echo "" >> "$BASHRC_PATH"
        echo "# Add user's local bin to PATH for pipx" >> "$BASHRC_PATH"
        echo "$local_bin_path_str" >> "$BASHRC_PATH"
        log_success "Added '$USER_HOME/.local/bin' to PATH in .bashrc"
    else
        log_warn "'$USER_HOME/.local/bin' is already in the PATH in $BASHRC_PATH. Skipping."
    fi

    log_info "Updating Exploit-DB database (searchsploit -u)..."
    searchsploit -u
    log_success "Exploit-DB updated."
}

## 9. Configure Desktop Environment (XFCE)
function configure_desktop() {
    log_info "🎨 Configuring XFCE keyboard shortcuts for Flameshot..."
    log_info "Resetting Print Screen key mapping for Flameshot..."
    # This needs to run as the user to access their DBus session
    sudo -u "$REAL_USER" xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/Print" -r
    log_info "Assigning Print Screen key to Flameshot GUI..."
    sudo -u "$REAL_USER" xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/Print" -n -t string -s "flameshot gui"
    log_success "Print Screen key is now mapped to Flameshot."
}

## 10. Configure Firewall
function configure_firewall() {
    log_info "🔥 Configuring UFW (Uncomplicated Firewall)..."
    log_info "Setting UFW default policies: allow outgoing, deny incoming..."

    ufw default allow outgoing
    ufw default deny incoming

    log_info "Adding UFW rule to allow SSH and enable ICMP (ping) requests..."
    ufw allow ssh comment 'Allow inbound SSH connections'

    # Allow incoming ICMP (ping) requests by uncommenting the relevant rules.
    log_info "Uncommenting ICMP (ping) rules in /etc/ufw/before.rules..."
    sed -i -e '/-A ufw-before-input -p icmp/s/^#\s*//' /etc/ufw/before.rules

    log_info "Enabling the firewall (ufw --force enable)..."
    ufw --force enable

    log_success "UFW has been enabled and configured."
    log_info "Final UFW status (ufw status verbose):"
    # Pipe to sed to indent the output for better readability in the log
    ufw status verbose | sed 's/^/    /'
}

## 11. Security Hardening
function security_hardening() {
    log_info "🛡️  Applying security hardening settings..."
    log_info "Disabling Bash history for $REAL_USER and root..."

    # --- Disable Bash History for User ---
    if [ ! -L "$USER_HOME/.bash_history" ]; then
        log_info "Disabling Bash history for $REAL_USER..."
        rm -f "$USER_HOME/.bash_history"
        ln -s /dev/null "$USER_HOME/.bash_history"
        chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.bash_history"
        log_success "Bash history disabled for user $REAL_USER."
    else
        log_warn "Bash history for user $REAL_USER is already disabled. Skipping."
    fi

    # --- Disable Bash History for Root ---
    if [ ! -L "/root/.bash_history" ]; then
        log_info "Disabling Bash history for root..."
        rm -f "/root/.bash_history"
        ln -s /dev/null "/root/.bash_history"
        log_success "Bash history disabled for root user."
    else
        log_warn "Bash history for root is already disabled. Skipping."
    fi
}


# --- Main Execution ---

# Trap all errors and print them in red
set -e
trap 'log_error "An error occurred on line $LINENO. Exiting."' ERR

main() {
    clear
    log_info "Kali Linux Setup Script Initialized!"

    system_init
    configure_dns
    install_apt_tools
    install_third_party_tools
    install_pentest_tools
    install_ssh_server
    configure_services
    configure_wordlists
    configure_shell
    configure_desktop
    configure_firewall
    security_hardening

    echo
    log_success "✅ All tasks completed successfully!"
    log_warn "For all changes (especially new aliases and PATH) to take effect, you must start a new shell session."
    log_info "You can do this by logging out and back in, rebooting, or opening a new terminal window."
    echo
}

main