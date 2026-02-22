#!/usr/bin/env bash
# postgres-lab run script — boots a VM with PostgreSQL for database practice

set -euo pipefail

PLUGIN_NAME="postgres-lab"

echo "============================================="
echo "  postgres-lab: PostgreSQL Database Lab"
echo "============================================="
echo ""
echo "  This lab demonstrates:"
echo "    1. Provisioning PostgreSQL via cloud-init"
echo "    2. Creating databases, tables, and queries"
echo "    3. Managing users and permissions"
echo "    4. Performing backups and restores with pg_dump"
echo "    5. Managing databases visually with pgAdmin"
echo ""

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run ${PLUGIN_NAME}'."
    exit 1
fi

for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [[ -f "$lib_file" ]] && source "$lib_file"
done

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-.qlab}"
LAB_DIR="lab"
IMAGE_DIR="$WORKSPACE_DIR/images"
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img")
CLOUD_IMAGE_FILE="$IMAGE_DIR/ubuntu-22.04-minimal-cloudimg-amd64.img"
MEMORY="${QLAB_MEMORY:-$(get_config DEFAULT_MEMORY 2048)}"

# Ensure directories exist
mkdir -p "$LAB_DIR" "$IMAGE_DIR"

# Step 1: Download cloud image if not present
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    echo ""
    echo "  Cloud images are pre-built OS images designed for cloud environments."
    echo "  They are minimal and expect cloud-init to configure them on first boot."
    echo ""
    info "Downloading Ubuntu cloud image..."
    echo "  URL: $CLOUD_IMAGE_URL"
    echo "  This may take a few minutes depending on your connection."
    echo ""
    check_dependency curl || exit 1
    curl -L -o "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL" || {
        error "Failed to download cloud image."
        echo "  Check your internet connection and try again."
        exit 1
    }
    success "Cloud image downloaded: $CLOUD_IMAGE_FILE"
fi
echo ""

# Step 2: Create cloud-init configuration
info "Step 2: Cloud-init configuration"
echo ""
echo "  cloud-init will:"
echo "    - Create a user 'labuser' with SSH access"
echo "    - Install PostgreSQL server and pgAdmin4"
echo "    - Create a sample database with test data"
echo "    - Create a PostgreSQL 'labuser' with privileges on the test DB"
echo "    - Configure pgAdmin4 for web-based database management"
echo ""

cat > "$LAB_DIR/user-data" <<'USERDATA'
#cloud-config
hostname: postgres-lab
package_update: true
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
packages:
  - postgresql
  - postgresql-client
  - postgresql-contrib
  - apache2
  - curl
  - gnupg2
  - lsb-release
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mpostgres-lab\033[0m — \033[1mPostgreSQL Database Lab\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mObjectives:\033[0m
          • connect to PostgreSQL and explore databases
          • create databases, tables, and run queries
          • manage users and permissions
          • perform backups and restores
          • use pgAdmin for visual database management

        \033[1;33mPostgreSQL Commands:\033[0m
          \033[0;32msudo -u postgres psql\033[0m                connect as superuser
          \033[0;32mpsql -U labuser -d testdb\033[0m            connect as labuser
          \033[0;32msudo systemctl status postgresql\033[0m     service status

        \033[1;33mSample Database:\033[0m
          \033[0;32m\dt\033[0m                                  list tables
          \033[0;32mSELECT * FROM users;\033[0m

        \033[1;33mBackup & Restore:\033[0m
          \033[0;32mpg_dump -U labuser testdb > backup.sql\033[0m
          \033[0;32mpsql -U labuser testdb < backup.sql\033[0m

        \033[1;33mpgAdmin (web interface):\033[0m
          Inside VM:  \033[0;32mhttp://localhost/pgadmin4/\033[0m
          From host:  \033[0;32mhttp://localhost:<HTTP_PORT>/pgadmin4/\033[0m
          Login:      \033[1;36mlabuser@lab.example.com\033[0m / \033[1;36mlabpass\033[0m

        \033[1;33mFrom the host:\033[0m  run \033[0;32mqlab ports\033[0m to see port numbers
          PostgreSQL: \033[0;32mpsql -h 127.0.0.1 -p <PG_PORT> -U labuser -d testdb\033[0m
          pgAdmin:    \033[0;32mhttp://localhost:<HTTP_PORT>/pgadmin4/\033[0m

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m


  - path: /home/labuser/sample_data.sql
    permissions: '0644'
    content: |
      CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          name VARCHAR(50) NOT NULL,
          email VARCHAR(100),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      INSERT INTO users (name, email) VALUES
          ('Alice', 'alice@example.com'),
          ('Bob', 'bob@example.com'),
          ('Charlie', 'charlie@example.com');

      CREATE TABLE IF NOT EXISTS orders (
          id SERIAL PRIMARY KEY,
          user_id INT NOT NULL,
          product VARCHAR(100) NOT NULL,
          amount DECIMAL(10,2),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users(id)
      );
      INSERT INTO orders (user_id, product, amount) VALUES
          (1, 'Laptop', 999.99),
          (2, 'Mouse', 29.99),
          (1, 'Keyboard', 79.99),
          (3, 'Monitor', 349.99);
  - path: /tmp/pgadmin_setup.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -e
      # Add pgAdmin4 APT repository
      curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | gpg --dearmor -o /usr/share/keyrings/pgadmin-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/pgadmin-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list
      apt-get update
      apt-get install -y pgadmin4-web
      # Configure pgAdmin4 non-interactively
      export PGADMIN_SETUP_EMAIL="labuser@lab.example.com"
      export PGADMIN_SETUP_PASSWORD="labpass"
      /usr/pgadmin4/bin/setup-web.sh --yes
      # Confirm the user account (pgAdmin 9.x does not auto-confirm)
      python3 -c "
      import sqlite3, datetime
      conn = sqlite3.connect('/var/lib/pgadmin/pgadmin4.db')
      c = conn.cursor()
      c.execute('UPDATE user SET confirmed_at = ? WHERE confirmed_at IS NULL', (datetime.datetime.now().isoformat(),))
      conn.commit()
      conn.close()
      "
runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - |
    # Configure PostgreSQL to listen on all interfaces
    PG_CONF=$(find /etc/postgresql -name postgresql.conf | head -1)
    PG_HBA=$(find /etc/postgresql -name pg_hba.conf | head -1)
    sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" "$PG_CONF"
    sed -i "s/scram-sha-256/md5/g" "$PG_HBA"
    echo "host    all             all             0.0.0.0/0               md5" >> "$PG_HBA"
    systemctl restart postgresql
  - |
    # Create labuser and sample database
    sudo -u postgres psql -c "CREATE USER labuser WITH PASSWORD 'labpass';"
    sudo -u postgres psql -c "CREATE DATABASE testdb OWNER labuser;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE testdb TO labuser;"
    sudo -u postgres psql -d testdb -f /home/labuser/sample_data.sql
    sudo -u postgres psql -d testdb -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO labuser;"
    sudo -u postgres psql -d testdb -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO labuser;"
    sudo -u postgres psql -c "ALTER USER labuser CREATEDB;"
  - |
    # Install and configure pgAdmin4
    bash /tmp/pgadmin_setup.sh
  - chown -R labuser:labuser /home/labuser
  - echo "=== postgres-lab VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data"

cat > "$LAB_DIR/meta-data" <<METADATA
instance-id: ${PLUGIN_NAME}-001
local-hostname: ${PLUGIN_NAME}
METADATA

success "Created cloud-init files in $LAB_DIR/"
echo ""

# Step 3: Generate cloud-init ISO
info "Step 3: Cloud-init ISO"
echo ""
echo "  QEMU reads cloud-init data from a small ISO image (CD-ROM)."
echo "  We use genisoimage to create it with the 'cidata' volume label."
echo ""

CIDATA_ISO="$LAB_DIR/cidata.iso"
check_dependency genisoimage || {
    warn "genisoimage not found. Install it with: sudo apt install genisoimage"
    exit 1
}
genisoimage -output "$CIDATA_ISO" -volid cidata -joliet -rock \
    "$LAB_DIR/user-data" "$LAB_DIR/meta-data" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_ISO"
echo ""

# Step 4: Create overlay disk
info "Step 4: Overlay disk"
echo ""
echo "  An overlay disk uses copy-on-write (COW) on top of the base image."
echo "  This means:"
echo "    - The original cloud image stays untouched"
echo "    - All writes go to the overlay file"
echo "    - You can reset the lab by deleting the overlay"
echo ""

OVERLAY_DISK="$LAB_DIR/${PLUGIN_NAME}-disk.qcow2"
if [[ -f "$OVERLAY_DISK" ]]; then
    info "Removing previous overlay disk..."
    rm -f "$OVERLAY_DISK"
fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_DISK" "${QLAB_DISK_SIZE:-6G}" || {
    error "Failed to create overlay disk."
    exit 1
}
echo ""

# Step 5: Boot the VM in background with PostgreSQL port forwarding
info "Step 5: Starting VM in background"
echo ""
echo "  The VM will run in background with:"
echo "    - Serial output logged to .qlab/logs/$PLUGIN_NAME.log"
echo "    - SSH access on a dynamically allocated port"
echo "    - PostgreSQL access on a dynamically allocated port (forwarded to VM port 5432)"
echo "    - pgAdmin (HTTP) on a dynamically allocated port (forwarded to VM port 80)"
echo ""

start_vm "$OVERLAY_DISK" "$CIDATA_ISO" "$MEMORY" "$PLUGIN_NAME" auto \
    "hostfwd=tcp::0-:5432" \
    "hostfwd=tcp::0-:80"

# Read the dynamically allocated ports from .ports file
PG_PORT=""
PGADMIN_PORT=""
if [[ -f "$STATE_DIR/${PLUGIN_NAME}.ports" ]]; then
    PG_PORT=$(grep ':5432$' "$STATE_DIR/${PLUGIN_NAME}.ports" | head -1 | cut -d: -f2)
    PGADMIN_PORT=$(grep ':80$' "$STATE_DIR/${PLUGIN_NAME}.ports" | head -1 | cut -d: -f2)
fi

echo ""
echo "============================================="
echo "  postgres-lab: VM is booting"
echo "============================================="
echo ""
echo "  Credentials: labuser / labpass"
echo ""
echo "  SSH (wait ~90s for boot + package install):"
echo "    qlab shell ${PLUGIN_NAME}"
echo ""
echo "  PostgreSQL (after boot completes):"
echo "    Inside VM:  sudo -u postgres psql"
if [[ -n "$PG_PORT" ]]; then
echo "    From host:  psql -h 127.0.0.1 -p ${PG_PORT} -U labuser -d testdb"
else
echo "    From host:  psql -h 127.0.0.1 -p <port> -U labuser -d testdb"
fi
echo ""
echo "  ---------------------------------------------"
echo "  pgAdmin (web interface):"
if [[ -n "$PGADMIN_PORT" ]]; then
echo "    URL:   http://localhost:${PGADMIN_PORT}/pgadmin4/"
else
echo "    URL:   http://localhost:<port>/pgadmin4/"
fi
echo "    Login: labuser@lab.example.com / labpass"
echo "  ---------------------------------------------"
echo ""
echo "  Active ports:  qlab ports"
echo "  View boot log: qlab log ${PLUGIN_NAME}"
echo "  Stop VM:       qlab stop ${PLUGIN_NAME}"
echo ""
echo "  Tip: QLAB_MEMORY=4096 QLAB_DISK_SIZE=30G qlab run ${PLUGIN_NAME}"
echo "============================================="
