#!/bin/bash

set -e

# --- Configuratie ---
read -p "Enter RDS endpoint (e.g., db1.c7cmqcsaq1q3.us-east-1.rds.amazonaws.com): " DB_SERVER
if [ -z "$DB_SERVER" ]; then
    echo "✗ RDS endpoint is required"
    exit 1
fi

read -p "Enter S3 bucket Name: " S3_BUCKET
if [ -z "$S3_BUCKET" ]; then
    echo "✗ S3 bucket Name is required"
    exit 1
fi

DB_USER="csadmin"
DB_PASSWORD="cspasswd"
DB_NAME="Microsoft.eShopOnWeb.CatalogDb"
EXPORT_FILE="/tmp/orders_export.csv"

# --- BCP installatie check ---
if ! command -v bcp &> /dev/null; then
    echo "ℹ Installing mssql-tools18..."
    sudo tee /etc/yum.repos.d/mssql-release.repo > /dev/null << 'EOF'
[mssql-release]
name=Microsoft SQL Server Release
baseurl=https://packages.microsoft.com/rhel/9/prod/
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    sudo dnf update -y
    sudo dnf install -y unixODBC unixODBC-devel
    sudo ACCEPT_EULA=Y dnf install -y mssql-tools18
    export PATH="$PATH:/opt/mssql-tools18/bin"
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
else
    export PATH="$PATH:/opt/mssql-tools18/bin"
fi

# --- Export Orders tabel ---
echo "ℹ Exporting Orders table from $DB_SERVER..."
/opt/mssql-tools18/bin/bcp "SELECT * FROM Orders" queryout "$EXPORT_FILE" \
    -S "$DB_SERVER,1433;Encrypt=Optional;TrustServerCertificate=yes" \
    -U "$DB_USER" \
    -P "$DB_PASSWORD" \
    -d "$DB_NAME" \
    -c \
    -t ","

# --- Upload naar S3 ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
S3_KEY="orders/orders_$TIMESTAMP.csv"

echo "ℹ Uploading $EXPORT_FILE to s3://$S3_BUCKET/$S3_KEY..."
aws s3 cp "$EXPORT_FILE" "s3://$S3_BUCKET/$S3_KEY"

# --- Cleanup ---
rm -f "$EXPORT_FILE"
echo "✓ Done: s3://$S3_BUCKET/$S3_KEY"
