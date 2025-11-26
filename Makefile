NAME = inception
LOGIN ?= $(shell whoami)

# Set USE_VM=1 to run Docker commands in VM via SSH, or USE_VM=0 for local execution
# Default is VM mode (USE_VM=1)
#
# Examples:
#   make up                    # Run in VM (default)
#   USE_VM=0 make up          # Run locally on host
#   USE_VM=1 make up          # Run in VM via SSH
USE_VM ?= 1
USE_NETINST ?= 0

# Path Configuration
GOINFRE_BASE ?= /goinfre/niida
ISO_DIR ?= $(GOINFRE_BASE)/iso
VM_DIR ?= $(GOINFRE_BASE)/vm
SHARE_DIR ?= $(GOINFRE_BASE)/42share
DATA_DIR ?= ./data
NGINX_SSL_DIR ?= $(DATA_DIR)/nginx_ssl
WORDPRESS_DB_DIR ?= $(DATA_DIR)/wordpress_db
WORDPRESS_FILES_DIR ?= $(DATA_DIR)/wordpress_files

# Debian Configuration
DEBIAN_VERSION ?= 13.1.0
DEBIAN_ARCH ?= amd64
DEBIAN_ISO_TYPE ?= netinst
DEBIAN_ISO_NAME = debian-$(DEBIAN_VERSION)-$(DEBIAN_ARCH)-$(DEBIAN_ISO_TYPE).iso
DEBIAN_ISO_URL = https://cdimage.debian.org/debian-cd/current/$(DEBIAN_ARCH)/iso-cd/$(DEBIAN_ISO_NAME)

# Debian Full ISO Configuration
DEBIAN_FULL_ISO_NAME = debian-$(DEBIAN_VERSION)-$(DEBIAN_ARCH)-DVD-1.iso
DEBIAN_FULL_ISO_PATH = $(ISO_DIR)/$(DEBIAN_FULL_ISO_NAME)
DEBIAN_FULL_ISO_URL = https://cdimage.debian.org/debian-cd/current/$(DEBIAN_ARCH)/iso-dvd/$(DEBIAN_FULL_ISO_NAME)

ifeq ($(USE_NETINST),1)
	DEBIAN_ISO_PATH = $(ISO_DIR)/$(DEBIAN_ISO_NAME)
else
	DEBIAN_ISO_PATH = $(DEBIAN_FULL_ISO_PATH)
endif

# VirtualBox Configuration
VM_NAME ?= Inception
VM_OSTYPE ?= Debian_64
VM_MEMORY ?= 2048
VM_VRAM ?= 128
VM_CPUS ?= 2
VM_DISK_SIZE ?= 20480
VM_DISK_PATH = $(VM_DIR)/$(VM_NAME)/$(VM_NAME).vdi
VBOX_GUEST_ADDITIONS_ISO = $(ISO_DIR)/VBoxGuestAdditions.iso

# Port Forwarding Configuration
SSH_PORT ?= 2222
HTTP_PORT ?= 8080
HTTPS_PORT ?= 8443

# Network Configuration
PRESEED_SERVER_PORT ?= 8000
PRESEED_SERVER_LOG ?= /tmp/preseed-server.log
PRESEED_SERVER_PID ?= /tmp/preseed-server.pid
# Auto-detect host IP from default route interface (e.g., 10.11.7.2 from enp4s0f0)
# Override with: PRESEED_SERVER_IP=x.x.x.x make vm-boot
IFACE := $(shell route get 1.1.1.1 | awk '/interface: / {print $$2}')
PRESEED_SERVER_IP := $(shell ifconfig $(IFACE) | grep "inet " | grep -v inet6 | awk '{print $$2}' | head -1)

ifeq ($(USE_VM),1)
    DOCKER_CMD = ssh -p $(SSH_PORT) $(LOGIN)@localhost
    # In VM mode, volumes are at /home/<login>/data to match project requirements
    COMPOSE = $(DOCKER_CMD) "cd /home/$(LOGIN)/inception && LOGIN=$(LOGIN) VOLUME_BASE=/home/$(LOGIN) COMPOSE_BAKE=true docker compose -f srcs/docker-compose.yml"
    COMPOSE_EXEC = $(DOCKER_CMD) "cd /home/$(LOGIN)/inception && docker compose -f srcs/docker-compose.yml exec"
    DOCKER_EXEC = $(DOCKER_CMD) "cd /home/$(LOGIN)/inception && docker exec"
    DOCKER_SYSTEM = $(DOCKER_CMD) "docker system"
else
    # In local mode, volumes are at /home/<login>/data
    COMPOSE = LOGIN=$(LOGIN) VOLUME_BASE=/home/$(LOGIN) COMPOSE_BAKE=true docker compose -f srcs/docker-compose.yml
    COMPOSE_EXEC = docker compose -f srcs/docker-compose.yml exec
    DOCKER_EXEC = docker exec
    DOCKER_SYSTEM = docker system
endif

all: up

help:
	@echo "Inception Docker Project"
	@echo ""
	@echo "Environment Variables:"
	@echo "  USE_VM=1    Run Docker commands in VM via SSH (default)"
	@echo "              - Starts VM automatically with 'make up'"
	@echo "              - Uses SSH to execute Docker commands in VM"
	@echo "  USE_VM=0    Run Docker commands locally on host"
	@echo "              - No VM operations (VirtualBox not used)"
	@echo "              - Direct Docker execution on host system"
	@echo "  LOGIN       Your login name (default: current user)"
	@echo ""
	@echo "Main targets:"
	@echo "  up          Start all services"
	@echo "  down        Stop all services"
	@echo "  build       Build all images"
	@echo "  clean       Clean up containers and images"
	@echo "  logs        Show container logs"
	@echo ""
	@echo "Testing targets:"
	@echo "  test-nginx-internal      Test nginx from inside container"
	@echo "  test-nginx-host          Test nginx from host system"
	@echo ""
	@echo "VM management:"
	@echo "  vm-start           Start VM (headless)"
	@echo "  vm-start-gui       Start VM (with GUI)"
	@echo "  vm-stop            Stop VM"
	@echo "  vm-status          Show VM status"
	@echo "  vm-install-docker  Install Docker in VM after preseed installation"
	@echo "  vm-test-docker     Test Docker installation in VM"
	@echo "  ssh-key-check      Check for SSH key (required for VM access)"
	@echo ""
	@echo "Examples:"
	@echo "  make up                   # Start in VM (default)"
	@echo "  USE_VM=0 make up         # Start locally (no VM operations)"
	@echo "  USE_VM=0 make logs       # View logs locally"
	@echo "  USE_VM=1 make up         # Explicitly start in VM"

ifeq ($(USE_VM),1)
up: vm-start-gui vm-sync-project vm-data-setup ssl-setup
	$(COMPOSE) up -d
else
up: ssl-setup
	$(COMPOSE) up -d
endif

ssl-setup:
ifeq ($(USE_VM),1)
	@echo "Setting up SSL certificates for VM host system access..."
	@mkdir -p $(NGINX_SSL_DIR)
	@echo "SSL certificates will be available in $(NGINX_SSL_DIR)/ after container start"
else
	@echo "Setting up SSL certificates for local host system access..."
	@mkdir -p $(NGINX_SSL_DIR)
	@echo "SSL certificates will be available in $(NGINX_SSL_DIR)/ after container start"
	@echo "Note: Running in local mode - containers will bind directly to host ports"
endif

browser-setup:
	@echo ""
ifeq ($(USE_VM),1)
	@echo "=== Browser Configuration for $(LOGIN).42.fr (VM Mode) ==="
	@echo "Note: VM forwards ports 443->8443, 80->8080 to host"
else
	@echo "=== Browser Configuration for $(LOGIN).42.fr (Local Mode) ==="
	@echo "Note: Containers bind directly to host ports 443 and 80"
endif
	@echo ""
	@echo "Option 1: Browser Extensions"
	@echo "  Chrome: Install 'Host Admin App' extension"
	@echo "  Firefox: Install 'Virtual Hosts' extension"
	@echo "  Add mapping: 127.0.0.1 -> $(LOGIN).42.fr"
	@echo ""
	@echo "Option 2: Import SSL Certificate (recommended)"
	@echo "  1. After 'make up', certificate will be at: $(NGINX_SSL_DIR)/cert.pem"
	@echo "  2. Chrome: Settings -> Privacy & Security -> Security -> Manage Certificates -> Authorities -> Import"
	@echo "  3. Firefox: Settings -> Privacy & Security -> Certificates -> View Certificates -> Authorities -> Import"
	@echo "  4. Import $(NGINX_SSL_DIR)/cert.pem"
	@echo ""
	@echo "Option 3: Firefox about:config (Advanced)"
	@echo "  1. Type about:config in address bar"
	@echo "  2. Search for 'network.dns.localDomains'"
	@echo "  3. Add '$(LOGIN).42.fr' to redirect to localhost"
	@echo ""
	@echo "Testing: Use 'make test-nginx-host-header' to test without /etc/hosts"
	@echo "Access: https://$(LOGIN).42.fr (after browser configuration)"
	@echo ""

vm-download:
	@echo "Downloading Debian ISO..."
	@mkdir -p $(ISO_DIR)
	curl -L -o $(DEBIAN_ISO_PATH) "$(DEBIAN_ISO_URL)"

vm-download-full:
	@echo "Downloading full Debian ISO (offline installation)..."
	@mkdir -p $(ISO_DIR)
	curl -L -o $(DEBIAN_FULL_ISO_PATH) "$(DEBIAN_FULL_ISO_URL)"

vm-guest-additions-download:
	@echo "Downloading VirtualBox Guest Additions ISO..."
	@mkdir -p $(ISO_DIR)
	@VBOX_VERSION=$$(VBoxManage --version | cut -d 'r' -f1) && \
	curl -L -o $(VBOX_GUEST_ADDITIONS_ISO) "https://download.virtualbox.org/virtualbox/$$VBOX_VERSION/VBoxGuestAdditions_$$VBOX_VERSION.iso"

ssh-key-check:
	@echo "Checking for SSH public key..."
	@SSH_PUB_KEY_FILE=""; \
	for key_type in id_ed25519 id_rsa id_ecdsa id_dsa; do \
		if [ -f "$(HOME)/.ssh/$$key_type.pub" ]; then \
			SSH_PUB_KEY_FILE="$(HOME)/.ssh/$$key_type.pub"; \
			echo "✓ Found SSH public key: $$SSH_PUB_KEY_FILE"; \
			echo ""; \
			echo "Key content:"; \
			cat "$$SSH_PUB_KEY_FILE"; \
			echo ""; \
			echo "This key will be injected into the VM's authorized_keys"; \
			exit 0; \
		fi; \
	done; \
	echo "✗ No SSH public key found in $(HOME)/.ssh/"; \
	echo ""; \
	echo "Searched for: id_ed25519.pub, id_rsa.pub, id_ecdsa.pub, id_dsa.pub"; \
	echo ""; \
	echo "To generate a new SSH key, run:"; \
	echo "  ssh-keygen -t ed25519"; \
	echo ""; \
	exit 1

vm-init:
	@echo "Creating VM..."
	@mkdir -p $(VM_DIR)
	VBoxManage createvm --name "$(VM_NAME)" --ostype "$(VM_OSTYPE)" --register --basefolder "$(VM_DIR)"
	VBoxManage modifyvm "$(VM_NAME)" --memory $(VM_MEMORY) --vram $(VM_VRAM)
	VBoxManage modifyvm "$(VM_NAME)" --cpus $(VM_CPUS)

vm-storage:
	@echo "Setting up storage..."
	VBoxManage createhd --filename "$(VM_DISK_PATH)" --size $(VM_DISK_SIZE) --format VDI
	VBoxManage storagectl "$(VM_NAME)" --name "SATA Controller" --add sata --controller IntelAHCI
	VBoxManage storageattach "$(VM_NAME)" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$(VM_DISK_PATH)"
	VBoxManage storagectl "$(VM_NAME)" --name "IDE Controller" --add ide --controller PIIX4
	VBoxManage storageattach "$(VM_NAME)" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$(DEBIAN_ISO_PATH)"

vm-preseed-cp:
	@echo "Copying preseed file to shared folder..."
	@mkdir -p $(SHARE_DIR)
	@# Find default SSH public key (try ed25519, rsa, ecdsa, dsa in order)
	@SSH_PUB_KEY=""; \
	for key_type in id_ed25519 id_rsa id_ecdsa id_dsa; do \
		if [ -f "$(HOME)/.ssh/$$key_type.pub" ]; then \
			SSH_PUB_KEY=$$(cat $(HOME)/.ssh/$$key_type.pub); \
			echo "Found SSH public key: $(HOME)/.ssh/$$key_type.pub"; \
			break; \
		fi; \
	done; \
	if [ -z "$$SSH_PUB_KEY" ]; then \
		echo "ERROR: No SSH public key found in $(HOME)/.ssh/"; \
		echo "Please generate one with: ssh-keygen -t ed25519"; \
		exit 1; \
	fi; \
	sed -e 's/passwd\/username string user/passwd\/username string $(LOGIN)/g' \
	    -e 's/passwd\/user-fullname string User/passwd\/user-fullname string $(LOGIN)/g' \
	    -e 's/passwd\/user-password password user/passwd\/user-password password $(LOGIN)/g' \
	    -e 's/passwd\/user-password-again password user/passwd\/user-password-again password $(LOGIN)/g' \
	    -e 's/usermod -aG docker user/usermod -aG docker $(LOGIN)/g' \
	    -e 's/\/home\/user/\/home\/$(LOGIN)/g' \
	    -e 's/chown -R user:user/chown -R $(LOGIN):$(LOGIN)/g' \
	    -e "s|SSH_PUBLIC_KEY_PLACEHOLDER|$$SSH_PUB_KEY|g" \
	    preseed.cfg > $(SHARE_DIR)/preseed.cfg
	@echo "SSH public key injected into preseed.cfg"
	
vm-config: vm-preseed-cp
	@echo "Configuring VM settings..."
	VBoxManage modifyvm "$(VM_NAME)" --boot1 dvd --boot2 disk --boot3 none --boot4 none
	VBoxManage modifyvm "$(VM_NAME)" --audio-driver none
	@mkdir -p "$(SHARE_DIR)"
	VBoxManage sharedfolder add "$(VM_NAME)" --name "42share" --hostpath "$(SHARE_DIR)/" --automount
	@echo "Attaching Guest Additions ISO..."
	VBoxManage storageattach "$(VM_NAME)" --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium "$(VBOX_GUEST_ADDITIONS_ISO)"

vm-boot:
	@echo "VM '$(VM_NAME)' created successfully!"
	@echo "Starting preseed server in background..."
	nohup make vm-serve-preseed > $(PRESEED_SERVER_LOG) 2>&1 & echo $$! > $(PRESEED_SERVER_PID)
	@sleep 2
	@echo "Starting VM for automated installation..."
	make vm-start-gui
	@echo ""
	@echo "At boot menu, press TAB and add: auto url=http://$(PRESEED_SERVER_IP):$(PRESEED_SERVER_PORT)/preseed.cfg"
	@echo "Default credentials: root/root, $(LOGIN)/$(LOGIN)"
	@echo "Stop preseed server with: make vm-stop-preseed"

vm-create: vm-init vm-storage vm-network-setup vm-guest-additions-download vm-config vm-boot

vm-stop-preseed:
	@if [ -f $(PRESEED_SERVER_PID) ]; then \
		kill `cat $(PRESEED_SERVER_PID)` 2>/dev/null || true; \
		rm -f $(PRESEED_SERVER_PID) $(PRESEED_SERVER_LOG); \
		echo "Preseed server stopped"; \
	else \
		echo "Preseed server not running"; \
	fi

vm-serve-preseed: vm-preseed-cp
	@echo "Serving preseed file on http://0.0.0.0:$(PRESEED_SERVER_PORT)/preseed.cfg"
	@echo "VM will access it via http://$(PRESEED_SERVER_IP):$(PRESEED_SERVER_PORT)/preseed.cfg"
	@echo "Stop with Ctrl+C after installation completes"
	cd $(SHARE_DIR) && python3 -m http.server $(PRESEED_SERVER_PORT)

vm-install-docker: vm-wait-ssh
	@echo "Installing Docker in VM..."
	@echo "Copying installation script to VM..."
	@scp -P $(SSH_PORT) -o StrictHostKeyChecking=no scripts/install-docker.sh $(LOGIN)@localhost:~
	@echo "Running Docker installation (this may take a few minutes)..."
	@ssh -p $(SSH_PORT) -o StrictHostKeyChecking=no $(LOGIN)@localhost "sudo bash ~/install-docker.sh"
	@echo "Docker installation complete!"
	@echo "Note: You may need to log out and back in for group changes to take effect"

vm-test-docker:
	@echo "Testing Docker installation in VM..."
	@echo "SSH to the VM and run:"
	@echo "ssh -p $(SSH_PORT) $(LOGIN)@localhost"
	ssh -p $(SSH_PORT) $(LOGIN)@localhost "docker --version"
	ssh -p $(SSH_PORT) $(LOGIN)@localhost "docker compose version"

vm-start:
	VBoxManage startvm "$(VM_NAME)" --type headless

vm-start-gui:
	VBoxManage startvm "$(VM_NAME)"

vm-stop:
	VBoxManage controlvm "$(VM_NAME)" poweroff

vm-pause:
	VBoxManage controlvm "$(VM_NAME)" pause

vm-resume:
	VBoxManage controlvm "$(VM_NAME)" resume

vm-status:
	VBoxManage showvminfo "$(VM_NAME)" --machinereadable | grep VMState

vm-network-setup:
	@echo "Setting up VirtualBox NAT networking with port forwarding..."
	VBoxManage modifyvm "$(VM_NAME)" --nic1 nat
	VBoxManage modifyvm "$(VM_NAME)" --natpf1 "ssh,tcp,,$(SSH_PORT),,22"
	VBoxManage modifyvm "$(VM_NAME)" --natpf1 "http,tcp,,$(HTTP_PORT),,80"
	VBoxManage modifyvm "$(VM_NAME)" --natpf1 "https,tcp,,$(HTTPS_PORT),,443"
	@echo "Network setup complete:"
	@echo "  - VM gets internet via NAT"
	@echo "  - SSH: localhost:$(SSH_PORT)"
	@echo "  - HTTP: localhost:$(HTTP_PORT)"
	@echo "  - HTTPS: localhost:$(HTTPS_PORT)"

vm-network-bridged:
	@echo "Configuring VM for bridged networking..."
	VBoxManage modifyvm "$(VM_NAME)" --nic1 bridged --bridgeadapter1 "en0"
	@echo "Bridged networking configured"

vm-network-info:
	@echo "VM network configuration:"
	VBoxManage showvminfo "$(VM_NAME)" | grep -E "(NIC|MAC|Cable|Line|Rule)"
	@echo "\nPort forwarding rules:"
	VBoxManage showvminfo "$(VM_NAME)" | grep "NIC 1 Rule"

vm-wait-ssh:
	@echo "Waiting for VM SSH to be ready..."
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		if ssh -p $(SSH_PORT) -o ConnectTimeout=5 -o StrictHostKeyChecking=no $(LOGIN)@localhost "echo SSH ready" 2>/dev/null; then \
			echo "SSH connection established"; \
			exit 0; \
		fi; \
		echo "Attempt $$i/10 failed, waiting 3 seconds..."; \
		sleep 3; \
	done; \
	echo "ERROR: Could not establish SSH connection after 10 attempts"; \
	exit 1

vm-sync-project: vm-wait-ssh
	@echo "Syncing project files to VM..."
	@ssh -p $(SSH_PORT) -o StrictHostKeyChecking=no $(LOGIN)@localhost "mkdir -p /home/$(LOGIN)"
	@rsync -avz --delete \
		--exclude='.git/' \
		--exclude='data/' \
		--exclude='*.vdi' \
		--exclude='*.iso' \
		--exclude='.DS_Store' \
		--exclude='__pycache__/' \
		--exclude='*.pyc' \
		-e "ssh -p $(SSH_PORT) -o StrictHostKeyChecking=no" \
		./ $(LOGIN)@localhost:/home/$(LOGIN)/inception/
	@echo "Project files synced successfully"

vm-data-setup: vm-wait-ssh
	@echo "Setting up data directories in VM at /home/$(LOGIN)/data..."
	@ssh -p $(SSH_PORT) -o StrictHostKeyChecking=no $(LOGIN)@localhost "\
		sudo mkdir -p /home/$(LOGIN)/data/wordpress_db && \
		sudo mkdir -p /home/$(LOGIN)/data/wordpress_files && \
		sudo chown -R $(LOGIN):$(LOGIN) /home/$(LOGIN)/data && \
		echo 'Data directories created successfully at /home/$(LOGIN)/data'"

vm-resync:
	@echo "Re-syncing project files to VM..."
	@$(MAKE) vm-sync-project

down:
	$(COMPOSE) down

build:
	$(COMPOSE) build

logs:
	$(COMPOSE) logs -f

test-nginx-internal:
	@echo "Testing nginx server access from inside container (skip cert verification)..."
ifeq ($(USE_VM),1)
	$(COMPOSE_EXEC) nginx curl -k -I https://localhost"
else
	$(COMPOSE_EXEC) nginx curl -k -I https://localhost
endif

test-nginx-internal-ssl:
	@echo "Testing nginx server access from inside container (with SSL verification)..."
ifeq ($(USE_VM),1)
	$(COMPOSE_EXEC) nginx curl --cacert /etc/nginx/ssl/cert.pem -I https://localhost"
else
	$(COMPOSE_EXEC) nginx curl --cacert /etc/nginx/ssl/cert.pem -I https://localhost
endif

test-nginx-host:
	@echo "Testing nginx server access from host system (skip cert verification)..."
ifeq ($(USE_VM),1)
	@echo "Using domain: $(LOGIN).42.fr (via VM port forwarding)"
	curl -k -I https://$(LOGIN).42.fr
else
	@echo "Using domain: $(LOGIN).42.fr (direct local access)"
	curl -k -I https://$(LOGIN).42.fr
endif

test-nginx-host-ssl:
	@echo "Testing nginx server access from host system (with SSL verification)..."
ifeq ($(USE_VM),1)
	@echo "Using domain: $(LOGIN).42.fr (via VM port forwarding)"
else
	@echo "Using domain: $(LOGIN).42.fr (direct local access)"
endif
	@if [ -f $(NGINX_SSL_DIR)/cert.pem ]; then \
		curl --cacert $(NGINX_SSL_DIR)/cert.pem -I https://$(LOGIN).42.fr; \
	else \
		echo "SSL certificate not found. Run 'make up' first to generate certificates."; \
	fi

test-nginx-host-header:
	@echo "Testing nginx server using Host header (no /etc/hosts modification needed)..."
	@echo "Using domain: $(LOGIN).42.fr"
	curl -k -H "Host: $(LOGIN).42.fr" -I https://127.0.0.1

test-nginx-host-header-ssl:
	@echo "Testing nginx server using Host header with SSL verification..."
	@echo "Using domain: $(LOGIN).42.fr"
	@if [ -f $(NGINX_SSL_DIR)/cert.pem ]; then \
		curl --cacert $(NGINX_SSL_DIR)/cert.pem -H "Host: $(LOGIN).42.fr" -I https://127.0.0.1; \
	else \
		echo "SSL certificate not found. Run 'make up' first to generate certificates."; \
	fi

clean: down
	$(DOCKER_SYSTEM) prune -f

ifeq ($(USE_VM),1)
fclean: clean
	@echo "Cleaning data directories in VM at /home/$(LOGIN)/data..."
	@ssh -p $(SSH_PORT) -o StrictHostKeyChecking=no $(LOGIN)@localhost "\
		sudo rm -rf /home/$(LOGIN)/data/wordpress_db && \
		sudo rm -rf /home/$(LOGIN)/data/wordpress_files && \
		echo 'Data directories cleaned at /home/$(LOGIN)/data'"
else
fclean: clean
	@echo "Cleaning local data directories..."
	rm -rf $(WORDPRESS_DB_DIR)
	rm -rf $(WORDPRESS_FILES_DIR)
endif

re: fclean all

.PHONY: all help up down build clean fclean re logs ssl-setup browser-setup test-nginx-internal test-nginx-internal-ssl test-nginx-host test-nginx-host-ssl test-nginx-host-header test-nginx-host-header-ssl ssh-key-check vm vm-download vm-download-full vm-guest-additions-download vm-init vm-storage vm-config vm-create vm-serve-preseed vm-stop-preseed vm-install-docker vm-test-docker vm-start vm-start-gui vm-stop vm-pause vm-resume vm-status vm-network-setup vm-network-bridged vm-network-info vm-boot vm-wait-ssh vm-sync-project vm-data-setup vm-resync
