#!/bin/bash

# Pipe Network Testnet Node - Perfect One-Click Installer
# This script automates the complete installation process of a Pipe Network Testnet Node

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Text formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Banner
echo -e "${BLUE}${BOLD}"
echo "╔═════════════════════════════════════════════════════════════════════╗"
echo "║                                                                     ║"
echo "║          PIPE NETWORK TESTNET NODE - ONE-CLICK INSTALLER            ║"
echo "║                                                                     ║"
echo "╚═════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Set installation directory
INSTALL_DIR="/opt/popcache"

# ===== 1. Prerequisites and Dependencies =====

echo -e "${BLUE}${BOLD}Installing required dependencies...${NC}"
apt-get update
apt-get install -y curl wget jq net-tools apt-transport-https ca-certificates gnupg lsb-release

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
    echo -e "${GREEN}Docker installed successfully.${NC}"
else
    echo -e "${GREEN}Docker is already installed.${NC}"
fi

# Ensure Docker is running
if ! systemctl is-active --quiet docker; then
    echo -e "${YELLOW}Starting Docker service...${NC}"
    systemctl start docker
fi

# ===== 2. Detect System Resources =====

echo -e "${BLUE}${BOLD}Detecting system resources...${NC}"

# Get total memory in MB
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))

# Get available disk space in GB
DISK_SPACE_KB=$(df -k "$INSTALL_DIR" 2>/dev/null | tail -1 | awk '{print $4}')
if [ -z "$DISK_SPACE_KB" ]; then
    DISK_SPACE_KB=$(df -k / | tail -1 | awk '{print $4}')
fi
DISK_SPACE_GB=$((DISK_SPACE_KB / 1024 / 1024))

# Get CPU cores
CPU_CORES=$(grep -c processor /proc/cpuinfo)

# Calculate recommended values (70%)
RECOMMENDED_MEM_MB=$((TOTAL_MEM_MB * 70 / 100))
RECOMMENDED_DISK_GB=$((DISK_SPACE_GB * 70 / 100))
RECOMMENDED_WORKERS=$((CPU_CORES > 1 ? CPU_CORES - 1 : 1))

echo -e "  Total Memory: ${GREEN}${TOTAL_MEM_MB} MB${NC}"
echo -e "  Available Disk Space: ${GREEN}${DISK_SPACE_GB} GB${NC}"
echo -e "  CPU Cores: ${GREEN}${CPU_CORES}${NC}"
echo -e "  Recommended Memory Cache: ${GREEN}${RECOMMENDED_MEM_MB} MB${NC}"
echo -e "  Recommended Disk Cache: ${GREEN}${RECOMMENDED_DISK_GB} GB${NC}"
echo -e "  Recommended Workers: ${GREEN}${RECOMMENDED_WORKERS}${NC}"

# ===== 3. Setup Installation Directory =====

echo -e "${BLUE}${BOLD}Setting up installation directory...${NC}"
mkdir -p $INSTALL_DIR
mkdir -p $INSTALL_DIR/logs
mkdir -p $INSTALL_DIR/cache
chmod -R 755 $INSTALL_DIR

# ===== 4. Check for Available Ports =====

echo -e "${BLUE}${BOLD}Checking port availability...${NC}"

# Function to check if a port is in use
check_port() {
    netstat -tuln | grep -q ":$1 "
    return $?
}

# Find available HTTP port
if check_port 80; then
    HTTP_PORT=8080
    while check_port $HTTP_PORT; do
        HTTP_PORT=$((HTTP_PORT + 1))
    done
    echo -e "${YELLOW}Port 80 is in use. Using port ${HTTP_PORT} instead.${NC}"
else
    HTTP_PORT=80
    echo -e "${GREEN}Using default HTTP port 80.${NC}"
fi

# Find available HTTPS port
if check_port 443; then
    HTTPS_PORT=8443
    while check_port $HTTPS_PORT; do
        HTTPS_PORT=$((HTTPS_PORT + 1))
    done
    echo -e "${YELLOW}Port 443 is in use. Using port ${HTTPS_PORT} instead.${NC}"
else
    HTTPS_PORT=443
    echo -e "${GREEN}Using default HTTPS port 443.${NC}"
fi

# ===== 5. Collect User Input =====

echo -e "${BLUE}${BOLD}Please provide the following information:${NC}"

read -p "Enter your POP name: " POP_NAME
read -p "Enter your POP location (e.g., Seoul, South Korea): " POP_LOCATION
read -p "Enter your invite code: " INVITE_CODE
read -p "Enter your name: " USER_NAME
read -p "Enter your email: " USER_EMAIL
read -p "Enter your website (or press Enter to skip): " USER_WEBSITE
read -p "Enter your Twitter handle (or press Enter to skip): " USER_TWITTER
read -p "Enter your Discord username (or press Enter to skip): " USER_DISCORD
read -p "Enter your Telegram handle (or press Enter to skip): " USER_TELEGRAM
read -p "Enter your Solana wallet address for rewards: " SOLANA_PUBKEY

# For resource allocation, use recommended values by default
read -p "Enter memory cache size in MB (press Enter for recommended ${RECOMMENDED_MEM_MB} MB): " MEMORY_CACHE_SIZE
read -p "Enter disk cache size in GB (press Enter for recommended ${RECOMMENDED_DISK_GB} GB): " DISK_CACHE_SIZE
read -p "Enter number of workers (press Enter for recommended ${RECOMMENDED_WORKERS}): " WORKERS

# Use default values if empty
MEMORY_CACHE_SIZE=${MEMORY_CACHE_SIZE:-$RECOMMENDED_MEM_MB}
DISK_CACHE_SIZE=${DISK_CACHE_SIZE:-$RECOMMENDED_DISK_GB}
WORKERS=${WORKERS:-$RECOMMENDED_WORKERS}
USER_WEBSITE=${USER_WEBSITE:-""}
USER_TWITTER=${USER_TWITTER:-""}
USER_DISCORD=${USER_DISCORD:-""}
USER_TELEGRAM=${USER_TELEGRAM:-""}

# ===== 6. Create Configuration File =====

echo -e "${BLUE}${BOLD}Creating configuration file...${NC}"
cat > $INSTALL_DIR/config.json << EOL
{
  "pop_name": "$POP_NAME",
  "pop_location": "$POP_LOCATION",
  "invite_code": "$INVITE_CODE",
  "server": {
    "host": "0.0.0.0",
    "port": $HTTPS_PORT,
    "http_port": $HTTP_PORT,
    "workers": $WORKERS
  },
  "cache_config": {
    "memory_cache_size_mb": $MEMORY_CACHE_SIZE,
    "disk_cache_path": "./cache",
    "disk_cache_size_gb": $DISK_CACHE_SIZE,
    "default_ttl_seconds": 86400,
    "respect_origin_headers": true,
    "max_cacheable_size_mb": 1024
  },
  "api_endpoints": {
    "base_url": "https://dataplane.pipenetwork.com"
  },
  "identity_config": {
    "node_name": "$POP_NAME",
    "name": "$USER_NAME",
    "email": "$USER_EMAIL",
    "website": "$USER_WEBSITE",
    "twitter": "$USER_TWITTER",
    "discord": "$USER_DISCORD",
    "telegram": "$USER_TELEGRAM",
    "solana_pubkey": "$SOLANA_PUBKEY"
  }
}
EOL

# Validate the configuration file
if ! jq -e . $INSTALL_DIR/config.json > /dev/null 2>&1; then
    echo -e "${RED}Error: Generated configuration file is not valid JSON. Please check your inputs.${NC}"
    exit 1
fi

echo -e "${GREEN}Configuration file created at $INSTALL_DIR/config.json${NC}"

# ===== 7. Create Management Script =====

echo -e "${BLUE}${BOLD}Creating management script...${NC}"
cat > /usr/local/bin/popcache-manager << 'EOL'
#!/bin/bash

CONTAINER_NAME="popcache-node"
INSTALL_DIR="/opt/popcache"

# Colors for output
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

case "$1" in
    start)
        echo -e "${YELLOW}Starting POP Cache Node...${NC}"
        
        # Check if container already exists
        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo "Found existing container. Removing it first..."
            docker stop ${CONTAINER_NAME} 2>/dev/null || true
            docker rm ${CONTAINER_NAME} 2>/dev/null || true
        fi
        
        # Get port configurations from config.json
        HTTP_PORT=$(jq -r '.server.http_port' $INSTALL_DIR/config.json)
        HTTPS_PORT=$(jq -r '.server.port' $INSTALL_DIR/config.json)
        
        # Start container
        docker run -d \
          --name ${CONTAINER_NAME} \
          --restart unless-stopped \
          -p ${HTTP_PORT}:${HTTP_PORT} \
          -p ${HTTPS_PORT}:${HTTPS_PORT} \
          -v ${INSTALL_DIR}:/app \
          -v ${INSTALL_DIR}/cache:/app/cache \
          -v ${INSTALL_DIR}/logs:/app/logs \
          -e POP_CONFIG_PATH=/app/config.json \
          --workdir /app \
          ubuntu:latest \
          bash -c "apt-get update && apt-get install -y libssl-dev ca-certificates curl wget && wget -O /app/pop https://github.com/kooroot/Node_Executor-Pipenetwork/raw/main/pop && chmod +x /app/pop && export POP_CONFIG_PATH=/app/config.json && ./pop"
        
        # Check if container started successfully
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo -e "${GREEN}Container started successfully.${NC}"
            echo "Use 'popcache-manager logs' to view logs."
        else
            echo -e "${RED}Failed to start container. See logs for details.${NC}"
            docker logs ${CONTAINER_NAME} 2>&1 | head -n 20
        fi
        ;;
    stop)
        echo -e "${YELLOW}Stopping POP Cache Node...${NC}"
        docker stop ${CONTAINER_NAME} && docker rm ${CONTAINER_NAME}
        echo -e "${GREEN}Container stopped and removed.${NC}"
        ;;
    restart)
        echo -e "${YELLOW}Restarting POP Cache Node...${NC}"
        $0 stop
        sleep 2
        $0 start
        ;;
    logs)
        echo -e "${YELLOW}Showing logs from POP Cache Node...${NC}"
        echo "Press Ctrl+C to exit logs view."
        docker logs -f ${CONTAINER_NAME}
        ;;
    status)
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo -e "${GREEN}POP Cache Node is running.${NC}"
            docker ps -f name=${CONTAINER_NAME}
            
            # Show resource usage
            echo -e "\n${YELLOW}Resource Usage:${NC}"
            docker stats --no-stream ${CONTAINER_NAME}
        else
            echo -e "${RED}POP Cache Node is not running.${NC}"
            
            # Check if container exists but stopped
            if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                echo -e "${YELLOW}Container exists but is not running.${NC}"
                docker ps -a -f name=${CONTAINER_NAME}
            fi
        fi
        ;;
    shell)
        echo -e "${YELLOW}Connecting to shell in container...${NC}"
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            docker exec -it ${CONTAINER_NAME} bash
        else
            echo -e "${RED}Container is not running. Start it first with 'popcache-manager start'${NC}"
        fi
        ;;
    update)
        echo -e "${YELLOW}Updating POP Cache Node...${NC}"
        
        # Stop container if running
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo "Stopping container..."
            docker stop ${CONTAINER_NAME} && docker rm ${CONTAINER_NAME}
        fi
        
        # Update pop binary
        echo "Updating pop binary..."
        wget -O ${INSTALL_DIR}/pop https://github.com/kooroot/Node_Executor-Pipenetwork/raw/main/pop
        chmod +x ${INSTALL_DIR}/pop
        
        # Pull latest Ubuntu image
        echo "Updating Ubuntu image..."
        docker pull ubuntu:latest
        
        # Restart container
        echo "Restarting container..."
        $0 start
        ;;
    info)
        echo -e "${YELLOW}POP Cache Node Information:${NC}"
        echo "----------------------------------------"
        echo -e "Installation Directory: ${GREEN}${INSTALL_DIR}${NC}"
        
        if [ -f "${INSTALL_DIR}/config.json" ]; then
            echo -e "\n${YELLOW}Configuration Summary:${NC}"
            jq -r '. | "POP Name: \(.pop_name)\nLocation: \(.pop_location)\nHTTP Port: \(.server.http_port)\nHTTPS Port: \(.server.port)\nWorkers: \(.server.workers)\nMemory Cache: \(.cache_config.memory_cache_size_mb) MB\nDisk Cache: \(.cache_config.disk_cache_size_gb) GB"' ${INSTALL_DIR}/config.json
            
            # Container status
            if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                echo -e "\n${GREEN}Status: Running${NC}"
                # Get uptime
                CREATED=$(docker inspect -f '{{.Created}}' ${CONTAINER_NAME})
                echo "Running since: $CREATED"
            else
                echo -e "\n${RED}Status: Not Running${NC}"
            fi
        else
            echo -e "${RED}Configuration file not found.${NC}"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|shell|update|info}"
        exit 1
        ;;
esac

exit 0
EOL

chmod +x /usr/local/bin/popcache-manager

echo -e "${GREEN}Management script created at /usr/local/bin/popcache-manager${NC}"

# ===== 8. Download the pop binary =====

echo -e "${BLUE}${BOLD}Downloading pop binary...${NC}"
wget -O $INSTALL_DIR/pop https://github.com/kooroot/Node_Executor-Pipenetwork/raw/main/pop
chmod +x $INSTALL_DIR/pop
echo -e "${GREEN}Binary downloaded successfully.${NC}"

# ===== 9. Clean up any existing Docker containers with the same name =====

echo -e "${BLUE}${BOLD}Cleaning up existing containers...${NC}"
if docker ps -a --format '{{.Names}}' | grep -q "^popcache-node$"; then
    echo -e "${YELLOW}Found existing container. Removing it...${NC}"
    docker stop popcache-node 2>/dev/null || true
    docker rm popcache-node 2>/dev/null || true
    echo -e "${GREEN}Existing container removed.${NC}"
else
    echo -e "${GREEN}No existing containers found.${NC}"
fi

# ===== 10. Start the Pipe Network Node =====

echo -e "${BLUE}${BOLD}Starting Pipe Network Node...${NC}"
popcache-manager start

# Wait for a moment to let the container initialize
echo -e "${YELLOW}Waiting for container to initialize...${NC}"
sleep 10

# ===== 11. Verify container is running =====

if docker ps --format '{{.Names}}' | grep -q "^popcache-node$"; then
    echo -e "\n${GREEN}${BOLD}✓ Pipe Network Node successfully started!${NC}"
    echo -e "HTTP Port: ${YELLOW}${HTTP_PORT}${NC}"
    echo -e "HTTPS Port: ${YELLOW}${HTTPS_PORT}${NC}"
    echo -e "Memory Allocation: ${YELLOW}${MEMORY_CACHE_SIZE} MB${NC}"
    echo -e "Disk Allocation: ${YELLOW}${DISK_CACHE_SIZE} GB${NC}"
    echo -e "Workers: ${YELLOW}${WORKERS}${NC}"
    
    # Check logs for any immediate issues
    if docker logs popcache-node 2>&1 | grep -q "ERROR\|Error\|error"; then
        echo -e "\n${RED}${BOLD}Warning: Issues detected in node logs. Please check:${NC}"
        echo -e "${YELLOW}popcache-manager logs${NC}"
    else
        echo -e "\n${GREEN}No immediate issues detected in logs.${NC}"
    fi
else
    echo -e "\n${RED}${BOLD}✗ Failed to start Pipe Network Node.${NC}"
    echo -e "${YELLOW}Checking logs for errors:${NC}"
    docker logs popcache-node 2>&1 | grep -E "ERROR|Error|error|failed" || echo "No specific error found in logs."
    echo -e "\n${YELLOW}View complete logs with:${NC} popcache-manager logs"
fi

# ===== 12. Display management instructions =====

echo -e "\n${BLUE}${BOLD}======================================================${NC}"
echo -e "${GREEN}${BOLD}Installation Complete!${NC}"
echo -e "${BLUE}${BOLD}======================================================${NC}"
echo -e "\n${YELLOW}Management Commands:${NC}"
echo -e "  ${BOLD}popcache-manager start${NC}      - Start the node"
echo -e "  ${BOLD}popcache-manager stop${NC}       - Stop the node"
echo -e "  ${BOLD}popcache-manager restart${NC}    - Restart the node"
echo -e "  ${BOLD}popcache-manager logs${NC}       - View node logs"
echo -e "  ${BOLD}popcache-manager status${NC}     - Check node status and resource usage"
echo -e "  ${BOLD}popcache-manager info${NC}       - Display configuration summary"
echo -e "  ${BOLD}popcache-manager shell${NC}      - Connect to container shell"
echo -e "  ${BOLD}popcache-manager update${NC}     - Update the node"

echo -e "\n${YELLOW}Configuration File:${NC} $INSTALL_DIR/config.json"
echo -e "${YELLOW}Installation Directory:${NC} $INSTALL_DIR"

if [ $HTTP_PORT -ne 80 ] || [ $HTTPS_PORT -ne 443 ]; then
    echo -e "\n${YELLOW}${BOLD}Note: Using non-standard ports!${NC}"
    echo -e "Make sure ports ${HTTP_PORT} and ${HTTPS_PORT} are open in your firewall/security groups."
else
    echo -e "\n${YELLOW}${BOLD}Firewall Information:${NC}"
    echo -e "Make sure ports 80 and 443 are open in your firewall/security groups."
fi

echo -e "\n${GREEN}Thank you for installing Pipe Network Testnet Node!${NC}"

exit 0
