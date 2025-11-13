#!/bin/bash

# MCP Atlassian Management Script
# Quick management commands for the MCP Atlassian server

set -e

DEPLOY_DIR="/root/mcp-atlassian"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo -e "${BLUE}MCP Atlassian Management Script${NC}"
    echo
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  start       - Start the MCP Atlassian server"
    echo "  stop        - Stop the MCP Atlassian server"
    echo "  restart     - Restart the server"
    echo "  status      - Show server status"
    echo "  logs        - Show logs (follow mode)"
    echo "  logs-tail   - Show last 50 lines of logs"
    echo "  health      - Check server health endpoint"
    echo "  update      - Pull latest image and restart"
    echo "  config      - Edit .env configuration"
    echo "  clean       - Stop and remove containers (preserves OAuth tokens)"
    echo "  clean-all   - Stop and remove everything including volumes (CAUTION)"
    echo
}

cd "$DEPLOY_DIR" || {
    echo -e "${RED}Error: Cannot access $DEPLOY_DIR${NC}"
    exit 1
}

case "$1" in
    start)
        echo -e "${YELLOW}→${NC} Starting MCP Atlassian server..."
        docker compose up -d
        echo -e "${GREEN}✓${NC} Server started"
        docker compose ps
        ;;
    stop)
        echo -e "${YELLOW}→${NC} Stopping MCP Atlassian server..."
        docker compose down
        echo -e "${GREEN}✓${NC} Server stopped"
        ;;
    restart)
        echo -e "${YELLOW}→${NC} Restarting MCP Atlassian server..."
        docker compose restart
        echo -e "${GREEN}✓${NC} Server restarted"
        docker compose ps
        ;;
    status)
        docker compose ps
        echo
        echo -e "${BLUE}Container details:${NC}"
        docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
        ;;
    logs)
        echo -e "${BLUE}Showing logs (Ctrl+C to exit)...${NC}"
        docker compose logs -f
        ;;
    logs-tail)
        docker compose logs --tail=50
        ;;
    health)
        echo -e "${YELLOW}→${NC} Checking health endpoint..."
        if curl -sf http://localhost:9000/health >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Server is healthy"
            curl -s http://localhost:9000/health | jq . || curl -s http://localhost:9000/health
        else
            echo -e "${RED}✗${NC} Server health check failed"
            echo "  Try: curl -v http://localhost:9000/health"
            exit 1
        fi
        ;;
    update)
        echo -e "${YELLOW}→${NC} Pulling latest image..."
        docker compose pull
        echo -e "${YELLOW}→${NC} Restarting with new image..."
        docker compose up -d
        echo -e "${GREEN}✓${NC} Server updated and restarted"
        docker compose ps
        ;;
    config)
        echo -e "${BLUE}Opening .env configuration...${NC}"
        ${EDITOR:-nano} .env
        echo
        read -p "Restart server to apply changes? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker compose restart
            echo -e "${GREEN}✓${NC} Server restarted with new configuration"
        fi
        ;;
    clean)
        echo -e "${YELLOW}⚠${NC}  This will stop and remove containers (OAuth tokens will be preserved)"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker compose down
            echo -e "${GREEN}✓${NC} Containers removed"
        fi
        ;;
    clean-all)
        echo -e "${RED}⚠ WARNING${NC}  This will remove EVERYTHING including OAuth tokens!"
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker compose down -v
            echo -e "${GREEN}✓${NC} All containers and volumes removed"
        fi
        ;;
    *)
        show_help
        exit 1
        ;;
esac
