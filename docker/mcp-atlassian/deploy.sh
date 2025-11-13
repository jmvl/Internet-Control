#!/bin/bash

# MCP Atlassian Deployment Script for LXC 111
# Deploys and configures MCP Atlassian server on Docker

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       MCP Atlassian Server Deployment Script             ║${NC}"
echo -e "${BLUE}║       Target: LXC 111 (docker-debian)                     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo

# Configuration
DEPLOY_DIR="/root/mcp-atlassian"
PVE_HOST="pve2"
LXC_ID="111"

echo -e "${YELLOW}→${NC} Step 1: Creating deployment directory..."
ssh root@${PVE_HOST} "pct exec ${LXC_ID} -- mkdir -p ${DEPLOY_DIR}/{config,logs}"
echo -e "${GREEN}✓${NC} Directory created: ${DEPLOY_DIR}"

echo
echo -e "${YELLOW}→${NC} Step 2: Transferring files to LXC 111..."

# Transfer docker-compose.yml
cat docker-compose.yml | ssh root@${PVE_HOST} "pct exec ${LXC_ID} -- bash -c 'cat > ${DEPLOY_DIR}/docker-compose.yml'"
echo -e "${GREEN}✓${NC} Transferred: docker-compose.yml"

# Transfer .env.example
cat .env.example | ssh root@${PVE_HOST} "pct exec ${LXC_ID} -- bash -c 'cat > ${DEPLOY_DIR}/.env.example'"
echo -e "${GREEN}✓${NC} Transferred: .env.example"

# Transfer README.md
cat README.md | ssh root@${PVE_HOST} "pct exec ${LXC_ID} -- bash -c 'cat > ${DEPLOY_DIR}/README.md'"
echo -e "${GREEN}✓${NC} Transferred: README.md"

echo
echo -e "${YELLOW}→${NC} Step 3: Checking for existing .env file..."
if ssh root@${PVE_HOST} "pct exec ${LXC_ID} -- test -f ${DEPLOY_DIR}/.env" 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC}  .env file already exists, keeping existing configuration"
    echo -e "    To reconfigure: ssh root@${PVE_HOST} 'pct exec ${LXC_ID} -- nano ${DEPLOY_DIR}/.env'"
else
    # Copy .env.example to .env
    ssh root@${PVE_HOST} "pct exec ${LXC_ID} -- cp ${DEPLOY_DIR}/.env.example ${DEPLOY_DIR}/.env"
    echo -e "${GREEN}✓${NC} Created .env from template"
    echo -e "${YELLOW}⚠${NC}  IMPORTANT: You must edit .env with your credentials!"
fi

echo
echo -e "${YELLOW}→${NC} Step 4: Pulling Docker image..."
ssh root@${PVE_HOST} "pct exec ${LXC_ID} -- bash -c 'cd ${DEPLOY_DIR} && docker-compose pull'"
echo -e "${GREEN}✓${NC} Docker image pulled"

echo
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Deployment Complete!                     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${YELLOW}Next Steps:${NC}"
echo
echo -e "1. Configure your Atlassian credentials:"
echo -e "   ${BLUE}ssh root@${PVE_HOST} 'pct exec ${LXC_ID} -- nano ${DEPLOY_DIR}/.env'${NC}"
echo
echo -e "2. Start the MCP Atlassian server:"
echo -e "   ${BLUE}ssh root@${PVE_HOST} 'pct exec ${LXC_ID} -- bash -c \"cd ${DEPLOY_DIR} && docker-compose up -d\"'${NC}"
echo
echo -e "3. Check the logs:"
echo -e "   ${BLUE}ssh root@${PVE_HOST} 'pct exec ${LXC_ID} -- bash -c \"cd ${DEPLOY_DIR} && docker-compose logs -f\"'${NC}"
echo
echo -e "4. Verify health:"
echo -e "   ${BLUE}curl http://192.168.1.111:9000/health${NC}"
echo
echo -e "5. Update your Claude Code .mcp.json with:"
echo -e "   ${BLUE}\"url\": \"http://192.168.1.111:9000/mcp\"${NC}"
echo
echo -e "${YELLOW}Documentation:${NC}"
echo -e "   View README: ${BLUE}ssh root@${PVE_HOST} 'pct exec ${LXC_ID} -- cat ${DEPLOY_DIR}/README.md | less'${NC}"
echo
echo -e "${GREEN}Deployment files ready on LXC 111 at: ${DEPLOY_DIR}${NC}"
