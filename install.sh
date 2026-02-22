#!/usr/bin/env bash
# postgres-lab install script

set -euo pipefail

echo ""
echo "  [postgres-lab] Installing..."
echo ""
echo "  This plugin demonstrates how to install and manage PostgreSQL"
echo "  databases inside a QEMU virtual machine."
echo ""
echo "  What you will learn:"
echo "    - How to connect to PostgreSQL and run queries"
echo "    - How to create databases, tables, and insert data"
echo "    - How to manage users and permissions"
echo "    - How to perform backups and restores with pg_dump"
echo "    - How to access PostgreSQL from the host via port forwarding"
echo "    - How to use pgAdmin for web-based database management"
echo ""

# Create lab working directory
mkdir -p lab

# Check for required tools
echo "  Checking dependencies..."
local_ok=true
for cmd in qemu-system-x86_64 qemu-img genisoimage curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "    [OK] $cmd"
    else
        echo "    [!!] $cmd — not found (install before running)"
        local_ok=false
    fi
done

if [[ "$local_ok" == true ]]; then
    echo ""
    echo "  All dependencies are available."
else
    echo ""
    echo "  Some dependencies are missing. Install them with:"
    echo "    sudo apt install qemu-kvm qemu-utils genisoimage curl"
fi

echo ""
echo "  [postgres-lab] Installation complete."
echo "  Run with: qlab run postgres-lab"
