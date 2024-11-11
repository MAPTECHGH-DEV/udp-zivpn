#!/bin/bash
# Zivpn UDP Module installer with password protection and Telegram verification
# Creator Zahid Islam

# Set your Telegram bot TOKEN and CHAT_ID
TELEGRAM_TOKEN="7644668358:AAGo4HM-z8_1UDF_rnvtN2GKcQY7z1EuaIk"
CHAT_ID="5989863155"

# Function to send a message to Telegram with error handling
send_telegram_message() {
    response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="$1")
    
    # Check if the message was sent successfully
    if ! grep -q '"ok":true' <<< "$response"; then
        echo "Failed to send message to Telegram: $response"
        exit 1
    fi
}

# Prompt for password
echo -e "Enter installation password:"
read -s user_password

# Define the correct password
correct_password="your_password_here"

if [ "$user_password" != "$correct_password" ]; then
    echo "Incorrect password. Exiting."
    exit 1
fi

# Generate a random verification code and send to Telegram
verification_code=$((RANDOM % 10000 + 1000))
echo "Generated verification code (for debug): $verification_code"  # Remove or comment this line after testing
send_telegram_message "Your Zivpn verification code: ${verification_code}"

# Prompt the user to enter the verification code received on Telegram
echo -e "Enter the verification code sent to your Telegram:"
read user_code

# Verify the code
if [ "$user_code" != "$verification_code" ]; then
    echo "Incorrect verification code. Exiting."
    exit 1
fi

# Proceed with installation
echo -e "Updating server"
sudo apt-get update && apt-get upgrade -y
systemctl stop zivpn.service 1> /dev/null 2> /dev/null
echo -e "Downloading UDP Service"
wget https://github.com/MAPTECHGH-DEV/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn
mkdir /etc/zivpn 1> /dev/null 2> /dev/null
wget https://raw.githubusercontent.com/MAPTECHGH-DEV/udp-zivpn/main/config.json -O /etc/zivpn/config.json 1> /dev/null 2> /dev/null

echo "Generating cert files:"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"
sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

echo -e "ZIVPN UDP Passwords"
read -p "Enter passwords separated by commas, example: pass1,pass2 (Press enter for Default 'zi'): " input_config

if [ -n "$input_config" ]; then
    IFS=',' read -r -a config <<< "$input_config"
    if [ ${#config[@]} -eq 1 ]; then
        config+=(${config[0]})
    fi
else
    config=("zi")
fi

new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"

sed -i -E "s/\"config\": ?\[[[:space:]]*\"zi\"[[:space:]]*\]/${new_config_str}/g" /etc/zivpn/config.json

systemctl enable zivpn.service
systemctl start zivpn.service
iptables -t nat -A PREROUTING -i $(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1) -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp
ufw allow 5667/udp
rm zi.* 1> /dev/null 2> /dev/null
echo -e "MAPTECH ZIVPN UDP Installed"


