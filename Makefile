NAME = inception
LOGIN ?= $(shell whoami)
COMPOSE = LOGIN=$(LOGIN) COMPOSE_BAKE=true docker-compose -f srcs/docker-compose.yml

all: up

up: hosts
	$(COMPOSE) up -d

hosts:
	@echo "Configuring /etc/hosts for $(LOGIN).42.fr..."
	@if ! grep -q "$(LOGIN).42.fr" /etc/hosts 2>/dev/null; then \
		echo "127.0.0.1 $(LOGIN).42.fr" | sudo tee -a /etc/hosts > /dev/null && \
		echo "Added $(LOGIN).42.fr to /etc/hosts" || \
		echo "Failed to add $(LOGIN).42.fr to /etc/hosts (sudo required)"; \
	else \
		echo "$(LOGIN).42.fr already exists in /etc/hosts"; \
	fi

vm-download:
	@echo "Downloading Debian ISO..."
	@mkdir -p /goinfre/niida/iso
	curl -L -o /goinfre/niida/iso/debian-12.11.0-amd64-netinst.iso "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso"

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
	VBoxManage sharedfolder add "Inception" --name "42share" --hostpath "/goinfre/niida/42share/" --automount

vm-create: vm-download vm-init vm-storage vm-network-setup vm-config
	@echo "VM 'Inception' created successfully!"
	@echo "Start VM with: make vm-start-gui"

vm-setup-docker:
	@echo "Setting up Docker in VM..."
	@echo "Run these commands inside the VM after SSH connection:"
	@echo "ssh user@192.168.56.100"
	@echo ""
	@echo "# Update system"
	@echo "sudo apt update && sudo apt upgrade -y"
	@echo ""
	@echo "# Install Docker"
	@echo "sudo apt install -y ca-certificates curl gnupg lsb-release"
	@echo "sudo mkdir -p /etc/apt/keyrings"
	@echo "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
	@echo "echo \"deb [arch=\$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \$$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
	@echo "sudo apt update"
	@echo "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
	@echo ""
	@echo "# Add user to docker group"
	@echo "sudo usermod -aG docker \$$USER"
	@echo "newgrp docker"
	@echo ""
	@echo "# Test Docker"
	@echo "docker run hello-world"

vm:
	VBoxManage sharedfolder add "Inception" --name "42share" --hostpath "/goinfre/niida/42share/"

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
	@echo "Setting up VirtualBox host-only network..."
	VBoxManage hostonlyif create || true
	VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1 --netmask 255.255.255.0
	VBoxManage dhcpserver add --netname HostInterfaceNetworking-vboxnet0 --ip 192.168.56.1 --netmask 255.255.255.0 --lowerip 192.168.56.100 --upperip 192.168.56.200 --enable || true
	VBoxManage modifyvm "Inception" --nic1 hostonly --hostonlyadapter1 vboxnet0
	@echo "Network setup complete. VM will use 192.168.56.x subnet"

vm-network-bridged:
	@echo "Configuring VM for bridged networking..."
	VBoxManage modifyvm "Inception" --nic1 bridged --bridgeadapter1 "en0"
	@echo "Bridged networking configured"

vm-network-info:
	@echo "VirtualBox network configuration:"
	VBoxManage list hostonlyifs
	@echo "\nVM network settings:"
	VBoxManage showvminfo "Inception" | grep -E "(NIC|MAC|Cable|Line)"

down:
	$(COMPOSE) down

build:
	$(COMPOSE) build

logs:
	$(COMPOSE) logs -f

clean: down
	docker system prune -f

fclean: clean
	rm -rf ~/data/wordpress_db
	rm -rf ~/data/wordpress_files

re: fclean all

.PHONY: all up down build clean fclean re hosts logs vm vm-download vm-init vm-storage vm-config vm-create vm-setup-docker vm-start vm-start-gui vm-stop vm-pause vm-resume vm-status vm-network-setup vm-network-bridged vm-network-info 
