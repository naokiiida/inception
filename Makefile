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

ifeq ($(USE_VM),1)
    DOCKER_CMD = ssh -p 2222 user@localhost
    COMPOSE = $(DOCKER_CMD) "cd /home/user/inception && LOGIN=$(LOGIN) COMPOSE_BAKE=true docker compose -f srcs/docker-compose.yml"
    DOCKER_EXEC = $(DOCKER_CMD) "cd /home/user/inception && docker exec"
    DOCKER_SYSTEM = $(DOCKER_CMD) "docker system"
else
    COMPOSE = LOGIN=$(LOGIN) COMPOSE_BAKE=true docker compose -f srcs/docker-compose.yml
    DOCKER_EXEC = docker exec
    DOCKER_SYSTEM = docker system
endif

all: up

help:
	@echo "Inception Docker Project"
	@echo ""
	@echo "Environment Variables:"
	@echo "  USE_VM=1    Run Docker commands in VM via SSH (default)"
	@echo "  USE_VM=0    Run Docker commands locally on host"
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
	@echo "  vm-start      Start VM (headless)"
	@echo "  vm-start-gui  Start VM (with GUI)"
	@echo "  vm-stop       Stop VM"
	@echo "  vm-status     Show VM status"
	@echo ""
	@echo "Examples:"
	@echo "  make up                   # Start in VM (default)"
	@echo "  USE_VM=0 make up         # Start locally"
	@echo "  USE_VM=0 make logs       # View logs locally"

up: vm-start-gui ssl-setup
	$(COMPOSE) up -d

ssl-setup:
	@echo "Setting up SSL certificates for host system access..."
	@mkdir -p ~/data/nginx_ssl
	@echo "SSL certificates will be available in ~/data/nginx_ssl/ after container start"

browser-setup:
	@echo ""
	@echo "=== Browser Configuration for $(LOGIN).42.fr (No sudo required) ==="
	@echo ""
	@echo "Option 1: Browser Extensions"
	@echo "  Chrome: Install 'Host Admin App' extension"
	@echo "  Firefox: Install 'Virtual Hosts' extension"
	@echo "  Add mapping: 127.0.0.1 -> $(LOGIN).42.fr"
	@echo ""
	@echo "Option 2: Import SSL Certificate (recommended)"
	@echo "  1. After 'make up', certificate will be at: ~/data/nginx_ssl/cert.pem"
	@echo "  2. Chrome: Settings -> Privacy & Security -> Security -> Manage Certificates -> Authorities -> Import"
	@echo "  3. Firefox: Settings -> Privacy & Security -> Certificates -> View Certificates -> Authorities -> Import"
	@echo "  4. Import ~/data/nginx_ssl/cert.pem"
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
	@mkdir -p /goinfre/niida/iso
	curl -L -o /goinfre/niida/iso/debian-12.11.0-amd64-netinst.iso "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso"

vm-download-full:
	@echo "Downloading full Debian ISO (offline installation)..."
	@mkdir -p /goinfre/niida/iso
	curl -L -o /goinfre/niida/iso/debian-12.11.0-amd64-DVD-1.iso "https://cdimage.debian.org/debian-cd/current/amd64/iso-dvd/debian-12.11.0-amd64-DVD-1.iso"

vm-guest-additions-download:
	@echo "Downloading VirtualBox Guest Additions ISO..."
	@mkdir -p /goinfre/niida/iso
	@VBOX_VERSION=$$(VBoxManage --version | cut -d 'r' -f1) && \
	curl -L -o /goinfre/niida/iso/VBoxGuestAdditions.iso "https://download.virtualbox.org/virtualbox/$$VBOX_VERSION/VBoxGuestAdditions_$$VBOX_VERSION.iso"

vm-init:
	@echo "Creating VM..."
	@mkdir -p /goinfre/niida/vm
	VBoxManage createvm --name "Inception" --ostype "Debian_64" --register --basefolder "/goinfre/niida/vm"
	VBoxManage modifyvm "Inception" --memory 2048 --vram 128
	VBoxManage modifyvm "Inception" --cpus 2

vm-storage:
	@echo "Setting up storage..."
	VBoxManage createhd --filename "/goinfre/niida/vm/Inception/Inception.vdi" --size 20480 --format VDI
	VBoxManage storagectl "Inception" --name "SATA Controller" --add sata --controller IntelAHCI
	VBoxManage storageattach "Inception" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "/goinfre/niida/vm/Inception/Inception.vdi"
	VBoxManage storagectl "Inception" --name "IDE Controller" --add ide --controller PIIX4
	VBoxManage storageattach "Inception" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "/goinfre/niida/iso/debian-12.11.0-amd64-netinst.iso"

vm-config:
	@echo "Configuring VM settings..."
	VBoxManage modifyvm "Inception" --boot1 dvd --boot2 disk --boot3 none --boot4 none
	VBoxManage modifyvm "Inception" --audio-driver none
	@mkdir -p "/goinfre/niida/42share"
	VBoxManage sharedfolder add "Inception" --name "42share" --hostpath "/goinfre/niida/42share/" --automount
	@echo "Attaching Guest Additions ISO..."
	VBoxManage storageattach "Inception" --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium "/goinfre/niida/iso/VBoxGuestAdditions.iso"
	@echo "Copying preseed file to shared folder..."
	@mkdir -p /goinfre/niida/42share
	cp preseed.cfg /goinfre/niida/42share/

vm-boot:
	@echo "VM 'Inception' created successfully!"
	@echo "Starting preseed server in background..."
	nohup make vm-serve-preseed > /tmp/preseed-server.log 2>&1 & echo $$! > /tmp/preseed-server.pid
	@sleep 2
	@echo "Starting VM for automated installation..."
	make vm-start-gui
	@echo ""
	@echo "At boot menu, press TAB and add: auto url=http://10.0.2.2:8000/preseed.cfg"
	@echo "Default credentials: root/root, user/user"
	@echo "Stop preseed server with: make vm-stop-preseed"

vm-create: vm-init vm-storage vm-network-setup vm-guest-additions-download vm-config vm-boot

vm-stop-preseed:
	@if [ -f /tmp/preseed-server.pid ]; then \
		kill `cat /tmp/preseed-server.pid` 2>/dev/null || true; \
		rm -f /tmp/preseed-server.pid /tmp/preseed-server.log; \
		echo "Preseed server stopped"; \
	else \
		echo "Preseed server not running"; \
	fi

vm-serve-preseed:
	@echo "Serving preseed file on http://0.0.0.0:8000"
	@echo "VM will access it via http://10.0.2.2:8000"
	@echo "Stop with Ctrl+C after installation completes"
	cd /goinfre/niida/42share && python3 -m http.server 8000

vm-test-docker:
	@echo "Testing Docker installation in VM..."
	@echo "SSH to the VM and run:"
	@echo "ssh -p 2222 user@localhost"
	ssh -p 2222 user@localhost "docker --version"
	ssh -p 2222 user@localhost "docker compose version"

vm-start:
	VBoxManage startvm "Inception" --type headless

vm-start-gui:
	VBoxManage startvm "Inception"

vm-stop:
	VBoxManage controlvm "Inception" poweroff

vm-pause:
	VBoxManage controlvm "Inception" pause

vm-resume:
	VBoxManage controlvm "Inception" resume

vm-status:
	VBoxManage showvminfo "Inception" --machinereadable | grep VMState

vm-network-setup:
	@echo "Setting up VirtualBox NAT networking with port forwarding..."
	VBoxManage modifyvm "Inception" --nic1 nat
	VBoxManage modifyvm "Inception" --natpf1 "ssh,tcp,,2222,,22"
	VBoxManage modifyvm "Inception" --natpf1 "http,tcp,,8080,,80"
	VBoxManage modifyvm "Inception" --natpf1 "https,tcp,,8443,,443"
	@echo "Network setup complete:"
	@echo "  - VM gets internet via NAT"
	@echo "  - SSH: localhost:2222"
	@echo "  - HTTP: localhost:8080"
	@echo "  - HTTPS: localhost:8443"

vm-network-bridged:
	@echo "Configuring VM for bridged networking..."
	VBoxManage modifyvm "Inception" --nic1 bridged --bridgeadapter1 "en0"
	@echo "Bridged networking configured"

vm-network-info:
	@echo "VM network configuration:"
	VBoxManage showvminfo "Inception" | grep -E "(NIC|MAC|Cable|Line|Rule)"
	@echo "\nPort forwarding rules:"
	VBoxManage showvminfo "Inception" | grep "NIC 1 Rule"

down:
	$(COMPOSE) down

build:
	$(COMPOSE) build

logs:
	$(COMPOSE) logs -f

test-nginx-internal:
	@echo "Testing nginx server access from inside container (skip cert verification)..."
ifeq ($(USE_VM),1)
	$(DOCKER_EXEC) \$$(docker compose -f srcs/docker-compose.yml ps -q nginx) curl -k -I https://localhost"
else
	$(DOCKER_EXEC) $$(docker compose -f srcs/docker-compose.yml ps -q nginx) curl -k -I https://localhost
endif

test-nginx-internal-ssl:
	@echo "Testing nginx server access from inside container (with SSL verification)..."
ifeq ($(USE_VM),1)
	$(DOCKER_EXEC) \$$(docker compose -f srcs/docker-compose.yml ps -q nginx) curl --cacert /etc/nginx/ssl/cert.pem -I https://localhost"
else
	$(DOCKER_EXEC) $$(docker compose -f srcs/docker-compose.yml ps -q nginx) curl --cacert /etc/nginx/ssl/cert.pem -I https://localhost
endif

test-nginx-host:
	@echo "Testing nginx server access from host system (skip cert verification)..."
	@echo "Using domain: $(LOGIN).42.fr"
	curl -k -I https://$(LOGIN).42.fr

test-nginx-host-ssl:
	@echo "Testing nginx server access from host system (with SSL verification)..."
	@echo "Using domain: $(LOGIN).42.fr"
	@if [ -f ~/data/nginx_ssl/cert.pem ]; then \
		curl --cacert ~/data/nginx_ssl/cert.pem -I https://$(LOGIN).42.fr; \
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
	@if [ -f ~/data/nginx_ssl/cert.pem ]; then \
		curl --cacert ~/data/nginx_ssl/cert.pem -H "Host: $(LOGIN).42.fr" -I https://127.0.0.1; \
	else \
		echo "SSL certificate not found. Run 'make up' first to generate certificates."; \
	fi

clean: down
	$(DOCKER_SYSTEM) prune -f

fclean: clean
	rm -rf ~/data/wordpress_db
	rm -rf ~/data/wordpress_files

re: fclean all

.PHONY: all help up down build clean fclean re logs ssl-setup browser-setup test-nginx-internal test-nginx-internal-ssl test-nginx-host test-nginx-host-ssl test-nginx-host-header test-nginx-host-header-ssl vm vm-download vm-download-full vm-guest-additions-download vm-init vm-storage vm-config vm-create vm-serve-preseed vm-stop-preseed vm-test-docker vm-start vm-start-gui vm-stop vm-pause vm-resume vm-status vm-network-setup vm-network-bridged vm-network-info vm-boot
