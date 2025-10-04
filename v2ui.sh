#!/bin/bash
# V2Ray Auto Installer & Manager (VMess + AES-128-GCM + WS)
# By ChatGPT

CONFIG_PATH="/usr/local/etc/v2ray/config.json"
CLIENTS_FILE="/usr/local/etc/v2ray/clients.txt"

# Ensure jq, qrencode, curl
apt install -y jq qrencode curl >/dev/null 2>&1

get_ipv4() {
    curl -s4 ifconfig.me
}

generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

create_server_config() {
    UUID=$1
    PORT=10086
    WSPATH="/ray"

    cat > $CONFIG_PATH <<EOF
{
  "inbounds": [
    {
      "port": $PORT,
      "listen": "0.0.0.0",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$WSPATH"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

    systemctl restart v2ray
}

create_client_config() {
    UUID=$1
    IP=$(get_ipv4)
    PORT=10086
    WSPATH="/ray"

    CLIENT_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "My-V2Ray",
  "add": "$IP",
  "port": "$PORT",
  "id": "$UUID",
  "aid": "0",
  "security": "aes-128-gcm",
  "net": "ws",
  "type": "none",
  "host": "",
  "path": "$WSPATH",
  "tls": "none"
}
EOF
)

    VMESS_BASE64=$(echo -n "$CLIENT_JSON" | base64 -w0)
    VMESS_URL="vmess://$VMESS_BASE64"

    echo -e "\n--- Client Config ---"
    echo "$CLIENT_JSON" | jq .
    echo -e "\nVMess URL: $VMESS_URL"
    echo -e "\nQR Code:"
    echo "$VMESS_URL" | qrencode -t ANSIUTF8

    # Save client config
    echo -e "\n$CLIENT_JSON" >> $CLIENTS_FILE
    echo -e "\nSaved in $CLIENTS_FILE"
}

menu() {
    clear
    echo "==============================="
    echo " V2Ray Manager"
    echo "==============================="
    echo "1) Fresh Install V2Ray"
    echo "2) Add New Client UUID"
    echo "3) Show Saved Client Configs"
    echo "4) Exit"
    echo "==============================="
    read -p "Select option [1-4]: " choice

    case $choice in
        1)
            UUID=$(generate_uuid)
            echo "Installing V2Ray..."
            bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
            create_server_config "$UUID"
            create_client_config "$UUID"
            ;;
        2)
            UUID=$(generate_uuid)
            # Insert new UUID into config.json
            jq --arg uuid "$UUID" '.inbounds[0].settings.clients += [{"id":$uuid,"alterId":0}]' $CONFIG_PATH > /tmp/config.json && mv /tmp/config.json $CONFIG_PATH
            systemctl restart v2ray
            create_client_config "$UUID"
            ;;
        3)
            echo -e "\n--- Saved Clients ---"
            cat $CLIENTS_FILE
            ;;
        4)
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Run menu
menu
