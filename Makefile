# RealChord – local development helpers (Linux).
#
# Test instances use their own data directory (DATA_DIR, default .dev-data/),
# so they never touch the data of a normally started app.
#
#   make            show this help
#   make dev        start a test instance with hot reload
#   make start      build and start a test instance (without Flutter tooling)
#   make reset      delete the test instance's data (fresh start with demo song)
#   make backend    start a local PocketBase with the repository's schema and hooks
#   make server-*   install and operate the PocketBase server (SERVER=root@host)

SHELL := /bin/bash
.DEFAULT_GOAL := help

ROOT     := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
APP      := $(ROOT)/app
PACKAGE  := $(ROOT)/packages/chordpro
DATA_DIR ?= $(ROOT)/.dev-data

# Flutter from PATH, otherwise from ~/development/flutter.
FLUTTER  ?= $(shell command -v flutter 2>/dev/null || echo $(HOME)/development/flutter/bin/flutter)
DART     := $(dir $(FLUTTER))dart

BUNDLE   := $(APP)/build/linux/x64/debug/bundle/realchord

# CI image (tool/ci/Dockerfile) in the Forgejo container registry. The tag is the
# Flutter version; keep it in sync with .forgejo/workflows/ci.yml.
FLUTTER_VERSION ?= 3.47.9
CI_IMAGE        ?= ghcr.io/tafli/realchord-ci:$(FLUTTER_VERSION)
DOCKER          ?= docker

# PocketBase server (ADR-0014, docs/operations/server.md). SERVER is the SSH target;
# it defaults to the production instance (api.realchord.app, Proxmox CT 600).
# Override it for another instance, e.g. `make server-install SERVER=root@<ip>`.
# PB_VERSION is the pinned PocketBase version; updates are deliberate (ADR-0004).
SERVER          ?= root@192.168.1.40
PB_VERSION      ?= 0.40.6
SSH             ?= ssh
SERVER_BACKUPS  := /var/lib/pocketbase/backups
BACKUP_DIR      ?= $(ROOT)/.server-backups
# Local PocketBase (make backend); its data lives in DATA_DIR like the test instance.
BACKEND_PORT    ?= 8090

# Redirects the app's private data to DATA_DIR: REALCHORD_DATA_DIR for the
# database and PDFs, XDG_DATA_HOME for the settings (shared_preferences).
TEST_ENV := REALCHORD_DATA_DIR=$(DATA_DIR)/app XDG_DATA_HOME=$(DATA_DIR)/xdg

.PHONY: help setup dev start build reset data-dir backend check test codegen l10n screenshots examples doctor clean ci-image ci-image-push \
	server-target server-install server-status server-logs server-backup server-fetch-backup server-ssh

help: ## Show this help
	@echo "RealChord – make targets"
	@echo
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Test data: $(DATA_DIR)   (override with DATA_DIR=...)"
	@echo "Flutter:   $(FLUTTER)"

setup: ## Install dependencies, generate code and translations
	@test -x "$(FLUTTER)" || { echo "Flutter not found. Install it or set FLUTTER=/path/to/flutter"; exit 1; }
	cd $(PACKAGE) && $(DART) pub get
	cd $(ROOT)/server && $(DART) pub get
	cd $(APP) && $(FLUTTER) pub get
	$(MAKE) codegen l10n

dev: data-dir ## Start a test instance with hot reload (r = reload, q = quit)
	cd $(APP) && $(TEST_ENV) $(FLUTTER) run -d linux

start: build data-dir ## Build and start a test instance (debug build, no hot reload)
	$(TEST_ENV) $(BUNDLE)

build: ## Build the Linux debug app
	cd $(APP) && $(FLUTTER) build linux --debug

reset: ## Delete all data of the test instance
	rm -rf "$(DATA_DIR)"
	@echo "Test data deleted: $(DATA_DIR)"

data-dir:
	@mkdir -p "$(DATA_DIR)/app" "$(DATA_DIR)/xdg"
	@echo "Test data: $(DATA_DIR)"

backend: ## Start a local PocketBase with the schema and hooks from server/ (PB_VERSION)
	@pb=$$($(ROOT)/tool/server/fetch-pocketbase.sh $(PB_VERSION)) && \
		echo "PocketBase $(PB_VERSION): http://127.0.0.1:$(BACKEND_PORT)/_/  (data: $(DATA_DIR)/pb_data)" && \
		echo "Create a superuser: $$pb superuser upsert EMAIL PASS --dir $(DATA_DIR)/pb_data" && \
		$$pb serve --dir $(DATA_DIR)/pb_data --hooksDir $(ROOT)/server/pb_hooks \
			--migrationsDir $(ROOT)/server/pb_migrations --http 127.0.0.1:$(BACKEND_PORT)

check: ## Run all checks (format, analysis, l10n, tests) – the test gate
	$(ROOT)/tool/check.sh

test: ## Run all tests
	cd $(PACKAGE) && $(DART) test
	cd $(ROOT)/server && $(DART) test
	cd $(APP) && $(FLUTTER) test

codegen: ## Regenerate the drift database code
	cd $(APP) && $(DART) run build_runner build

l10n: ## Regenerate the translations from the ARB files
	cd $(APP) && $(FLUTTER) gen-l10n

screenshots: ## Render screenshots with real fonts to app/build/screenshots/
	cd $(APP) && $(FLUTTER) test test_screenshots
	@echo "Screenshots: $(APP)/build/screenshots/"

examples: ## Rebuild docs/examples/feature-showcase.zip from the example files
	cd $(ROOT)/docs/examples && rm -f feature-showcase.zip && \
		python3 -c "import zipfile; z = zipfile.ZipFile('feature-showcase.zip', 'w', zipfile.ZIP_DEFLATED); [z.write(f) for f in ('feature-showcase.cho', 'stage-plan.svg')]; z.close()"
	@echo "Updated docs/examples/feature-showcase.zip"

doctor: ## Show the state of the Flutter toolchain
	$(FLUTTER) doctor

clean: ## Remove build output (keeps test data; see 'make reset')
	cd $(APP) && $(FLUTTER) clean

ci-image: ## Build the CI image (tool/ci/Dockerfile) with docker
	$(DOCKER) build --build-arg FLUTTER_VERSION=$(FLUTTER_VERSION) -t $(CI_IMAGE) $(ROOT)/tool/ci

ci-image-push: ## Push the CI image (needs: docker login ghcr.io)
	$(DOCKER) push $(CI_IMAGE)

server-target:
	@test -n "$(SERVER)" || { echo "Set SERVER to the SSH target, e.g. make $(MAKECMDGOALS) SERVER=root@<ip>"; exit 1; }

server-install: server-target ## Install or update the server (PocketBase PB_VERSION, hooks, migrations)
	tar -C $(ROOT) -czf - tool/server server/pb_hooks server/pb_migrations | \
		$(SSH) $(SERVER) 'd=$$(mktemp -d /tmp/realchord-setup.XXXXXX) && tar -C $$d -xzf - && bash $$d/tool/server/install.sh $(PB_VERSION)'

server-status: server-target ## Show services, PocketBase version and backups of the server
	@$(SSH) $(SERVER) 'systemctl --no-pager --lines=0 status pocketbase cloudflared realchord-backup.timer; \
		echo; /opt/pocketbase/pocketbase --version; curl -fsS http://127.0.0.1:8090/api/health; echo; \
		echo; echo "Backups:"; ls -lh $(SERVER_BACKUPS) | tail -n 5; echo; df -h /'

server-logs: server-target ## Follow the PocketBase and tunnel logs of the server (Ctrl+C to stop)
	$(SSH) -t $(SERVER) 'journalctl -u pocketbase -u cloudflared -n 100 -f'

server-backup: server-target ## Run a backup on the server now
	$(SSH) $(SERVER) 'systemctl start realchord-backup.service && journalctl -u realchord-backup -n 3 -o cat'

server-fetch-backup: server-target ## Copy the latest server backup to BACKUP_DIR (off-host copy)
	@mkdir -p "$(BACKUP_DIR)"
	@latest=$$($(SSH) $(SERVER) 'ls -1t $(SERVER_BACKUPS)/realchord-*.tar.gz 2>/dev/null | head -n 1'); \
		test -n "$$latest" || { echo "No backup on the server yet"; exit 1; }; \
		$(SSH) $(SERVER) "cat '$$latest'" >"$(BACKUP_DIR)/$$(basename $$latest)"; \
		echo "Saved $(BACKUP_DIR)/$$(basename $$latest)"

server-ssh: server-target ## Open a shell on the server
	$(SSH) $(SERVER)
