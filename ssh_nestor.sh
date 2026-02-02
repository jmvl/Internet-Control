#!/bin/bash
#
# SSH Test Script for OpenClaw LXC Container (nestor)
# Tests bidirectional SSH authentication between nestor and macOS
#
# Usage: ./ssh_nestor.sh [test|status|exec]
#

set -e

# Configuration
NESTOR_HOST="root@pve2"
NESTOR_CONTAINER="101"
NESTOR_IP="192.168.1.151"
MACOS_USER="jm"
MACOS_IP="192.168.1.165"
NESTOR_SSH_KEY="/root/.ssh/id_rsa"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test 1: Check if nestor container is running
test_nestor_running() {
    log_info "Test 1: Checking if nestor container is running..."
    if ssh "${NESTOR_HOST}" "pct status ${NESTOR_CONTAINER}" | grep -q "status: running"; then
        log_info "✓ Nestor container is running"
        return 0
    else
        log_error "✗ Nestor container is not running"
        return 1
    fi
}

# Test 2: Check network connectivity to nestor
test_nestor_connectivity() {
    log_info "Test 2: Checking network connectivity to nestor..."
    if ping -c 2 -W 2 "${NESTOR_IP}" >/dev/null 2>&1; then
        log_info "✓ Network connectivity to nestor OK"
        return 0
    else
        log_error "✗ Cannot reach nestor at ${NESTOR_IP}"
        return 1
    fi
}

# Test 3: Check macOS SSH server
test_macos_ssh_server() {
    log_info "Test 3: Checking macOS SSH server..."
    if netstat -an | grep "\.22 " | grep -q LISTEN; then
        log_info "✓ macOS SSH server is listening on port 22"
        return 0
    else
        log_error "✗ macOS SSH server is not running"
        return 1
    fi
}

# Test 4: SSH from macOS to nestor
test_ssh_to_nestor() {
    log_info "Test 4: Testing SSH from macOS to nestor..."
    local hostname
    hostname=$(ssh "${NESTOR_HOST}" "pct exec ${NESTOR_CONTAINER} -- hostname" 2>/dev/null)
    if echo "$hostname" | grep -qE "(nestor|openclaw)"; then
        log_info "✓ SSH from macOS to nestor successful (hostname: $hostname)"
        return 0
    else
        log_error "✗ Cannot SSH from macOS to nestor"
        return 1
    fi
}

# Test 5: SSH from nestor to macOS
test_ssh_from_nestor() {
    log_info "Test 5: Testing SSH from nestor to macOS..."
    local result
    result=$(ssh "${NESTOR_HOST}" "pct exec ${NESTOR_CONTAINER} -- ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${MACOS_USER}@${MACOS_IP} 'echo SUCCESS'" 2>&1)

    if echo "$result" | grep -q "SUCCESS"; then
        log_info "✓ SSH from nestor to macOS successful"
        return 0
    else
        log_error "✗ Cannot SSH from nestor to macOS"
        echo "$result" | head -5
        return 1
    fi
}

# Test 6: Check SSH key existence on nestor
test_nestor_ssh_key() {
    log_info "Test 6: Checking SSH key on nestor..."
    local key_exists
    key_exists=$(ssh "${NESTOR_HOST}" "pct exec ${NESTOR_CONTAINER} -- test -f ${NESTOR_SSH_KEY} && echo 'EXISTS'" 2>/dev/null)

    if [ "$key_exists" = "EXISTS" ]; then
        log_info "✓ SSH private key exists on nestor"
        return 0
    else
        log_error "✗ SSH private key not found on nestor"
        return 1
    fi
}

# Test 7: Check SSH key in macOS authorized_keys
test_macos_authorized_keys() {
    log_info "Test 7: Checking nestor's key in macOS authorized_keys..."
    local nestor_pubkey
    nestor_pubkey=$(ssh "${NESTOR_HOST}" "pct exec ${NESTOR_CONTAINER} -- cat /root/.ssh/id_rsa.pub" 2>/dev/null)

    if grep -q "$(echo "$nestor_pubkey" | awk '{print $2}')" ~/.ssh/authorized_keys 2>/dev/null; then
        log_info "✓ Nestor's public key is in macOS authorized_keys"
        return 0
    else
        log_error "✗ Nestor's public key not found in macOS authorized_keys"
        return 1
    fi
}

# Test 8: Execute remote command on macOS from nestor
test_remote_command() {
    log_info "Test 8: Testing remote command execution..."
    local result
    result=$(ssh "${NESTOR_HOST}" "pct exec ${NESTOR_CONTAINER} -- ssh -o BatchMode=yes ${MACOS_USER}@${MACOS_IP} 'whoami && hostname'" 2>&1)

    if echo "$result" | grep -q "${MACOS_USER}"; then
        log_info "✓ Remote command execution successful"
        log_info "  Result: $result"
        return 0
    else
        log_error "✗ Remote command execution failed"
        return 1
    fi
}

# Main test runner
run_all_tests() {
    log_info "Starting SSH authentication tests..."
    log_info "========================================"

    local tests=(
        "test_nestor_running"
        "test_nestor_connectivity"
        "test_macos_ssh_server"
        "test_ssh_to_nestor"
        "test_nestor_ssh_key"
        "test_macos_authorized_keys"
        "test_ssh_from_nestor"
        "test_remote_command"
    )

    local passed=0
    local failed=0
    local total=${#tests[@]}

    for test in "${tests[@]}"; do
        if $test; then
            ((passed++))
        else
            ((failed++))
        fi
        echo ""
    done

    log_info "========================================"
    log_info "Test Results: ${passed}/${total} passed"

    if [ $failed -eq 0 ]; then
        log_info "✓ All tests passed!"
        return 0
    else
        log_error "✗ ${failed} test(s) failed"
        return 1
    fi
}

# Show status
show_status() {
    log_info "SSH Authentication Status"
    log_info "=========================="
    echo ""
    echo "Nestor Container:"
    echo "  Container ID: ${NESTOR_CONTAINER}"
    echo "  IP Address: ${NESTOR_IP}"
    echo "  Access: ssh ${NESTOR_HOST} \"pct exec ${NESTOR_CONTAINER} -- <command>\""
    echo ""
    echo "macOS Development Machine:"
    echo "  IP Address: ${MACOS_IP}"
    echo "  User: ${MACOS_USER}"
    echo ""
    echo "SSH Key Information:"
    local fingerprint
    fingerprint=$(ssh "${NESTOR_HOST}" "pct exec ${NESTOR_CONTAINER} -- ssh-keygen -lf /root/.ssh/id_rsa.pub" 2>/dev/null | awk '{print $2}')
    echo "  Nestor Key Fingerprint: ${fingerprint}"
    echo ""
    echo "Documentation:"
    echo "  /docs/openclaw/ssh-authentication-setup-2026-01-31.md"
}

# Execute command on nestor
exec_on_nestor() {
    local cmd="$*"
    if [ -z "$cmd" ]; then
        log_error "No command specified"
        echo "Usage: $0 exec <command>"
        exit 1
    fi

    log_info "Executing command on nestor: $cmd"
    ssh "${NESTOR_HOST}" "pct exec ${NESTOR_CONTAINER} -- $cmd"
}

# Execute command on macOS from nestor
exec_on_macos_from_nestor() {
    local cmd="$*"
    if [ -z "$cmd" ]; then
        log_error "No command specified"
        echo "Usage: $0 tunnel <command>"
        exit 1
    fi

    log_info "Executing command on macOS (via nestor): $cmd"
    ssh "${NESTOR_HOST}" "pct exec ${NESTOR_CONTAINER} -- ssh -o BatchMode=yes ${MACOS_USER}@${MACOS_IP} '$cmd'"
}

# Main
case "${1:-test}" in
    test)
        run_all_tests
        ;;
    status)
        show_status
        ;;
    exec)
        exec_on_nestor "${@:2}"
        ;;
    tunnel)
        exec_on_macos_from_nestor "${@:2}"
        ;;
    *)
        echo "Usage: $0 {test|status|exec|tunnel}"
        echo ""
        echo "Commands:"
        echo "  test     - Run all SSH authentication tests"
        echo "  status   - Show SSH authentication status"
        echo "  exec     - Execute command on nestor"
        echo "  tunnel   - Execute command on macOS via nestor"
        echo ""
        echo "Examples:"
        echo "  $0 test"
        echo "  $0 status"
        echo "  $0 exec 'ls -la /root/.ssh'"
        echo "  $0 tunnel 'ls -la ~'"
        exit 1
        ;;
esac
