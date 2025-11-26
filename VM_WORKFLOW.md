# VM Setup Workflow

## Initial Setup

1. **Create and configure VM:**
   ```bash
   make vm-create
   ```

2. **At boot menu, start automated installation:**
   - Press TAB at the boot menu
   - Add: `auto url=http://<local enp0 ip>:8000/preseed.cfg`
   - Press ENTER
   - Installation will complete automatically (SSH setup only, no Docker)

3. **After installation completes, VM will reboot**

4. **Install Docker in the VM:**
   ```bash
   make vm-install-docker
   ```
   This will:
   - Copy `scripts/install-docker.sh` to the VM
   - Run the installation script with sudo
   - Install Docker CE, Docker Compose, and all dependencies
   - Add user to docker group
   - Enable and start Docker service

5. **Start the Inception project:**
   ```bash
   make up
   ```

## Notes

- **Preseed installer** only sets up SSH access (fast installation)
- **Docker installation** happens separately via script (more reliable)
- After Docker install, you may need to log out/in for group changes, or run: `newgrp docker`
