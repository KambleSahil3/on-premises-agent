#!/bin/bash

if [[ ! -t 0 ]]; then
    echo "Error: This script must be run in an interactive shell."
    exit 1
fi

START_TIME=$(date +%s)
DIR=".educreds"
CONFIG_FILE="${PWD}/${DIR}/agent-config/parameters.conf"

# Ensure the directory exists
mkdir -p "${PWD}/${DIR}/agent-config"

# Create the configuration file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    touch "$CONFIG_FILE"
fi

chmod 600 "$CONFIG_FILE" || {
    echo "Error: Failed to set permissions on $CONFIG_FILE"
    exit 1
}

# Function to prompt user for input and save it to the config file
prompt_input() {
    local prompt_message=$1
    local input_variable=$2
    while [ -z "${!input_variable}" ]; do
        read -p "$prompt_message" $input_variable
        if [ -n "${!input_variable}" ]; then
            echo "$input_variable=${!input_variable}" >>"$CONFIG_FILE"
        fi
    done
    echo "$input_variable=${!input_variable} (loaded from config)"
}

# Function to prompt user for input with validation and save it to the config file
prompt_input_with_validation() {
    local prompt_message=$1
    local input_variable=$2
    local validation_pattern=$3
    local validation_message=$4

    while [ -z "${!input_variable}" ]; do
        read -p "$prompt_message" $input_variable
        if [[ "${!input_variable}" =~ $validation_pattern ]]; then
            echo "$input_variable=${!input_variable}" >>"$CONFIG_FILE"
        else
            echo "$validation_message"
            unset $input_variable
        fi
    done
    echo "$input_variable=${!input_variable} (loaded from config)"
}

# Function to prompt user for true/false input with validation and save it to the config file
prompt_input_with_tenant_validation() {
    local prompt_message=$1
    local input_variable=$2
    local validation_message=$3

    while [ -z "${!input_variable}" ]; do
        echo "$prompt_message"
        echo "1) true"
        echo "2) false"
        read -p "Select an option (1 or 2): " choice
        case "$choice" in
        1)
            eval $input_variable=true
            echo "$input_variable=true" >>"$CONFIG_FILE"
            ;;
        2)
            eval $input_variable=false
            echo "$input_variable=false" >>"$CONFIG_FILE"
            ;;
        *)
            echo "$validation_message"
            unset $input_variable
            ;;
        esac
    done
    echo "$input_variable=${!input_variable} (loaded from config)"
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
prompt_input_with_validation "Enter WEBHOOK_HOST (host/domain): " WEBHOOK_HOST "^(http:\/\/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+.*|https:\/\/[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?)$" "Error: WEBHOOK_HOST must be in the format http://host:port or https://domain."
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
prompt_input "Enter INBOUND_PORT: " INBOUND_PORT

# Running the command with user input
on_premises_agent.sh --ORGANIZATION_ID "$ORGANIZATION_ID" --WALLET_NAME "$WALLET_NAME" --WALLET_PASSWORD "$WALLET_PASSWORD" --WEBHOOK_HOST "$WEBHOOK_HOST" --WALLET_STORAGE_HOST "$WALLET_STORAGE_HOST" --WALLET_STORAGE_PORT "$WALLET_STORAGE_PORT" --WALLET_STORAGE_USER "$WALLET_STORAGE_USER" --WALLET_STORAGE_PASSWORD "$WALLET_STORAGE_PASSWORD" --AGENT_NAME "$AGENT_NAME" --PROTOCOL "$PROTOCOL" --TENANT "$TENANT" --CREDO_IMAGE "$CREDO_IMAGE" --INBOUND_ENDPOINT "$INBOUND_ENDPOINT" --ADMIN_PORT "$ADMIN_PORT" --INBOUND_PORT "$INBOUND_PORT"

# Run the command using user input
# on_premises_agent.sh --ORGANIZATION_ID "$ORGANIZATION_ID" --WALLET_NAME "$WALLET_NAME" --WALLET_PASSWORD "$WALLET_PASSWORD" --WEBHOOK_HOST "$WEBHOOK_HOST" --WALLET_STORAGE_HOST "$WALLET_STORAGE_HOST" --WALLET_STORAGE_PORT "$WALLET_STORAGE_PORT" --WALLET_STORAGE_USER "$WALLET_STORAGE_USER" --WALLET_STORAGE_PASSWORD "$WALLET_STORAGE_PASSWORD" --AGENT_NAME "$AGENT_NAME" --PROTOCOL "$PROTOCOL" --TENANT "$TENANT" --CREDO_IMAGE "$CREDO_IMAGE" --INBOUND_ENDPOINT "$INBOUND_ENDPOINT" --ADMIN_PORT "$ADMIN_PORT" --INBOUND_PORT "$INBOUND_PORT"

echo "admin port: $ADMIN_PORT"
echo "inbound port: $INBOUND_PORT"

echo "AGENT SPIN-UP STARTED"

if [ -d "${PWD}/${DIR}/agent-config" ]; then
    echo "agent-config directory exists."
else
    echo "Error: agent-config directory does not exists."
    mkdir ${PWD}/${DIR}/agent-config
fi

# Set ownership of the .educreds directory
sudo chown $USER: "$DIR"

# Define a regular expression pattern for IP address
IP_REGEX="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"

# Check if the input is a domain
if echo "$INBOUND_ENDPOINT" | grep -qP "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"; then
    echo "INBOUND_ENDPOINT is a domain: $INBOUND_ENDPOINT"
    AGENT_ENDPOINT=$INBOUND_ENDPOINT
else
    # Check if the input is an IP address
    if [[ $INBOUND_ENDPOINT =~ $IP_REGEX ]]; then
        echo "INBOUND_ENDPOINT is an IP address: $INBOUND_ENDPOINT"
        AGENT_ENDPOINT="${PROTOCOL}://${INBOUND_ENDPOINT}:${INBOUND_PORT}"
    else
        echo "Invalid input for INBOUND_ENDPOINT: $INBOUND_ENDPOINT"
    fi
fi

# Set permissions to restrict access to the agent-config directory
# chmod 700 "${PWD}/${DIR}/agent-config"
# echo "Permissions set to 700 for ${PWD}/${DIR}/agent-config"

echo "-----$AGENT_ENDPOINT----"
CONFIG_FILE="${PWD}/${DIR}/agent-config/${ORGANIZATION_ID}_${AGENT_NAME}.json"

# Check if the file exists
if [ -f "$CONFIG_FILE" ]; then
    # If it exists, remove the file
    rm "$CONFIG_FILE"
fi

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

# Check if the file exists
if [ -f "$DOCKER_COMPOSE" ]; then
    # If it exists, remove the file
    rm "$DOCKER_COMPOSE"
fi
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
      
    command: --auto-accept-connections --config /config.json
      
volumes:
  pgdata:
  agent-indy_client:
  agent-tmp:
EOF

# Set ownership and restrict permissions of the .educreds directory
# sudo chown -R $USER: "$DIR"
# chmod -R 700 "$DIR"

if [ $? -eq 0 ]; then
    cd ${PWD}/${DIR}
    echo "docker-compose generated successfully!"
    echo "================="
    echo "spinning up the container"
    echo "================="
    echo "container-name::::::${AGENT_NAME}"
    echo "file-name::::::$FILE_NAME"

    docker compose -p "${ORGANIZATION_ID}_${AGENT_NAME}" -f $FILE_NAME up -d
    if [ $? -eq 0 ]; then

        echo "Creating agent config"
        # Capture the logs from the container
        container_id=$(docker ps -q --filter "name=${ORGANIZATION_ID}_${AGENT_NAME}")

        if [ -z "$container_id" ]; then
            echo "Error: No container found with name ${ORGANIZATION_ID}_${AGENT_NAME}"
            exit 1
        fi

        # Wait for the container to generate logs
        retries=5
        delay=10
        while [ $retries -gt 0 ]; do
            container_logs=$(docker logs "$container_id" 2>/dev/null)
            if [ -n "$container_logs" ]; then
                break
            else
                echo "Waiting for logs to be generated..."
                sleep $delay
                retries=$((retries - 1))
            fi
        done

        if [ -z "$container_logs" ]; then
            echo "Error: No logs found for container ${ORGANIZATION_ID}_${AGENT_NAME} after waiting"
            exit 1
        fi

        # Extract the token from the logs using sed
        token=$(echo "$container_logs" | sed -nE 's/.*API Token: ([^ ]+).*/\1/p')

        if [ -z "$token" ]; then
            echo "Error: Failed to extract API token from logs"
            exit 1
        fi

        # Highlight the token line when printing
        highlighted_token="Token: \x1b[1;31m$token\x1b[0m"

        # Print the extracted token with highlighting
        echo -e "$highlighted_token"
        echo "Agent config created"

        # Check if the token exists to determine if the agent is running
        if [ -n "$token" ]; then
            echo "Agent is running"
        else
            echo "Agent is not running"
            exit 1
        fi

    else
        echo "==============="
        echo "ERROR : Failed to spin up the agent!"
        echo "===============" && exit 125
    fi
else
    echo "ERROR : Failed to execute!" && exit 125
fi

echo "Total time elapsed: $(date -ud "@$(($(date +%s) - $START_TIME))" +%T) (HH:MM:SS)"
