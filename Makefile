NAME = inception
LOGIN ?= $(shell whoami)

# Path Configuration
DATA_DIR ?= /home/$(LOGIN)/data
NGINX_SSL_DIR ?= $(DATA_DIR)/nginx_ssl
WORDPRESS_DB_DIR ?= $(DATA_DIR)/wordpress_db
WORDPRESS_FILES_DIR ?= $(DATA_DIR)/wordpress_files

# SSL Configuration
SSL_CA_DIR = ./srcs/requirements/tools/ssl-ca
CA_CERT = $(SSL_CA_DIR)/generated/ca-cert.pem
SERVER_CERT = $(SSL_CA_DIR)/generated/certs/$(LOGIN).42.fr-cert.pem
SERVER_KEY = $(SSL_CA_DIR)/generated/certs/$(LOGIN).42.fr-key.pem

# WordPress URL Configuration
HTTPS_PORT ?= 8443
WORDPRESS_URL = https://$(LOGIN).42.fr:$(HTTPS_PORT)

# Docker configuration for local execution
COMPOSE = LOGIN=$(LOGIN) VOLUME_BASE=/home/$(LOGIN) COMPOSE_BAKE=true docker compose -f srcs/docker-compose.yml
COMPOSE_EXEC = docker compose -f srcs/docker-compose.yml exec
DOCKER_EXEC = docker exec
DOCKER_SYSTEM = docker system

all: up

help:
	@echo "Inception Docker Project"
	@echo ""
	@echo "Environment Variables:"
	@echo "  LOGIN       Your login name (default: current user)"
	@echo "  HTTPS_PORT  HTTPS port for nginx (default: 8443)"
	@echo ""
	@echo "Main targets:"
	@echo "  up          Start all services (includes SSL setup)"
	@echo "  down        Stop all services"
	@echo "  build       Build all images"
	@echo "  clean       Clean up containers and images"
	@echo "  fclean      Full clean including data directories"
	@echo "  re          Rebuild everything (fclean + up)"
	@echo "  logs        Show container logs"
	@echo ""
	@echo "SSL Certificate Setup:"
	@echo "  ca-create               Create Certificate Authority (one-time)"
	@echo "  cert-create             Generate server certificate for $(LOGIN).42.fr"
	@echo "  ssl-setup               Complete SSL setup (CA + cert + copy to data dir)"
	@echo "  browser-setup           Show browser configuration instructions"
	@echo ""
	@echo "Testing targets:"
	@echo "  test-nginx-internal      Test nginx from inside container"
	@echo "  test-nginx-host          Test nginx from host (with --resolve)"
	@echo "  test-nginx-host-ssl      Test nginx with SSL verification"
	@echo "  test-nginx-host-header   Test nginx using Host header"
	@echo "  test-wp-url              Check WordPress URL configuration"
	@echo ""
	@echo "Certificate Verification:"
	@echo "  cert-check               View certificate details and SANs"
	@echo "  cert-verify              Verify certificate chain (should show OK)"
	@echo ""
	@echo "Setup:"
	@echo "  data-setup               Create data directories"
	@echo ""
	@echo "VM Management:"
	@echo "  For VM-related operations, use: make -f Makefile.vm vm-help"
	@echo ""
	@echo "WordPress URL: $(WORDPRESS_URL)"
	@echo ""
	@echo "Examples:"
	@echo "  make up                  # Start services locally"
	@echo "  make browser-setup       # Show how to configure browser"
	@echo "  make test-nginx-host-ssl # Test with SSL verification"
	@echo "  make fclean && make up   # Fresh start"

data-setup:
	@echo "Setting up data directories at $(DATA_DIR)..."
	@mkdir -p $(WORDPRESS_DB_DIR)
	@mkdir -p $(WORDPRESS_FILES_DIR)
	@mkdir -p $(NGINX_SSL_DIR)
	@echo "Data directories created successfully"

ca-create:
	@echo "=== Creating Certificate Authority ==="
	@if [ ! -f $(CA_CERT) ]; then \
		cd $(SSL_CA_DIR) && ./create-ca.sh; \
	else \
		echo "CA already exists at $(CA_CERT)"; \
	fi
	@echo ""
	@echo "✅ CA Certificate created: $(CA_CERT)"
	@echo ""
	@echo "📋 To trust this CA in Firefox:"
	@echo "   1. Open Firefox → Settings → Privacy & Security → Certificates → View Certificates"
	@echo "   2. Click 'Authorities' tab → Import"
	@echo "   3. Select: $(shell pwd)/$(CA_CERT)"
	@echo "   4. Check 'Trust this CA to identify websites'"
	@echo ""

cert-create: ca-create
	@echo "=== Generating Server Certificate for $(LOGIN).42.fr ==="
	@if [ ! -f $(SERVER_CERT) ]; then \
		cd $(SSL_CA_DIR) && ./sign-server-cert.sh -d $(LOGIN).42.fr -a "*.$(LOGIN).42.fr,localhost,127.0.0.1"; \
	else \
		echo "Certificate already exists at $(SERVER_CERT)"; \
	fi
	@echo "✅ Server certificate created for $(LOGIN).42.fr"

ssl-setup: data-setup cert-create
	@if [ ! -f $(NGINX_SSL_DIR)/cert.pem ]; then \
		cp $(SERVER_CERT) $(NGINX_SSL_DIR)/cert.pem; \
	fi
	@if [ ! -f $(NGINX_SSL_DIR)/key.pem ]; then \
		cp $(SERVER_KEY) $(NGINX_SSL_DIR)/key.pem; \
	fi
	@if [ ! -f $(NGINX_SSL_DIR)/ca-cert.pem ]; then \
		cp $(CA_CERT) $(NGINX_SSL_DIR)/ca-cert.pem; \
	fi

browser-setup:
	@echo ""
	@echo "=== Browser Configuration for $(WORDPRESS_URL) ==="
	@echo ""
	@echo "Step 1: Import CA Certificate into Firefox (Required)"
	@echo "  1. Open Firefox → Settings → Privacy & Security → Certificates → View Certificates"
	@echo "  2. Click 'Authorities' tab → Import"
	@echo "  3. Select: $(shell pwd)/$(NGINX_SSL_DIR)/ca-cert.pem"
	@echo "  4. ✅ Check 'Trust this CA to identify websites'"
	@echo "  5. Click OK"
	@echo ""
	@echo "Step 2: Configure Domain Resolution"
	@echo ""
	@echo "Firefox about:config (Advanced)"
	@echo "  1. Type about:config in address bar"
	@echo "  2. Search for 'network.dns.localDomains'"
	@echo "  3. Add '$(LOGIN).42.fr' to redirect to localhost"
	@echo ""
	@echo "Access URL: $(WORDPRESS_URL)"
	@echo "Testing: make test-nginx-host-ssl"
	@echo ""

up: ssl-setup
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

build:
	$(COMPOSE) build

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

test-nginx-internal:
	@echo "Testing nginx server access from inside container (skip cert verification)..."
	$(COMPOSE_EXEC) nginx curl -k -I https://localhost

test-nginx-internal-ssl:
	@echo "Testing nginx server access from inside container (with SSL verification)..."
	$(COMPOSE_EXEC) nginx curl --cacert /etc/nginx/ssl/cert.pem -I https://localhost

test-nginx-host:
	@echo "Testing nginx server access from host system (skip cert verification)..."
	@echo "Using URL: $(WORDPRESS_URL)"
	curl -k --resolve $(LOGIN).42.fr:$(HTTPS_PORT):127.0.0.1 -I $(WORDPRESS_URL)

test-nginx-host-ssl:
	@echo "Testing nginx server access from host system (with SSL verification)..."
	@echo "Using URL: $(WORDPRESS_URL)"
	@if [ -f $(NGINX_SSL_DIR)/ca-cert.pem ]; then \
		curl --cacert $(NGINX_SSL_DIR)/ca-cert.pem --resolve $(LOGIN).42.fr:$(HTTPS_PORT):127.0.0.1 -I $(WORDPRESS_URL); \
	else \
		echo "SSL certificate not found. Run 'make up' first to generate certificates."; \
	fi

test-nginx-host-header:
	@echo "Testing nginx server using Host header (no /etc/hosts modification needed)..."
	@echo "Using domain: $(LOGIN).42.fr:$(HTTPS_PORT)"
	curl -k -H "Host: $(LOGIN).42.fr" -I https://127.0.0.1:$(HTTPS_PORT)

test-nginx-host-header-ssl:
	@echo "Testing nginx server using Host header with SSL verification..."
	@echo "Using domain: $(LOGIN).42.fr:$(HTTPS_PORT)"
	@if [ -f $(NGINX_SSL_DIR)/ca-cert.pem ]; then \
		curl --cacert $(NGINX_SSL_DIR)/ca-cert.pem -H "Host: $(LOGIN).42.fr" -I https://127.0.0.1:$(HTTPS_PORT); \
	else \
		echo "SSL certificate not found. Run 'make up' first to generate certificates."; \
	fi

test-wp-url:
	@echo "=== WordPress URL Configuration Check ==="
	@echo "Expected URL (from Makefile): $(WORDPRESS_URL)"
	@echo ""
	@echo "Actual URLs in WordPress database:"
	@echo -n "  siteurl: "
	@$(COMPOSE_EXEC) wordpress wp option get siteurl --allow-root 2>/dev/null || echo "WordPress not installed yet"
	@echo -n "  home:    "
	@$(COMPOSE_EXEC) wordpress wp option get home --allow-root 2>/dev/null || echo "WordPress not installed yet"

cert-check:
	@echo "=== Certificate Details Check ==="
	@if [ -f $(NGINX_SSL_DIR)/cert.pem ]; then \
		echo "Certificate file: $(NGINX_SSL_DIR)/cert.pem"; \
		echo ""; \
		echo "Subject Alternative Names:"; \
		openssl x509 -noout -text -in $(NGINX_SSL_DIR)/cert.pem | grep -A1 "Subject Alternative Name"; \
		echo ""; \
		echo "Full certificate details:"; \
		openssl x509 -noout -text -in $(NGINX_SSL_DIR)/cert.pem; \
	else \
		echo "Certificate not found at $(NGINX_SSL_DIR)/cert.pem"; \
		echo "Run 'make ssl-setup' first to generate certificates."; \
	fi

cert-verify:
	@echo "=== Certificate Chain Verification ==="
	@if [ -f $(NGINX_SSL_DIR)/cert.pem ] && [ -f $(NGINX_SSL_DIR)/ca-cert.pem ]; then \
		echo "Verifying: $(NGINX_SSL_DIR)/cert.pem"; \
		echo "Against CA: $(NGINX_SSL_DIR)/ca-cert.pem"; \
		echo ""; \
		openssl verify -CAfile $(NGINX_SSL_DIR)/ca-cert.pem $(NGINX_SSL_DIR)/cert.pem; \
	else \
		echo "Certificate or CA not found."; \
		echo "Run 'make ssl-setup' first to generate certificates."; \
	fi

clean: down
	$(DOCKER_SYSTEM) prune -f

fclean: clean
	@echo "Cleaning local data directories..."
	sudo rm -rf $(DATA_DIR)

re: fclean all

.PHONY: all help up down build clean fclean re logs data-setup ca-create cert-create ssl-setup browser-setup test-nginx-internal test-nginx-internal-ssl test-nginx-host test-nginx-host-ssl test-nginx-host-header test-nginx-host-header-ssl test-wp-url cert-check cert-verify
