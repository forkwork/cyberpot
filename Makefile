.PHONY: build test deploy clean update backup help install uninstall start stop restart status

# Default target
help:
	@echo "CyberPot Makefile"
	@echo "----------------"
	@echo "Available targets:"
	@echo "  build     - Build CyberPot docker images locally"
	@echo "  test      - Run tests on the CyberPot setup"
	@echo "  deploy    - Deploy CyberPot with current configuration"
	@echo "  clean     - Remove all containers and volumes"
	@echo "  update    - Update CyberPot to the latest version"
	@echo "  backup    - Create a backup of CyberPot configuration"
	@echo "  install   - Run the CyberPot installer"
	@echo "  uninstall - Run the CyberPot uninstaller"
	@echo "  start     - Start CyberPot services"
	@echo "  stop      - Stop CyberPot services"
	@echo "  restart   - Restart CyberPot services"
	@echo "  status    - Check status of CyberPot services"
	@echo "  customize - Run the CyberPot customizer"
	@echo "  build-images - Build all Docker images using builder.sh"

# Build CyberPot docker images locally
build:
	@echo "Building CyberPot docker images..."
	docker-compose build

# Run tests on the CyberPot setup
test:
	@echo "Testing CyberPot setup..."
	@echo "Checking if required ports are available..."
	@if command -v netstat > /dev/null; then \
		netstat -tulpn | grep -E '64294|64295|64297' || echo "No conflicts found with required ports"; \
	elif command -v ss > /dev/null; then \
		ss -tulpn | grep -E '64294|64295|64297' || echo "No conflicts found with required ports"; \
	else \
		echo "Warning: Neither netstat nor ss commands are available. Install net-tools or iproute2 package to check ports."; \
	fi
	@echo "Checking Docker service..."
	@if command -v docker > /dev/null; then \
		docker info > /dev/null 2>&1 && echo "Docker is running" || echo "Docker is not running"; \
	else \
		echo "Warning: Docker is not installed or not in PATH"; \
	fi
	@echo "Checking Docker Compose..."
	@if command -v docker-compose > /dev/null; then \
		echo "Docker Compose is installed"; \
	else \
		echo "Warning: Docker Compose is not installed or not in PATH"; \
	fi

# Deploy CyberPot with current configuration
deploy:
	@echo "Deploying CyberPot..."
	@echo "Stopping any running containers first..."
	-docker-compose down || true
	@echo "Starting CyberPot services..."
	@echo "This may take some time as images are pulled..."
	@if [ -f .env ]; then \
		echo "Using configuration from .env file"; \
	else \
		echo "Warning: No .env file found. Using default configuration."; \
	fi
	@docker-compose pull --quiet || echo "Warning: Some images failed to pull. Will try to continue with local images."
	docker-compose up -d

# Remove all containers and volumes
clean:
	@echo "Cleaning up CyberPot containers and volumes..."
	-docker-compose down -v || true
	@echo "Removing unused Docker resources..."
	-docker system prune -f || true

# Update CyberPot to the latest version
update:
	@echo "Updating CyberPot..."
	@if [ -f ./update.sh ]; then \
		echo "Running update script..."; \
		bash ./update.sh || echo "Update script failed. Please check for errors."; \
	else \
		echo "Update script not found. Pulling latest changes from git..."; \
		git pull || echo "Failed to pull latest changes. Please update manually."; \
	fi

# Create a backup of CyberPot configuration
backup:
	@echo "Creating backup of CyberPot configuration..."
	@mkdir -p backups
	@tar -czf backups/cyberpot-backup-$(shell date +%Y%m%d-%H%M%S).tar.gz docker-compose.yml .env data/ || echo "Backup failed. Please check permissions and disk space."
	@echo "Backup created in backups/ directory"

# Run the CyberPot installer
install:
	@echo "Running CyberPot installer..."
	@if [ -f ./install.sh ]; then \
		bash ./install.sh || echo "Installation failed. Please check for errors."; \
	else \
		echo "Error: install.sh script not found"; \
		exit 1; \
	fi

# Run the CyberPot uninstaller
uninstall:
	@echo "Running CyberPot uninstaller..."
	@if [ -f ./uninstall.sh ]; then \
		bash ./uninstall.sh || echo "Uninstallation failed. Please check for errors."; \
	else \
		echo "Error: uninstall.sh script not found"; \
		exit 1; \
	fi

# Start CyberPot services
start:
	@echo "Starting CyberPot services..."
	@if command -v systemctl > /dev/null && systemctl list-unit-files | grep -q cyberpot; then \
		systemctl start cyberpot || echo "Failed to start CyberPot service via systemctl"; \
	else \
		echo "Using docker-compose to start services..."; \
		docker-compose up -d; \
	fi

# Stop CyberPot services
stop:
	@echo "Stopping CyberPot services..."
	@if command -v systemctl > /dev/null && systemctl list-unit-files | grep -q cyberpot; then \
		systemctl stop cyberpot || echo "Failed to stop CyberPot service via systemctl"; \
	else \
		echo "Using docker-compose to stop services..."; \
		docker-compose down || true; \
	fi

# Restart CyberPot services
restart: stop start

# Check status of CyberPot services
status:
	@echo "Checking CyberPot services status..."
	@if command -v systemctl > /dev/null && systemctl list-unit-files | grep -q cyberpot; then \
		systemctl status cyberpot --no-pager || echo "CyberPot service not found or not running"; \
	else \
		echo "CyberPot service not managed by systemd."; \
	fi
	@echo "\nDocker containers status:"
	docker ps -a | grep -E 'cyberpot|CONTAINER'

# Run the CyberPot customizer
customize:
	@echo "Running CyberPot customizer..."
	@if [ -d ./compose ] && [ -f ./compose/customizer.py ]; then \
		cd compose && python3 customizer.py; \
	else \
		echo "Error: customizer.py not found in compose directory"; \
		exit 1; \
	fi

# Build all Docker images using builder.sh
build-images:
	@echo "Building all Docker images using builder.sh..."
	@echo "Checking Docker buildx prerequisites..."
	@if ! command -v docker > /dev/null; then \
		echo "Error: Docker is not installed or not in PATH"; \
		exit 1; \
	fi
	@if ! docker buildx version > /dev/null 2>&1; then \
		echo "Error: Docker buildx plugin is not available"; \
		echo "Please install Docker buildx: https://docs.docker.com/buildx/working-with-buildx/"; \
		exit 1; \
	fi
	@echo "Setting up QEMU for cross-platform builds..."
	@if ! docker run --rm --privileged multiarch/qemu-user-static --reset -p yes > /dev/null 2>&1; then \
		echo "Warning: Failed to set up QEMU. ARM64 builds may not work."; \
	fi
	@if [ -f ./docker/_builder/builder.sh ]; then \
		echo "Do you want to push images after building? (y/n)"; \
		read answer; \
		if [ "$answer" = "y" ]; then \
			(cd docker/_builder && sudo bash ./builder.sh -p); \
		else \
			(cd docker/_builder && sudo bash ./builder.sh); \
		fi; \
	else \
		echo "Error: builder.sh script not found"; \
		exit 1; \
	fi