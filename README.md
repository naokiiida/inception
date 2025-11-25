# inception

A Docker-based infrastructure setup project implementing WordPress with NGINX and MariaDB.

## Overview

This project sets up a containerized web infrastructure with proper security and networking. It includes:
- NGINX with TLSv1.2/1.3
- WordPress with PHP-FPM
- MariaDB database (generic, reusable for any app)
- Docker networking and volumes
- Secure credential management

## Architecture Note

- MariaDB is now a generic database server: it only sets up the root user and basic security, and does not create any application-specific databases or users.
- WordPress is responsible for creating its own database, user, and privileges at startup. This follows microservices best practices and makes the stack more modular and reusable.
- The WordPress container receives the MariaDB root password via environment variable (`DB_ROOT_PASSWORD`) and uses it to set up its own database and user if needed.

This separation of concerns makes it easy to reuse the MariaDB container for other applications and improves maintainability.

for further improvement, I could rely more on secrets store such as Docker secrets, and test decoupling with other container images

## Prerequisites

### Host Machine (for VM development)
- VirtualBox
- Make
- rsync (for syncing project files to VM)

### VM / Target Environment
- Docker
- Docker Compose
- Make

## Directory Structure

```
.
├── Makefile
├── README.md
└── srcs/
    ├── docker-compose.yml
    ├── .env
    ├── secrets/
    └── requirements/
        ├── nginx/
        ├── wordpress/
        ├── mariadb/
        ├── tools/
        └── bonus/
```

## Setup

1. Clone the repository
2. Copy `srcs/.env.example` to `srcs/.env` and configure your environment variables
3. Generate SSL certificates and place them in `srcs/secrets/`
4. Run `make build` to build the containers
5. Run `make up` to start the services

## Usage

- `make up`: Start all services
- `make down`: Stop all services
- `make build`: Rebuild containers
- `make clean`: Clean up Docker resources
- `make fclean`: Remove all data and containers
- `make re`: Rebuild everything from scratch

## Security

- TLSv1.2/1.3 only
- Secure credential storage using Docker secrets
- Network isolation between containers
- No hardcoded passwords
- WordPress user restrictions

## Development

This project follows strict development guidelines:
- Custom Dockerfiles only
- No pre-built images except base
- Proper PID 1 handling
- No infinite loops or hacky patches
- Comprehensive documentation

## Note

This project is part of the 42 curriculum.
