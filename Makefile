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
#   make apk        build an Android APK for manual installation (sideloading)
#   make release    build the Linux release package (runs on any x86-64 Linux)
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

# Android APK for sideloading (make apk). The release build is signed with the
# machine's debug key (app/android/app/build.gradle.kts) until a release key exists.
export ANDROID_HOME ?= $(HOME)/Android/Sdk
ADB         ?= $(ANDROID_HOME)/platform-tools/adb
APK_VERSION := $(shell sed -n 's/^version: *\([^+]*\).*/\1/p' $(APP)/pubspec.yaml)
APK_COMMIT  := $(shell git -C $(ROOT) rev-parse --short HEAD 2>/dev/null || echo unknown)
APK         := $(APP)/build/realchord-$(APK_VERSION)-$(APK_COMMIT).apk

# CI image (tool/ci/Dockerfile) in the GitHub container registry. The tag is the
# Flutter version; keep it in sync with .github/workflows/ci.yml.
FLUTTER_VERSION ?= 3.50.0
CI_IMAGE        ?= ghcr.io/tafli/realchord-ci:$(FLUTTER_VERSION)
DOCKER          ?= docker

# Linux release package (make release, ADR-0019), named after version and commit.
# Built in a Debian container (tool/release/linux.Dockerfile) so the result runs on
# every x86-64 CPU and distribution, not only on the machine that runs make.
RELEASE_NAME  := realchord-$(APK_VERSION)-$(APK_COMMIT)
RELEASE_IMAGE ?= realchord-release-linux:$(FLUTTER_VERSION)

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

.PHONY: help setup dev start build web web-serve deps upgrade apk apk-install release release-linux release-check reset data-dir backend check test codegen l10n screenshots examples doctor clean ci-image ci-image-push \
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

apk: ## Build an Android release APK for manual installation (app/build/realchord-<version>-<commit>.apk)
	@test -d "$(ANDROID_HOME)" || { echo "Android SDK not found. Install it or set ANDROID_HOME=/path/to/sdk"; exit 1; }
	cd $(APP) && $(FLUTTER) build apk --release
	cp $(APP)/build/app/outputs/flutter-apk/app-release.apk $(APK)
	@echo "APK: $(APK)"

apk-install: apk ## Build the APK and install it on a USB-connected device (adb, USB debugging on)
	$(ADB) install -r $(APK)

release: release-linux ## Build the release packages (currently Linux only)

release-check:
	@git -C $(ROOT) diff --quiet HEAD || echo "warning: uncommitted changes are not part of the release (built from commit $(APK_COMMIT))"

release-linux: release-check ## Build the Linux release in a container (app/build/realchord-<version>-<commit>-linux-x64.tar.gz)
	$(DOCKER) build -q --build-arg CI_IMAGE=$(CI_IMAGE) -t $(RELEASE_IMAGE) -f $(ROOT)/tool/release/linux.Dockerfile $(ROOT)/tool/release
	@mkdir -p $(APP)/build
	git -C $(ROOT) archive HEAD | $(DOCKER) run --rm -i \
		-v $(ROOT)/tool/release:/release:ro -v $(APP)/build:/out -v realchord-release-pub-cache:/root/.pub-cache \
		-e HOST_UID=$$(id -u) -e HOST_GID=$$(id -g) \
		$(RELEASE_IMAGE) /release/build-linux.sh $(RELEASE_NAME)-linux-x64
	@echo "Linux release: $(APP)/build/$(RELEASE_NAME)-linux-x64.tar.gz"

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
		REALCHORD_PUBLIC_DIR=$(APP)/build/web \
		$$pb serve --dir $(DATA_DIR)/pb_data --hooksDir $(ROOT)/server/pb_hooks \
			--migrationsDir $(ROOT)/server/pb_migrations --http 127.0.0.1:$(BACKEND_PORT) \
			--publicDir $(APP)/build/web

web: ## Build the web client into app/build/web (ADR-0018)
	$(ROOT)/tool/build-web.sh

web-serve: web ## Build the web client and serve it with the local backend (make backend)
	$(MAKE) backend

deps: ## Check that all external libraries are the newest versions
	$(ROOT)/tool/check-deps.sh

upgrade: ## Upgrade all external libraries within their constraints
	cd $(PACKAGE) && $(DART) pub upgrade
	cd $(ROOT)/server && $(DART) pub upgrade
	cd $(APP) && $(FLUTTER) pub upgrade
	$(ROOT)/tool/check-deps.sh

check: ## Run all checks (dependencies, format, analysis, l10n, tests, web build) – the test gate
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

server-install: server-target web ## Install or update the server (PocketBase PB_VERSION, hooks, migrations, web client)
	tar -C $(ROOT) --transform 's,^app/build/web,web,' -czf - \
		tool/server server/pb_hooks server/pb_migrations app/build/web | \
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
