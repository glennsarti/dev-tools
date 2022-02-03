#!/bin/sh

# Set our variables
cat <<EOF > /etc/nginx/ssl/req.cnf
[req]
distinguished_name = req_distinguished_name
req_extensions  = v3_req
prompt = no

[req_distinguished_name]
commonName = *.ngrok.io

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1   = *.ngrok.io
DNS.2   = $TFE_FQDN
EOF

FLAG="/etc/nginx/ssl/$TFE_FQDN.flag"
if [ ! -f $FLAG ]; then
  echo "Creating Private Key for $TFE_FQDN...."
  openssl genrsa -out /etc/nginx/ssl/atlas.key 2048

  echo "Creating Certificate Signing Request for for $TFE_FQDN...."
  openssl req -new -key /etc/nginx/ssl/atlas.key -out /etc/nginx/ssl/atlas.csr -config /etc/nginx/ssl/req.cnf

  echo "Creating Certificate for for $TFE_FQDN...."
  openssl x509 -req -in /etc/nginx/ssl/atlas.csr -CA /etc/nginx/internal-ca.crt -CAkey /etc/nginx/internal-ca.pem -CAcreateserial -out /etc/nginx/ssl/atlas.crt -days 825 -sha256 -extensions v3_req -extfile /etc/nginx/ssl/req.cnf

  rm -f /etc/nginx/ssl/*.flag
  touch $FLAG
else
  echo "Self Signed Certificates exist"
fi

echo "Calling original entrypoint ..."
sh /tmp/entrypoint.sh
