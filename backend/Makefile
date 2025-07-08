# Makefile for Capture-v3 Backend Dependency Management

.PHONY: help compile upgrade upgrade-package install clean

# Default target
help:
	@echo "Available commands:"
	@echo "  make compile        - Compile requirements.in to requirements.txt"
	@echo "  make upgrade        - Upgrade all packages to latest compatible versions"
	@echo "  make upgrade-package PKG=<name>  - Upgrade specific package"
	@echo "  make install        - Install dependencies from requirements.txt"
	@echo "  make clean          - Remove compiled Python files and caches"

# Compile requirements.in to requirements.txt
compile:
	pip-compile requirements.in -o requirements.txt

# Upgrade all packages to latest compatible versions
upgrade:
	pip-compile --upgrade requirements.in -o requirements.txt

# Upgrade specific package (usage: make upgrade-package PKG=fastapi)
upgrade-package:
	@if [ -z "$(PKG)" ]; then \
		echo "Error: Please specify package name with PKG=<name>"; \
		exit 1; \
	fi
	pip-compile --upgrade-package $(PKG) requirements.in -o requirements.txt

# Install dependencies
install:
	pip install -r requirements.txt

# Clean Python cache files
clean:
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +