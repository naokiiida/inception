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

.PHONY: all up down build clean fclean re hosts logs vm vm-start vm-start-gui vm-stop vm-pause vm-resume vm-status vm-network-setup vm-network-bridged vm-network-info 
