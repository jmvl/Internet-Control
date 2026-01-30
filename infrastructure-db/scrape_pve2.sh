#!/bin/bash
#
# PVE2 Infrastructure Scraper
# Scrapes Proxmox PVE2 via SSH and updates infrastructure.db
#

# Configuration
PVE2_HOST="192.168.1.10"
PVE2_USER="root"
DB_PATH="/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_detail() { echo -e "${CYAN}  →${NC} $1"; }

# Get PVE2 host ID
get_pve2_host_id() {
    sqlite3 "$DB_PATH" "SELECT id FROM hosts WHERE hostname LIKE 'pve2%' OR management_ip = '$PVE2_HOST' LIMIT 1;"
}

# Upsert host
upsert_host() {
    local hostname="$1"
    local host_type="$2"
    local status="$3"
    local ip="$4"
    local cpu="$5"
    local ram="$6"
    local vmid="$7"
    local parent="$8"
    local purpose="$9"

    hostname=$(echo "$hostname" | sed "s/'//g;s/\"//g")
    purpose=$(echo "$purpose" | sed "s/'//g;s/\"//g")

    local existing=$(sqlite3 "$DB_PATH" "SELECT id FROM hosts WHERE hostname = '$hostname';")

    if [ -n "$existing" ]; then
        sqlite3 "$DB_PATH" "UPDATE hosts SET host_type='$host_type', status='$status',
            management_ip=$([ -n "$ip" ] && echo "'$ip'" || echo "NULL"),
            cpu_cores=$cpu, total_ram_mb=$ram, vmid=$vmid, updated_at=CURRENT_TIMESTAMP
            WHERE id=$existing;" 2>/dev/null
        echo "$existing"
    else
        sqlite3 "$DB_PATH" "INSERT INTO hosts (hostname,host_type,status,management_ip,cpu_cores,total_ram_mb,vmid,parent_host_id,purpose,criticality)
            VALUES ('$hostname','$host_type','$status',$([ -n "$ip" ] && echo "'$ip'" || echo "NULL"),$cpu,$ram,$vmid,$parent,'$purpose','medium');" 2>/dev/null
        sqlite3 "$DB_PATH" "SELECT last_insert_rowid();"
    fi
}

# Upsert proxmox container
upsert_proxmox_container() {
    local host_id="$1"
    local pve2_id="$2"
    local vmid="$3"
    local ctype="$4"
    local vmtype="${5:-}"
    local ostype="${6:-}"
    local ostpl="${7:-}"
    local unpriv="${8:-1}"
    local onboot="${9:-0}"

    vmtype=$(echo "$vmtype" | sed "s/'//g")
    ostype=$(echo "$ostype" | sed "s/'//g")
    ostpl=$(echo "$ostpl" | sed "s/'//g")

    local existing=$(sqlite3 "$DB_PATH" "SELECT id FROM proxmox_containers WHERE vmid=$vmid AND proxmox_host_id=$pve2_id;" 2>/dev/null)

    if [ -n "$existing" ]; then
        sqlite3 "$DB_PATH" "UPDATE proxmox_containers SET host_id=$host_id, container_type='$ctype',
            vmtype=$([ "$ctype" = "vm" ] && [ -n "$vmtype" ] && echo "'$vmtype'" || echo "NULL"),
            os_type=$([ "$ctype" = "vm" ] && [ -n "$ostype" ] && echo "'$ostype'" || echo "NULL"),
            os_template=$([ "$ctype" = "lxc" ] && [ -n "$ostpl" ] && echo "'$ostpl'" || echo "NULL"),
            unprivileged=$unpriv, auto_start=$onboot, updated_at=CURRENT_TIMESTAMP WHERE id=$existing;" 2>/dev/null
    else
        sqlite3 "$DB_PATH" "INSERT INTO proxmox_containers (host_id,proxmox_host_id,vmid,container_type,vm_type,os_type,os_template,unprivileged,auto_start)
            VALUES ($host_id,$pve2_id,$vmid,'$ctype',
            $([ "$ctype" = "vm" ] && [ -n "$vmtype" ] && echo "'$vmtype'" || echo "NULL"),
            $([ "$ctype" = "vm" ] && [ -n "$ostype" ] && echo "'$ostype'" || echo "NULL"),
            $([ "$ctype" = "lxc" ] && [ -n "$ostpl" ] && echo "'$ostpl'" || echo "NULL"),
            $unpriv,$onboot);" 2>/dev/null
    fi
}

# Main scrape
scrape_pve2() {
    log_info "Starting PVE2 infrastructure scrape..."

    local pve2_id=$(get_pve2_host_id)
    if [ -z "$pve2_id" ]; then
        log_error "PVE2 host not found in database"
        exit 1
    fi
    log_success "Found PVE2 host ID: $pve2_id"

    # Scrape LXC containers using direct query
    log_info "Scraping LXC containers..."
    local lxc_count=0

    while IFS='|' read -r vmid status rest; do
        [ -z "$vmid" ] && continue
        [[ "$vmid" =~ ^[0-9]+$ ]] || continue

        # Get config via SSH (use </dev/null to prevent reading from stdin)
        local config=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR root@192.168.1.10 "pct config $vmid" </dev/null 2>/dev/null)

        local name=$(echo "$config" | grep "^hostname:" | awk '{for(i=2;i<=NF;i++)printf $i" "}' | sed 's/ *$//')
        local cores=$(echo "$config" | grep "^cores:" | awk '{print $2}')
        local memory=$(echo "$config" | grep "^memory:" | awk '{print $2}')
        local ostpl=$(echo "$config" | grep "^ostemplate:" | awk '{print $2}')
        local onboot=$(echo "$config" | grep "^onboot:" | awk '{print $2}')
        local unpriv=$(echo "$config" | grep "^unprivileged:" | awk '{print $2}')
        local mgmt_ip=$(echo "$config" | grep "^net0:" | sed -n 's/.*ip=\([0-9.]*\).*/\1/p')

        cores=${cores:-1}
        memory=${memory:-512}
        onboot=${onboot:-0}
        unpriv=${unpriv:-1}

        local db_status="active"
        [[ "$status" == *"stopped"* ]] && db_status="stopped"

        log_detail "LXC: ${name:-VMID$vmid} (VMID: $vmid, Status: $status, IP: ${mgmt_ip:-none})"

        local host_id=$(upsert_host "${name:-ct-$vmid}" "lxc" "$db_status" "$mgmt_ip" "$cores" "$memory" "$vmid" "$pve2_id" "LXC on PVE2")
        upsert_proxmox_container "$host_id" "$pve2_id" "$vmid" "lxc" "" "" "$ostpl" "$unpriv" "$onboot"
        lxc_count=$((lxc_count + 1))
    done < <(ssh -o StrictHostKeyChecking=no root@192.168.1.10 "pct list" 2>/dev/null | grep -v "^[[:space:]]*VMID" | grep -v "^$" | awk '{print $1"|"$2}')

    log_success "Scraped $lxc_count LXC containers"

    # Scrape VMs
    log_info "Scraping VMs..."
    local vm_count=0

    while IFS='|' read -r vmid name status rest; do
        [ -z "$vmid" ] && continue
        [[ "$vmid" =~ ^[0-9]+$ ]] || continue

        local config=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR root@192.168.1.10 "qm config $vmid" </dev/null 2>/dev/null)

        local cores=$(echo "$config" | grep "^cores:" | awk '{print $2}')
        local sockets=$(echo "$config" | grep "^sockets:" | awk '{print $2}')
        local memory=$(echo "$config" | grep "^memory:" | awk '{print $2}')
        local ostype=$(echo "$config" | grep "^ostype:" | awk '{print $2}')
        local onboot=$(echo "$config" | grep "^onboot:" | awk '{print $2}')

        cores=${cores:-1}
        sockets=${sockets:-1}
        memory=${memory:-512}
        onboot=${onboot:-0}
        local total_cores=$((cores * sockets))

        local db_status="active"
        [[ "$status" == *"stopped"* ]] && db_status="stopped"

        log_detail "VM: $name (VMID: $vmid, CPUs: $total_cores, RAM: ${memory}MB)"

        local host_id=$(upsert_host "$name" "vm" "$db_status" "" "$total_cores" "$memory" "$vmid" "$pve2_id" "VM on PVE2")
        upsert_proxmox_container "$host_id" "$pve2_id" "$vmid" "vm" "qemu" "$ostype" "" "0" "$onboot"
        vm_count=$((vm_count + 1))
    done < <(ssh -o StrictHostKeyChecking=no root@192.168.1.10 "qm list" 2>/dev/null | grep -v "^[[:space:]]*VMID" | grep -v "^$" | awk '{print $1"|"$2"|"$3}')

    log_success "Scraped $vm_count VMs"

    # Summary
    log_info "Database Summary:"
    sqlite3 -column -header "$DB_PATH" "
        SELECT 'Hosts', COUNT(*) FROM hosts
        UNION ALL SELECT 'LXC', COUNT(*) FROM hosts WHERE host_type='lxc'
        UNION ALL SELECT 'VMs', COUNT(*) FROM hosts WHERE host_type='vm'
        UNION ALL SELECT 'Proxmox', COUNT(*) FROM proxmox_containers;" 2>/dev/null

    echo ""
    log_info "Proxmox Containers:"
    sqlite3 -column -header "$DB_PATH" "
        SELECT pc.vmid, h.hostname, pc.container_type, h.status, h.management_ip
        FROM proxmox_containers pc JOIN hosts h ON pc.host_id=h.id ORDER BY pc.vmid;" 2>/dev/null
}

scrape_pve2
