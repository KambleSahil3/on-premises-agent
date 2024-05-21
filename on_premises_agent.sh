#!/bin/bash

START_TIME=$(date +%s)
DIR=".educreds"
CONFIG_FILE="${PWD}/${DIR}/agent-config/parameters.conf"

# Ensure we are running in an interactive shell
if [[ ! -t 0 ]]; then
    echo "Error: This script must be run in an interactive shell."
    exit 1
fi

# Create the .educreds directory and the agent-config directory if they do not exist
if [ ! -d "$DIR/agent-config" ]; then
    mkdir -p "$DIR/agent-config"
fi

# Create the configuration file if it does not exist
if [ ! -f "$CONFIG_FILE" ]; then
    touch "$CONFIG_FILE"
fi

# Set permissions on the configuration file
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

# Load parameters from the configuration file if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Create a new configuration file
    touch "$CONFIG_FILE"
fi

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
