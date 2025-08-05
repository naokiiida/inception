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

.PHONY: all up down build clean fclean re hosts logs 