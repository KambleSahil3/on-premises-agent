#!/bin/bash

# Function to download the script
download_script() {
    local url=$1
    local file_name=$2
    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$file_name"
    elif command -v wget &>/dev/null; then
        wget -q "$url" -O "$file_name"
    else
        echo "Error: Neither curl nor wget is installed. Please install one of them to proceed."
        exit 1
    fi
    chmod +x "$file_name"
    echo "Script downloaded and made executable: $file_name"
}

# URL of the script in the GitHub repository
SCRIPT_URL="https://raw.githubusercontent.com/KulkarniShashank/on-premises-agent/master/on_premises_agent.sh"

# Check if the script is being run directly or if the user wants to download it
if [ "$1" == "--download" ]; then
    download_script "$SCRIPT_URL" "on_premises_agent.sh"
    exit 0
fi

START_TIME=$(date +%s)
DIR=".educreds"

# Check if the directory already exists
if [ -d "$DIR" ]; then
    echo "Directory $DIR already exists."
else
    # Create the directory
    mkdir "$DIR"
    echo "Directory $DIR created."
fi

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
    echo "Docker is not installed. Installing Docker..."

    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh

    # Add the current user to the docker group
    sudo usermod -aG docker $USER

    # Start and enable the Docker service
    sudo systemctl start docker
    sudo systemctl enable docker

    echo "Docker has been installed."
else
    echo "Docker is already installed."
fi

# Function to prompt user for input
prompt_input() {
    local prompt_message=$1
    local input_variable=$2
    read -p "$prompt_message" $input_variable
}

prompt_input_with_tenant_validation() {
    local prompt_message=$1
    local input_variable=$2
    local validation_message=$3

    while true; do
        echo "$prompt_message"
        echo "1) true"
        echo "2) false"
        read -p "Select an option (1 or 2): " choice
        case "$choice" in
        1)
            eval $input_variable=true
            break
            ;;
        2)
            eval $input_variable=false
            break
            ;;
        *)
            echo "$validation_message"
            ;;
        esac
    done
}

prompt_input_with_webhook_host_validation() {
    local prompt_message=$1
    local input_variable=$2
    local validation_message=$3

    while true; do
        read -p "$prompt_message" $input_variable
        local input_value="${!input_variable}"

        # Match http(s)://IP:port with any characters after port
        if [[ "$input_value" =~ ^http:\/\/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+.*$ ]] ||
            [[ "$input_value" =~ ^https:\/\/[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]; then
            break
        else
            echo "$validation_message"
        fi
    done
}

# Prompt user for input
prompt_input "Enter ORGANIZATION_ID: " ORGANIZATION_ID
prompt_input "Enter WALLET_NAME: " WALLET_NAME
prompt_input "Enter WALLET_PASSWORD: " WALLET_PASSWORD

INDY_LEDGER_FORMATTED='[
    {
        "genesisTransactions": "https://raw.githubusercontent.com/Indicio-tech/indicio-network/main/genesis_files/pool_transactions_testnet_genesis",
        "indyNamespace": "indicio:testnet"
    },
    {
        "genesisTransactions": "https://raw.githubusercontent.com/Indicio-tech/indicio-network/main/genesis_files/pool_transactions_demonet_genesis",
        "indyNamespace": "indicio:demonet"
    },
    {
        "genesisTransactions": "https://raw.githubusercontent.com/Indicio-tech/indicio-network/main/genesis_files/pool_transactions_mainnet_genesis",
        "indyNamespace": "indicio:mainnet"
    },
    {
        "genesisTransactions": "http://test.bcovrin.vonx.io/genesis",
        "indyNamespace": "bcovrin:testnet"
    }
]'

# Proceed to prompt for other parameters
prompt_input_with_webhook_host_validation "Enter WEBHOOK_HOST (host/domain): " WEBHOOK_HOST "Error: WEBHOOK_HOST must be in the format http://host:port or https://domain."
prompt_input "Enter WALLET_STORAGE_HOST: " WALLET_STORAGE_HOST
prompt_input "Enter WALLET_STORAGE_PORT: " WALLET_STORAGE_PORT
prompt_input "Enter WALLET_STORAGE_USER: " WALLET_STORAGE_USER
prompt_input "Enter WALLET_STORAGE_PASSWORD: " WALLET_STORAGE_PASSWORD
prompt_input "Enter AGENT_NAME: " AGENT_NAME
prompt_input "Enter PROTOCOL: " PROTOCOL
prompt_input_with_tenant_validation "Choose Multi-Tenancy:" TENANT "Error: Invalid selection. Please enter 1 for 'true' or 2 for 'false'."
echo "You selected: $TENANT"
prompt_input "Enter CREDO_IMAGE: " CREDO_IMAGE
prompt_input "Enter INBOUND_ENDPOINT: " INBOUND_ENDPOINT
prompt_input "Enter ADMIN_PORT: " ADMIN_PORT
prompt_input "Enter INBOUND_PORT: " INBOUND_PORT"

# Validate and format the INBOUND_ENDPOINT
if [[ "$INBOUND_ENDPOINT" =~ ^https?:// ]]; then
    AGENT_ENDPOINT="$INBOUND_ENDPOINT"
else
    echo "Invalid input for INBOUND_ENDPOINT: $INBOUND_ENDPOINT"
    exit 1
fi

echo "-----$AGENT_ENDPOINT----"
CONFIG_FILE="${PWD}/${DIR}/agent-config/${ORGANIZATION_ID}_${AGENT_NAME}.json"

# Ensure the agent-config directory exists
if [ ! -d "${PWD}/${DIR}/agent-config" ]; then
    echo "Error: agent-config directory does not exist."
    mkdir -p ${PWD}/${DIR}/agent-config
fi

# Set ownership of the .educreds directory
sudo chown $USER: "$DIR"

# Check if ports are set
if [ -z "$ADMIN_PORT" ] || [ -z "$INBOUND_PORT" ]; then
    echo "Please set ADMIN_PORT and INBOUND_PORT environment variables."
    exit 1
fi

# Enable ports in firewall
sudo iptables -A INPUT -p tcp --dport "$ADMIN_PORT" -j ACCEPT
sudo iptables -A INPUT -p tcp --dport "$INBOUND_PORT" -j ACCEPT

# Display message
echo "Ports $ADMIN_PORT and $INBOUND_PORT have been enabled in the firewall."

# Generate the configuration file
cat <<EOF >${CONFIG_FILE}
{
  "label": "${ORGANIZATION_ID}_${AGENT_NAME}",
  "walletId": "$WALLET_NAME",
  "walletKey": "$WALLET_PASSWORD",
  "walletType": "postgres",
  "walletUrl": "$WALLET_STORAGE_HOST:$WALLET_STORAGE_PORT",
  "walletAccount": "$WALLET_STORAGE_USER",
  "walletPassword": "$WALLET_STORAGE_PASSWORD",
  "walletAdminAccount": "$WALLET_STORAGE_USER",
  "walletAdminPassword": "$WALLET_STORAGE_PASSWORD",
  "walletScheme": "DatabasePerWallet",
  "indyLedger": $INDY_LEDGER_FORMATTED,
  "endpoint": [
    "$AGENT_ENDPOINT"
  ],
  "autoAcceptConnections": true,
  "autoAcceptCredentials": "contentApproved",
  "autoAcceptProofs": "contentApproved",
  "logLevel": 5,
  "inboundTransport": [
    {
      "transport": "$PROTOCOL",
      "port": "$INBOUND_PORT"
    }
  ],
  "outboundTransport": [
    "$PROTOCOL"
  ],
  "webhookUrl": "$WEBHOOK_HOST",
  "adminPort": "$ADMIN_PORT",
  "tenancy": $TENANT
}
EOF

FILE_NAME="docker-compose_${ORGANIZATION_ID}_${AGENT_NAME}.yaml"
DOCKER_COMPOSE="${PWD}/${DIR}/${FILE_NAME}"

# Generate the Docker Compose file
cat <<EOF >${DOCKER_COMPOSE}
version: '3'

services:
  agent:
    image: $CREDO_IMAGE
    container_name: ${ORGANIZATION_ID}_${AGENT_NAME}
    restart: always
    environment:
      AFJ_REST_LOG_LEVEL: 1
    ports:
     - ${INBOUND_PORT}:${INBOUND_PORT}
     - ${ADMIN_PORT}:${ADMIN_PORT}
    volumes:
      - ./agent-config/${ORGANIZATION_ID}_${AGENT_NAME}.json:/config.json
    command: ["aca-py", "start", "-c", "/config.json"]
EOF

END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))

echo "Execution time: $EXECUTION_TIME seconds"
echo "docker-compose path: $DOCKER_COMPOSE"
