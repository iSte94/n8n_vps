#!/bin/bash

# Stop Docker Compose
echo "🟢 Stopping Docker Compose..."
sudo -E docker compose down
echo "🔴 Docker Compose stopped."
echo ""

# Setup Ngrok
# Questi comandi verranno eseguiti ogni volta.
# wget scaricherà l'archivio, tar lo estrarrà (sovrascrivendo ngrok se già presente).
echo "🟢 Setting up Ngrok..."
wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz
sudo tar xvzf ./ngrok.tgz -C /usr/local/bin
rm ./ngrok.tgz # È buona pratica rimuovere l'archivio dopo l'estrazione
# Assicura che jq sia installato. apt update è una buona pratica prima di install.
sudo apt update > /dev/null 2>&1 # Esegui in background per non riempire l'output
sudo apt install -y jq
echo ""

# User input for Ngrok token and domain
echo "🔴🔴🔴 Please log in to dashboard.ngrok.com to get your Auth Token."
echo "   For the 'Ngrok Hostname', use your static subdomain provided by Ngrok (e.g., your-name.ngrok.app)."
read -p "Enter Ngrok Auth Token: " token
read -p "Enter your Ngrok Hostname (e.g., your-name.ngrok.app): " domain # 'domain' qui si riferisce al tuo hostname statico di Ngrok
echo ""

# Configure and start Ngrok
echo "🟢 Configuring Ngrok token..."
ngrok config add-authtoken "$token"

echo "🟢 Starting Ngrok for hostname '$domain' on local port 8080..."
# MODIFICATO: Utilizza --hostname, la porta corretta (8080), e il $domain (hostname) fornito.
# L'output di Ngrok viene inviato a /dev/null per mantenere pulito il terminale, come nell'originale.
ngrok http --hostname "$domain" 8080 > /dev/null &

# Wait for Ngrok to initialize
echo "🔴🔴🔴 Waiting for Ngrok to initialize..."
sleep 8 # Attesa fissa come nell'originale
echo ""

# Fetch public URL from Ngrok
echo "🟢 Fetching Ngrok public URL..."
# Tentativo di recuperare l'URL specifico per l'hostname.
# Se il tuo hostname in Ngrok è esattamente quello che hai inserito in $domain, questo dovrebbe funzionare.
export EXTERNAL_IP=$(curl -s http://localhost:4040/api/tunnels | jq -r --arg host "$domain" '.tunnels[] | select(.config.hostname == $host or .public_url | contains($host)) | .public_url')

# Fallback se l'URL specifico non viene trovato (potrebbe accadere se $domain non matcha perfettamente o se ci sono altri tunnel)
if [[ -z "$EXTERNAL_IP" || "$EXTERNAL_IP" == "null" ]]; then
    echo "   Warning: Could not find tunnel for specific hostname '$domain'. Trying to get the first available tunnel."
    export EXTERNAL_IP=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
fi

# Controllo finale se EXTERNAL_IP è stato ottenuto
if [[ -z "$EXTERNAL_IP" || "$EXTERNAL_IP" == "null" ]]; then
    echo "❌ ERROR: Failed to get Ngrok public URL."
    echo "   Please check Ngrok status (visit http://localhost:4040 in a browser on the VPS, if possible, or check ngrok logs if you change output redirection)."
    echo "   Ensure Ngrok is running and your hostname '$domain' is correct and active."
    exit 1
fi
echo "   Ngrok URL obtained: $EXTERNAL_IP"
echo ""

echo "🔴 Ngrok setup complete."
echo ""

# Start Docker Compose
echo "🟢 Starting Docker Compose..."
# La variabile EXTERNAL_IP (ora contenente l'URL di Ngrok) sarà usata da docker-compose.yml
sudo -E docker compose up -d
echo ""

# Messaggio Finale
echo "🔴🔴🔴 All done! 🔴🔴🔴"
echo "Please wait a few minutes for n8n to initialize inside Docker."
echo "Then visit the following URL to access the n8n UI:"
echo "$EXTERNAL_IP"
echo ""
echo "Note: Ngrok is running in the background. To stop everything, you'll need to stop Ngrok manually (e.g., 'killall ngrok' or find its PID) and then run 'sudo docker compose down'."
