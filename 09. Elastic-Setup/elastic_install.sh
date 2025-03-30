#!/bin/bash

# Progress file path
PROGRESS_FILE="/var/tmp/elk_setup_progress.txt"
INSTALLATION_OUTPUT="/var/tmp/installation_output.txt"

# Function to check progress and resume
check_progress() {
    if [ -f "$PROGRESS_FILE" ]; then
        echo "Resuming from last progress..."
        source "$PROGRESS_FILE"
    else
        echo "Starting fresh installation..."
        LAST_STEP="start"
    fi
}

# Function to save progress
save_progress() {
    echo "LAST_STEP=$1" > "$PROGRESS_FILE"
}

# Function to log output to both terminal and file
log_output() {
    echo "$1" | tee -a "$INSTALLATION_OUTPUT"
}

# Check if the script is resuming after a reboot
if [ "$1" == "reboot" ]; then
    echo "Resuming after reboot..."
    check_progress
fi

# Set up network configuration
check_progress
if [ "$LAST_STEP" == "start" ]; then
    sudo cat << EOF > /etc/netplan/01-netcfg.yaml
    network:
      version: 2
      renderer: networkd
      ethernets:
        ens32:
          dhcp4: no
          addresses: [10.10.10.100/24]
          gateway4: 10.10.10.2
          nameservers:
            addresses: [10.10.10.10, 1.1.1.1]
EOF
    sudo netplan apply
    save_progress "network_config"
    sudo reboot
    exit 0
fi

# Update the system
check_progress
if [ "$LAST_STEP" == "network_config" ]; then
    sudo apt-get update
    sudo apt-get upgrade -y
    save_progress "update_system"
fi

# Install required packages
check_progress
if [ "$LAST_STEP" == "update_system" ]; then
    sudo apt-get install -y default-jdk wget gnupg
    save_progress "install_packages"
fi

# Add the Elastic repository
check_progress
if [ "$LAST_STEP" == "install_packages" ]; then
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
    sudo apt-get install apt-transport-https
    save_progress "add_elastic_repo"
    sudo reboot
    exit 0
fi

# Install Elasticsearch 8.8.0
check_progress
if [ "$LAST_STEP" == "add_elastic_repo" ]; then
    sudo apt-get update
    sudo apt autoremove
    echo "Installing Elasticsearch..."
    sudo apt-get install -y elasticsearch=8.8.0 | tee -a "$INSTALLATION_OUTPUT"
    if [ $? -ne 0 ]; then
        log_output "Error installing Elasticsearch. Check the installation output for more details."
        save_progress "install_elasticsearch_failed"
        exit 1
    fi
    save_progress "install_elasticsearch"
fi

:'
# Manually download and install Elasticsearch
check_progress
if [ "$LAST_STEP" == "add_elastic_repo" ]; then
    # Download and extract Elasticsearch
    wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.8.0-linux-x86_64.tar.gz
    tar -zxvf elasticsearch-8.8.0-linux-x86_64.tar.gz -C /opt

    save_progress "install_elasticsearch"
fi
'
:'
# Manually download and install Elasticsearch Debian package
check_progress
if [ "$LAST_STEP" == "add_elastic_repo" ]; then
    # Download the Debian package
    wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.8.0-amd64.deb

    # Install the Debian package using dpkg
    sudo dpkg -i elasticsearch-8.8.0-amd64.deb | tee -a "$INSTALLATION_OUTPUT"

    save_progress "install_elasticsearch"
fi
'



# Configure Elasticsearch
check_progress
if [ "$LAST_STEP" == "install_elasticsearch" ]; then
    sudo sed -i 's/#http.port: 9200/http.port: 9200/' /etc/elasticsearch/elasticsearch.yml
    save_progress "configure_elasticsearch"
fi

# Start and enable Elasticsearch
check_progress
if [ "$LAST_STEP" == "configure_elasticsearch" ]; then
    sudo systemctl start elasticsearch
    if [ $? -ne 0 ]; then
        log_output "Error starting Elasticsearch. Check the service status."
        save_progress "start_elasticsearch_failed"
        exit 1
    fi
    sudo systemctl enable elasticsearch
    save_progress "start_elasticsearch"
fi

# Check Elasticsearch status and wait until it is up to test
check_progress
if [ "$LAST_STEP" == "start_elasticsearch" ]; then
    while ! sudo systemctl is-active --quiet elasticsearch; do
        log_output "Elasticsearch is not yet running. Waiting for Elasticsearch to start..."
        sleep 5  # Adjust the sleep duration as needed
    done
    log_output "Elasticsearch is up and running."
    save_progress "check_elasticsearch_status"

    # Test Elasticsearch using curl
    log_output "Testing Elasticsearch"
fi

# Test Elasticsearch using curl
check_progress
if [ "$LAST_STEP" == "check_elasticsearch_status" ]; then
    password=$(grep -o 'The generated password for the elastic built-in superuser is : \S*' "$INSTALLATION_OUTPUT" | awk '{print $NF}')
    curl_command="curl -X GET -k \"https://elastic:$password@10.10.10.100:9200\""
    response=$(eval $curl_command)
    if [[ $response == *"cluster_name"* ]]; then
        log_output "Elasticsearch installation completed successfully."
        save_progress "test_elasticsearch"
    else
        log_output "Failed to access Elasticsearch. Check the installation or configuration."
        save_progress "elastic_failed"
        exit 1
    fi

    check_progress
    if [ "$LAST_STEP" == "test_elasticsearch" ]; then
        log_output "We can continue with Installing Kibana Now"
    fi
fi

# Install Kibana 8.8.0
check_progress
if [ "$LAST_STEP" != "install_kibana" ]; then
    if ! sudo systemctl is-active --quiet elasticsearch; then
        echo "Elasticsearch is not running. Please start Elasticsearch before proceeding with Kibana installation."
        exit 1  # Exit the script if Elasticsearch is not running
    else
        sudo apt-get install -y kibana=8.8.0
    fi
    save_progress "install_kibana"
fi

# Create Kibana Enrollment Token
check_progress
if [ "$LAST_STEP" != "create_enrollment_token" ]; then
    ENROLLMENT_TOKEN=$(sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)
    save_progress "create_enrollment_token"
    echo "Created Enrollment Token for Kibana"
fi

# Set the enrollment token as an environment variable
export ENROLLMENT_TOKEN

# Enroll Kibana
check_progress
if [ "$LAST_STEP" != "configure_kibana" ]; then
    echo "ENROLLMENT_TOKEN = $ENROLLMENT_TOKEN"
    sudo /usr/share/kibana/bin/kibana-setup
    save_progress "configure_kibana"
fi

# Start and enable Kibana
check_progress
if [ "$LAST_STEP" != "start_kibana" ]; then
    sudo /usr/share/kibana/bin/kibana
    sudo systemctl restart kibana
    sudo systemctl enable kibana
    save_progress "start_kibana"
fi

# Check Kibana status
check_progress
if [ "$LAST_STEP" != "check_kibana_status" ]; then
    while ! sudo systemctl is-active --quiet kibana; do
        echo "Kibana is not yet running. Waiting for Kibana to start..."
        sleep 5  # Adjust the sleep duration as needed
    done
    sudo systemctl status kibana
    save_progress "check_kibana_status"
fi

# Install Nginx
check_progress
if [ "$LAST_STEP" != "install_nginx" ]; then
    sudo apt-get install -y nginx
    save_progress "install_nginx"
fi

# Configure Nginx reverse proxy
check_progress
if [ "$LAST_STEP" != "configure_nginx" ]; then
    sudo bash -c 'cat << EOF > /etc/nginx/sites-available/default
    server {
        listen 80;
        server_name 10.10.10.100;
        location / {
            proxy_pass http://127.0.0.1:5601;
        }
    }
EOF'
    password=$(grep -o 'The generated password for the elastic built-in superuser is : \S*' "$INSTALLATION_OUTPUT" | awk '{print $NF}')
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    save_progress "configure_nginx"
    echo "You are all done."
    echo "Visit -> http://10.10.10.100 \n\n"
    echo "Username = elastic \n\n"
    echo "Password = $password \n\n"
    echo "ENROLLMENT_TOKEN = $ENROLLMENT_TOKEN \n\n"
    echo "Facing any issues with enrolment of kibana, 'run sudo /usr/share/kibana/bin/kibana-setup' and copy the above Enrollment Token\n\n"
    
fi