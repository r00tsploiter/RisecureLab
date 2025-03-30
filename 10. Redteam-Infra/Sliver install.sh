#!/bin/bash

# Display banner
echo "========================================"
echo "           RISECURELAB                 "
echo "========================================"
echo "Options:"
echo "1. Weaponize"
echo "2. Clean Up Existing Installations"
echo "3. Exit"
echo "99. More about the Script"
echo "========================================"

# Prompt user for option
read -p "Select an option (1-3): " option

case $option in
    1)
        echo "Removing GUI interface before proceeding with the Sliver installation..."

        # Check if GUI exists (assuming XFCE or GNOME), then remove it
        if dpkg-query -l | grep -q 'kali-desktop-xfce'; then
            echo "XFCE desktop detected. Removing XFCE..."
            sudo apt-get remove --purge -y kali-desktop-xfce xfce4 xfce4-* lightdm
        elif dpkg-query -l | grep -q 'gnome-session'; then
            echo "GNOME desktop detected. Removing GNOME..."
            sudo apt-get remove --purge -y gnome-shell gnome-session gdm3
        elif dpkg-query -l | grep -q 'kde-plasma-desktop'; then
            echo "KDE desktop detected. Removing KDE..."
            sudo apt-get remove --purge -y kde-plasma-desktop sddm
        else
            echo "No GUI desktop environment detected."
        fi

        # Remove unnecessary GUI packages
        echo "Cleaning up GUI-related packages..."
        sudo apt-get autoremove --purge -y
        sudo apt-get autoclean -y

        # Install necessary packages (you can add or modify this based on your requirements)
        echo "Installing Sliver dependencies..."
        sudo apt-get update
        sudo apt-get install -y build-essential mingw-w64 binutils-mingw-w64 g++-mingw-w64

        # Start Sliver installation and setup
        echo "Proceeding with Sliver installation..."
        # Detect the user's shell and set the appropriate shell configuration file
        if [ -n "$ZSH_VERSION" ]; then
            SHELL_CONFIG="$HOME/.zshrc"
            SHELL_NAME="zsh"
        elif [ -n "$BASH_VERSION" ]; then
            SHELL_CONFIG="$HOME/.bashrc"
            SHELL_NAME="bash"
        else
            SHELL_CONFIG="$HOME/.profile"  # Fallback if neither zsh nor bash is detected
            SHELL_NAME="unknown shell"
        fi

        # Ensure /usr/local/bin is in the $PATH
        if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
            echo "Adding /usr/local/bin to the PATH for $SHELL_NAME..."
            export PATH=$PATH:/usr/local/bin
            # Persist the change in the user's shell configuration file
            echo "export PATH=\$PATH:/usr/local/bin" >> "$SHELL_CONFIG"
            # Source the appropriate shell config file to apply changes
            source "$SHELL_CONFIG"
        fi
        # Install required packages
        echo "Installing required packages..."
        sudo apt-get update
        sudo apt-get install -y build-essential mingw-w64 binutils-mingw-w64 g++-mingw-w64

        # Download sliver-server and set correct permissions
        echo "Downloading sliver-server..."
        sudo wget -O /usr/local/bin/sliver-server https://github.com/BishopFox/sliver/releases/download/v1.5.42/sliver-server_linux
        sudo chmod 755 /usr/local/bin/sliver-server

        # Download sliver-client and set correct permissions
        echo "Downloading sliver-client..."
        sudo wget -O /usr/local/bin/sliver https://github.com/BishopFox/sliver/releases/download/v1.5.42/sliver-client_linux
        sudo chmod 755 /usr/local/bin/sliver

        # Unpack sliver-server
        echo "Unpacking sliver-server..."
        sliver-server unpack --force

        # Create systemd service for Sliver server
        echo "Creating systemd service for Sliver server..."
        sudo bash -c 'cat <<EOF > /etc/systemd/system/sliver.service
[Unit]
Description=Sliver
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=on-failure
RestartSec=3
User=root
ExecStart=/usr/local/bin/sliver-server daemon

[Install]
WantedBy=multi-user.target
EOF'




        # Prompt for the username
        read -p "Enter the username: " username

        # Prompt for the operator name
        read -p "Enter the name of the name in your PC: " operator_name

        # Detect all available network interfaces and IP addresses
        echo "Detecting network interfaces and IP addresses..."
        available_ips=$(ip -4 addr | grep inet | awk '{print $2}' | cut -d'/' -f1)

        # Prompt the user to select an IP address
        echo "Available IP addresses:"
        select selected_ip in $available_ips; do
            if [[ -n "$selected_ip" ]]; then
                echo "You selected IP: $selected_ip"
                break
            else
                echo "Invalid selection, please try again."
            fi
        done

        # Prompt for the port number
        read -p "Enter the port number (default is 31337): " port
        port=${port:-31337}  # Use 31337 as the default if no port is provided

        # Define the config file path
        config_file="/home/$username/.sliver/configs/server.json"
        echo "Creating Sliver config at $config_file..."

        # Ensure the config directory exists
        mkdir -p "$(dirname "$config_file")"

# Write the configuration with the selected IP address, port, and operator name
        cat <<EOL > "$config_file"
{
    "daemon_mode": true,
    "daemon": {
        "host": "$selected_ip",
        "port": $port
    },
    "logs": {
        "level": 4,
        "grpc_unary_payloads": false,
        "grpc_stream_payloads": false,
        "tls_key_logger": false
    },
    "jobs": {
        "multiplayer": null
    },
    "watch_tower": null,
    "go_proxy": ""
}
EOL

        echo "Configuration successfully created at $config_file!"

        # Ensure appropriate permissions for the config file using the provided username
        sudo chown -R $username:$username "/home/$username/.sliver/"
        sudo chmod 600 "$config_file"

        echo "Configuration process completed for operator $operator_name with IP $selected_ip, port $port, and user $username."

        # Set correct permissions for the systemd service file
        sudo chmod 600 /etc/systemd/system/sliver.service

        # Reload systemd to apply changes
        sudo systemctl daemon-reload

        # Enable Sliver service to start on boot
        sudo systemctl enable sliver

        # Start the Sliver server

        echo "Starting the Sliver server..."
        sudo systemctl start sliver

        # Prompt for operator details
        read -p "Enter the folder where you want to save the operator details: " folder
        read -p "Enter the name of the operator: " operator_name
        read -p "Enter the IP address of the team server: " team_server_ip

        # Run sliver-server operator command with the provided details
        echo "Creating the operator..."
        sliver-server operator --name "$operator_name" --lhost "$team_server_ip" --save "$folder"

        # Create the configs directory if it doesn't exist
        CONFIGS_DIR="$HOME/.sliver-client/configs"
        mkdir -p "$CONFIGS_DIR"

        # Copy the generated config files to the configs directory
        echo "Copying configuration files to $CONFIGS_DIR..."
        cp "$folder"/* "$CONFIGS_DIR/"

        # Set ownership and permissions for the config file
        sudo chown -R $operator_name:$operator_name $HOME/.sliver-client/
        sudo chmod 600 "$CONFIGS_DIR/${operator_name}_${team_server_ip}.cfg"

        echo "Sliver server installation, setup, and operator creation complete!"
        # Install and set up Apache2
        echo "Installing Apache2..."
        sudo apt-get install -y apache2
        sudo systemctl enable apache2
        sudo systemctl start apache2

        # Set permissions for the Apache default directory
        echo "Setting permissions for /var/www/html..."
        sudo chown -R www-data:www-data /var/www/html
        sudo chmod -R 755 /var/www/html

        # Install and set up SSH
        echo "Installing SSH..."
        sudo apt-get install -y openssh-server
        sudo systemctl enable ssh
        sudo systemctl start ssh

        ;;
    
    2)
        # Cleanup script
        echo "Cleaning up any existing Sliver installations..."

        # Stop and disable the Sliver systemd service if it exists
        if systemctl list-units --full -all | grep -Fq 'sliver.service'; then
            echo "Stopping and disabling Sliver service..."
            sudo systemctl stop sliver
            sudo systemctl disable sliver
            sudo rm /etc/systemd/system/sliver.service
            sudo systemctl daemon-reload
        fi

        # Remove old sliver-client and sliver-server binaries
        if [ -f /usr/local/bin/sliver ]; then
            echo "Removing existing Sliver client..."
            sudo rm /usr/local/bin/sliver
        fi

        if [ -f /usr/local/bin/sliver-server ]; then
            echo "Removing existing Sliver server..."
            sudo rm /usr/local/bin/sliver-server
        fi

        echo "Cleanup complete!"
        ;;
    
    3)
        echo "Exiting..."
        exit 0
        ;;
    99)
        # Cleanup script
        echo "This script automates the installation and configuration of Sliver. "
        echo "Allows the user to specify key details such as"
        echo "Username: The username for which the Sliver configuration will be stored. (mostly username running the script)"
        echo "Network Interface IP: The script detects all available network interfaces on the system and allows the user to select one."
        echo "Port: The port that Sliver's daemon will listen on (default: 31337)."
        echo "runs sliver as deamon - Meaning clients will connect to the server even when the interface is terminated ;-)" 
        ;;
    *)
        echo "Invalid option. Please select 1, 2, or 3."
        ;;
esac
