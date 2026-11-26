# setDING – local development helpers (Linux).
#
# Test instances use their own data directory (DATA_DIR, default .dev-data/),
# so they never touch the data of a normally started app.
#
#   make            show this help
#   make dev        start a test instance with hot reload
#   make start      build and start a test instance (without Flutter tooling)
#   make reset      delete the test instance's data (fresh start with demo song)
#   make backend    start a local PocketBase with the repository's schema and hooks
#   make perf       measure performance on a USB-connected Android device
#   make android-test  run the Android integration tests (emulator, or DEVICE=<id>)
#   make web-test      run the web integration tests in headless Chrome (BROWSER=firefox)
#   make e2e           run the end-to-end tests: Linux desktop + web client against one backend
#   make coverage   measure the test coverage (report only, no threshold)
#   make apk        build an Android APK for manual installation (sideloading)
#   make android-install  install the local build as "setDING Beta" next to a release
#   make android-keystore  create the Android release key (owner, once)
#   make release    build the Linux release package (runs on any x86-64 Linux)
#   make sbom       build the Linux release with its CycloneDX SBOM and validate it
#   make changelog  draft the CHANGELOG.md section of the next release from the commits
#   make site       build the website and user documentation (website/, ADR-0030)
#   make server-*   install and operate the PocketBase server (SERVER=root@host or local.mk)

SHELL := /bin/bash
.DEFAULT_GOAL := help

ROOT     := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
APP      := $(ROOT)/app
PACKAGE  := $(ROOT)/packages/chordpro
DATA_DIR ?= $(ROOT)/.dev-data

# Flutter from PATH, otherwise from ~/development/flutter.
FLUTTER  ?= $(shell command -v flutter 2>/dev/null || echo $(HOME)/development/flutter/bin/flutter)
DART     := $(dir $(FLUTTER))dart

BUNDLE_DIR := $(APP)/build/linux/x64/debug/bundle
BUNDLE   := $(BUNDLE_DIR)/setding

# Android APK for sideloading (make apk). The release build is signed with the
# release key from app/android/key.properties if it exists, otherwise with the
# machine's debug key (app/android/app/build.gradle.kts, ADR-0021).
export ANDROID_HOME ?= $(HOME)/Android/Sdk
ADB         ?= $(ANDROID_HOME)/platform-tools/adb
APK_VERSION := $(shell sed -n 's/^version: *\([^+]*\).*/\1/p' $(APP)/pubspec.yaml)
APK_COMMIT  := $(shell git -C $(ROOT) rev-parse --short HEAD 2>/dev/null || echo unknown)
# Full commit of the Linux release build: archived and recorded in its SBOM.
RELEASE_COMMIT := $(shell git -C $(ROOT) rev-parse HEAD 2>/dev/null || echo unknown)
APK         := $(APP)/build/setding-$(APK_VERSION)-$(APK_COMMIT).apk
# Beta build (make android-install): own application ID app.setding.beta, so it is
# installed next to a release installation with its own data. DEVICE=<id> picks a
# device when several are connected; BETA_MODE=debug|profile|release.
BETA_MODE   ?= release
BETA_APK    := $(APP)/build/app/outputs/flutter-apk/app-$(BETA_MODE).apk
# Commit shown in the beta's version (Settings -> About), "-dirty" when the working
# tree has uncommitted changes, since the beta is built from the working tree.
BETA_COMMIT  = $(APK_COMMIT)$(shell git -C $(ROOT) diff --quiet HEAD 2>/dev/null || echo -dirty)

# Flutter version used for development; CI reads it from here
# (.github/workflows/ci.yml). CI_IMAGE (tool/ci/Dockerfile) is a local base image
# with Flutter on Debian for the Linux release build, tagged with that version.
FLUTTER_VERSION ?= 3.50.0
CI_IMAGE        ?= setding-ci:$(FLUTTER_VERSION)
DOCKER          ?= docker

# Linux release package (make release, ADR-0019), named after version and commit.
# Built in a Debian container (tool/release/linux.Dockerfile) so the result runs on
# every x86-64 CPU and distribution, not only on the machine that runs make.
# CI (ADR-0021) sets RELEASE_NAME without the commit and BUILD_NUMBER to its run number.
RELEASE_NAME  ?= setding-$(APK_VERSION)-$(APK_COMMIT)
RELEASE_IMAGE ?= setding-release-linux:$(FLUTTER_VERSION)
BUILD_NUMBER  ?=

# Android release key (make android-keystore, ADR-0021); never inside the repository.
ANDROID_KEYSTORE ?= $(HOME)/.local/share/setding/android-release.jks

# The owner's servers (ADR-0014, ADR-0063 §7, docs/operations/server.md), SSH
# targets without defaults, set in the git-ignored local.mk:
#   SERVER_PROD     production (api.setding.app)
#   SERVER_STAGING  test server (setding.dev)
#   SERVER_SITE     the website (setding.app)
# The make server-* targets pick one with TARGET=prod|staging (server-install
# defaults to staging, the others to prod). Non-root users need sudo without a
# password there. PB_VERSION is the pinned PocketBase version; updates are
# deliberate (ADR-0004).
-include $(ROOT)/local.mk
SERVER_PROD     ?=
SERVER_STAGING  ?=
SERVER_SITE     ?=
PB_VERSION      ?= 0.42.3
SSH             ?= ssh
SERVER_BACKUPS  := /var/lib/setding/pb_data/backups
BACKUP_DIR      ?= $(ROOT)/.server-backups
# Overridable for the tests of these targets (tool/test_server_targets.py).
SERVER_DEPLOY   ?= $(ROOT)/tool/server/deploy.sh
SERVER_RELEASE_DEPLOY ?= $(ROOT)/tool/release/deploy-server.sh
SITE_DEPLOY     ?= $(ROOT)/tool/site/deploy-site.sh
# The server a server-* target works on, and a remote prefix that runs a
# command as root: directly as root, else with sudo -n (`$$s command`).
T   = $(or $(TARGET),prod)
SRV = $(if $(filter staging,$(T)),$(SERVER_STAGING),$(if $(filter prod,$(T)),$(SERVER_PROD)))
AS_ROOT := s=$$([ "$$(id -u)" -eq 0 ] || echo "sudo -n");
# Local PocketBase (make backend); its data lives in DATA_DIR like the test instance.
BACKEND_PORT    ?= 8090
# Sign-up mode of the local backend (ADR-0024); open, so the app can create accounts.
BACKEND_REGISTRATION ?= open

# Redirects the app's private data to DATA_DIR: SETDING_DATA_DIR for the
# database and PDFs, XDG_DATA_HOME for the settings (shared_preferences).
TEST_ENV := SETDING_DATA_DIR=$(DATA_DIR)/app XDG_DATA_HOME=$(DATA_DIR)/xdg

.PHONY: help setup dev start build web web-serve site site-dev deps upgrade upgrade-guard apk android-install android-keystore release release-linux release-check sbom changelog reset data-dir backend check check-full release-gate test codegen l10n coverage android-test web-test e2e perf screenshots branding examples doctor clean ci-image \
	server-target server-bundle server-image server-install server-release server-site server-status server-logs server-backup server-fetch-backup server-founder-invite server-ssh

help: ## Show this help
	@echo "setDING – make targets"
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
	@! [ -x $(BUNDLE_DIR)/install-desktop-entry.sh ] || $(BUNDLE_DIR)/install-desktop-entry.sh --hidden --if-missing
	cd $(APP) && $(TEST_ENV) $(FLUTTER) run -d linux

start: build data-dir ## Build and start a test instance (debug build, no hot reload)
	@$(BUNDLE_DIR)/install-desktop-entry.sh --hidden --if-missing
	$(TEST_ENV) $(BUNDLE)

build: ## Build the Linux debug app
	cd $(APP) && $(FLUTTER) build linux --debug

apk: ## Build an Android release APK for manual installation (app/build/setding-<version>-<commit>.apk)
	@test -d "$(ANDROID_HOME)" || { echo "Android SDK not found. Install it or set ANDROID_HOME=/path/to/sdk"; exit 1; }
	cd $(APP) && $(FLUTTER) build apk --release
	cp $(APP)/build/app/outputs/flutter-apk/app-release.apk $(APK)
	@echo "APK: $(APK)"

android-install: ## Install the local build as "setDING Beta" (app.setding.beta) next to a release on a USB device (DEVICE=<id>)
	@test -d "$(ANDROID_HOME)" || { echo "Android SDK not found. Install it or set ANDROID_HOME=/path/to/sdk"; exit 1; }
	@$(ADB) $(if $(DEVICE),-s $(DEVICE)) get-state >/dev/null 2>&1 || { echo "No Android device connected (USB debugging on; DEVICE=<id> for several)"; exit 1; }
	cd $(APP) && SETDING_ANDROID_BETA=1 $(FLUTTER) build apk --$(BETA_MODE) --dart-define=SETDING_BUILD_COMMIT=$(BETA_COMMIT)
	$(ADB) $(if $(DEVICE),-s $(DEVICE)) install -r $(BETA_APK)
	$(ADB) $(if $(DEVICE),-s $(DEVICE)) shell monkey -p app.setding.beta -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

android-keystore: ## Create the Android release key and store it as GitHub secrets (owner only, once)
	$(ROOT)/tool/release/android-keystore.sh $(ANDROID_KEYSTORE)

release: release-linux ## Build the release packages locally (Linux; a vX.Y.Z tag builds all platforms in CI)

release-check:
	@git -C $(ROOT) diff --quiet HEAD || echo "warning: uncommitted changes are not part of the release (built from commit $(APK_COMMIT))"

release-linux: release-check ## Build the Linux release and its SBOMs in a container (app/build/setding-<version>-<commit>-linux-x64.tar.gz and .AppImage, each with .cdx.json)
	@$(DOCKER) image inspect $(CI_IMAGE) >/dev/null 2>&1 || $(MAKE) ci-image
	$(DOCKER) build -q --build-arg CI_IMAGE=$(CI_IMAGE) -t $(RELEASE_IMAGE) -f $(ROOT)/tool/release/linux.Dockerfile $(ROOT)/tool/release
	@mkdir -p $(APP)/build
	git -C $(ROOT) archive $(RELEASE_COMMIT) | $(DOCKER) run --rm -i \
		-v $(ROOT)/tool/release:/release:ro -v $(APP)/build:/out -v setding-release-pub-cache:/root/.pub-cache \
		-e HOST_UID=$$(id -u) -e HOST_GID=$$(id -g) -e BUILD_NUMBER=$(BUILD_NUMBER) \
		-e COMMIT=$(RELEASE_COMMIT) \
		$(RELEASE_IMAGE) /release/build-linux.sh $(RELEASE_NAME)-linux-x64
	@echo "Linux release: $(APP)/build/$(RELEASE_NAME)-linux-x64.tar.gz and .AppImage"
	@echo "SBOMs:         $(APP)/build/$(RELEASE_NAME)-linux-x64.{tar.gz,AppImage}.cdx.json"

sbom: release-linux ## Build the Linux release with its CycloneDX SBOMs and validate them (ADR-0037)
	$(ROOT)/tool/sbom/validate.sh $(APP)/build/$(RELEASE_NAME)-linux-x64.tar.gz.cdx.json \
		$(APP)/build/$(RELEASE_NAME)-linux-x64.AppImage.cdx.json

changelog: ## Draft the CHANGELOG.md section of the next release from the commits since the last tag
	@$(ROOT)/tool/release/changelog.py draft

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
		SETDING_PUBLIC_DIR=$(APP)/build/web SETDING_REGISTRATION=$(BACKEND_REGISTRATION) \
		SETDING_INVITE_KEY=local-development-key \
		$$pb serve --dir $(DATA_DIR)/pb_data --hooksDir $(ROOT)/server/pb_hooks \
			--migrationsDir $(ROOT)/server/pb_migrations --http 127.0.0.1:$(BACKEND_PORT) \
			--publicDir $(APP)/build/web

web: ## Build the web client into app/build/web (ADR-0018)
	$(ROOT)/tool/build-web.sh

web-serve: web ## Build the web client and serve it with the local backend (make backend)
	$(MAKE) backend

site: ## Build the website and user documentation into website/dist (ADR-0030)
	$(ROOT)/tool/build-site.sh

site-dev: ## Serve the website with live reload on http://localhost:4321 (docs/development/website.md)
	cd $(ROOT)/website && npm ci --no-audit --no-fund --loglevel=error && ASTRO_TELEMETRY_DISABLED=1 npx --no-install astro dev

deps: ## Check that all external libraries are the newest versions
	$(ROOT)/tool/check-deps.sh

upgrade-guard: ## Stop if another session already changes dependencies (worktrees, open PRs, issues; UPGRADE_FORCE=1 overrides)
	cd $(ROOT) && python3 tool/upgrade_guard.py

upgrade: upgrade-guard ## Upgrade all external libraries within their constraints (after upgrade-guard)
	cd $(PACKAGE) && $(DART) pub upgrade
	cd $(ROOT)/server && $(DART) pub upgrade
	cd $(ROOT)/tool/sbom && $(DART) pub upgrade
	cd $(APP) && $(FLUTTER) pub upgrade
	cd $(ROOT)/website && npm update --no-audit --no-fund
	$(ROOT)/tool/check-deps.sh

check: ## The test gate: the checks (dependencies, format, analysis, l10n, tests, web build, website) of the areas the branch changes
	$(ROOT)/tool/check.sh

check-full: ## Run every check regardless of the changed files (larger changes; dependency check fatal)
	CHECK_FULL=1 $(ROOT)/tool/check.sh

release-gate: ## Before a release: every check, the server release test (bundle, image, update), then the web (Chrome and Firefox), end-to-end and Android integration tests (docs/development/releases.md)
	CHECK_FULL=1 $(ROOT)/tool/check.sh
	$(ROOT)/tool/server-dist/release-test.sh
	$(ROOT)/tool/web-test.sh
	BROWSER=firefox $(ROOT)/tool/web-test.sh
	$(ROOT)/tool/e2e-test.sh
	$(ROOT)/tool/android-test.sh

test: ## Run all tests
	cd $(PACKAGE) && $(DART) test
	cd $(ROOT)/server && $(DART) test
	cd $(APP) && $(FLUTTER) test

coverage: ## Measure the test coverage of the app and the ChordPro package, report only (docs/development/coverage.md)
	$(ROOT)/tool/coverage/coverage.sh

codegen: ## Regenerate the drift database code
	cd $(APP) && $(DART) run build_runner build

l10n: ## Regenerate the translations from the ARB files
	cd $(APP) && $(FLUTTER) gen-l10n

android-test: ## Run the Android integration tests on an own emulator, or on a USB device with DEVICE=<id> (docs/development/android-tests.md)
	$(ROOT)/tool/android-test.sh

web-test: ## Run the web integration tests in headless Chrome (or BROWSER=firefox) against a local PocketBase (docs/development/web-tests.md)
	$(ROOT)/tool/web-test.sh

e2e: ## Run the end-to-end tests: Linux desktop and web client at the same time against one local PocketBase (STORIES=…, BROWSER=firefox; docs/development/e2e-tests.md)
	$(ROOT)/tool/e2e-test.sh

perf: ## Measure performance on a USB-connected Android device (DEVICE=<id>; docs/development/performance.md)
	$(ROOT)/tool/perf.sh

screenshots: ## Render screenshots with real fonts to app/build/screenshots/ and copy those of the README and website to docs/screenshots/ (ONLY="<test name regex>": only the matching tests, for a PR; all of them in the release PR)
	rm -rf $(APP)/build/screenshots
	cd $(APP) && $(FLUTTER) test test_screenshots --dart-define=WRITE_SCREENSHOTS=true $(if $(ONLY),--name '$(ONLY)')
	@echo "Screenshots: $(APP)/build/screenshots/"
	$(ROOT)/tool/copy-screenshots.sh $(if $(ONLY),--partial)

branding: ## Regenerate the splash screens, favicon and web icons from app/branding/*.svg
	$(ROOT)/tool/branding.sh

examples: ## Rebuild the example ZIPs and song archives in docs/examples from the example files
	cd $(ROOT)/docs/examples && rm -f feature-showcase.zip && \
		python3 -c "import zipfile; z = zipfile.ZipFile('feature-showcase.zip', 'w', zipfile.ZIP_DEFLATED); [z.write(f) for f in ('feature-showcase.cho', 'stage-plan.svg')]; z.close()"
	@echo "Updated docs/examples/feature-showcase.zip"
	cd $(ROOT)/docs/examples/nord-test && rm -f ../nord-test.zip && \
		python3 -c "import glob, zipfile; z = zipfile.ZipFile('../nord-test.zip', 'w', zipfile.ZIP_DEFLATED); [z.write(f) for f in sorted(glob.glob('*.cho'))]; z.close()"
	@echo "Updated docs/examples/nord-test.zip"
	cd $(APP) && $(FLUTTER) test test/doc_examples_archive_test.dart --dart-define=WRITE_EXAMPLES=true
	@echo "Updated the song archives docs/examples/*.setDING.zip"

doctor: ## Show the state of the Flutter toolchain
	$(FLUTTER) doctor

clean: ## Remove build output (keeps test data; see 'make reset')
	cd $(APP) && $(FLUTTER) clean

ci-image: ## Build the Flutter base image of the release build (tool/ci/Dockerfile)
	$(DOCKER) build --build-arg FLUTTER_VERSION=$(FLUTTER_VERSION) -t $(CI_IMAGE) $(ROOT)/tool/ci

server-target:
	@test -z "$(SERVER)$(SITE_SERVER)" || { echo "SERVER and SITE_SERVER were renamed: set SERVER_PROD, SERVER_STAGING and SERVER_SITE in local.mk (docs/operations/server.md)"; exit 1; }
	@case "$(T)" in prod | staging) ;; *) echo "TARGET must be prod or staging, not '$(T)'"; exit 1 ;; esac
	@test -n "$(SRV)" || { echo "Set SERVER_$(if $(filter staging,$(T)),STAGING,PROD) to the SSH target in local.mk (docs/operations/server.md)"; exit 1; }

server-install: T = $(or $(TARGET),staging)
server-install: server-target ## Install the server built from the working tree on the test server (TARGET=staging, default; TARGET=prod FORCE=1 only in an emergency)
	@test "$(T)" != prod || test "$(FORCE)" = 1 || { echo "Production gets releases only (make server-release); TARGET=prod FORCE=1 only in an emergency"; exit 1; }
	@SERVER=$(SRV) SSH="$(SSH)" $(SERVER_DEPLOY)

server-release: server-target ## After a release: wait for its green build, then install its published bundle (VERSION=x.y.z, default newest; TARGET=prod, default, or staging)
	@SERVER=$(SRV) SSH="$(SSH)" $(SERVER_RELEASE_DEPLOY) $(VERSION)

server-bundle: ## Build the server bundle setding-server-<version>-linux-<arch>.tar.gz and SHA256SUMS into build/server-dist (ARCH=amd64|arm64, WEB_DIR=<web build>; ADR-0063)
	@ARCH=$(ARCH) WEB_DIR=$(WEB_DIR) PB_VERSION=$(PB_VERSION) $(ROOT)/tool/server-dist/build-bundle.sh

server-image: ## Build the Docker image of the server from a bundle (BUNDLE=<.tar.gz>, default built now; IMAGE=<name:tag>; ADR-0063)
	@BUNDLE=$(BUNDLE) IMAGE=$(IMAGE) ARCH=$(ARCH) WEB_DIR=$(WEB_DIR) PB_VERSION=$(PB_VERSION) $(ROOT)/tool/server-dist/build-image.sh

server-site: ## Build and deploy the website to SERVER_SITE, from the working tree or the release tag (VERSION=x.y.z; ADR-0030)
	@test -z "$(SERVER)$(SITE_SERVER)" || { echo "SERVER and SITE_SERVER were renamed: set SERVER_PROD, SERVER_STAGING and SERVER_SITE in local.mk (docs/operations/server.md)"; exit 1; }
	@test -n "$(SERVER_SITE)" || { echo "Set SERVER_SITE to the website server's SSH target in local.mk"; exit 1; }
	@SERVER_SITE=$(SERVER_SITE) SSH="$(SSH)" $(SITE_DEPLOY) $(VERSION)

server-status: server-target ## Show the services, version, health, latest backups and disk of the server (TARGET=prod|staging)
	@$(SSH) $(SRV) '$(AS_ROOT) $$s systemctl --no-pager --lines=0 status setding cloudflared || true; \
		echo; echo "setDING $$(cat /opt/setding/current/VERSION)"; curl -fsS http://127.0.0.1:8090/api/health; echo; \
		echo; echo "Backups:"; $$s ls -lht $(SERVER_BACKUPS) | head -n 6; echo; df -h /'

server-logs: server-target ## Follow the setDING and tunnel logs of the server (Ctrl+C to stop; TARGET=prod|staging)
	$(SSH) -t $(SRV) '$(AS_ROOT) $$s journalctl -u setding -u cloudflared -n 100 -f'

server-backup: server-target ## Create a backup on the server now (TARGET=prod|staging)
	$(SSH) $(SRV) '$(AS_ROOT) $$s /usr/local/bin/setding-backup-now'

server-fetch-backup: server-target ## Copy the latest backup of the server to BACKUP_DIR (off-host copy; TARGET=prod|staging)
	@mkdir -p "$(BACKUP_DIR)"
	@latest=$$($(SSH) $(SRV) '$(AS_ROOT) $$s sh -c "ls -1t $(SERVER_BACKUPS)/*.zip 2>/dev/null | head -n 1"'); \
		test -n "$$latest" || { echo "No backup on the server yet"; exit 1; }; \
		printf '%s' "$$latest" | $(SSH) $(SRV) '$(AS_ROOT) p=$$(cat); $$s cat "$$p"' >"$(BACKUP_DIR)/$(T)-$$(basename $$latest)"; \
		echo "Saved $(BACKUP_DIR)/$(T)-$$(basename $$latest)"

server-founder-invite: server-target ## Create a one-time link that founds an organization (NAME="…", ADR-0024; TARGET=prod|staging)
	@test -n "$(NAME)" || { echo 'Set NAME, e.g. make server-founder-invite NAME="Music school"'; exit 1; }
	@printf '%s' "$(NAME)" | $(SSH) $(SRV) '$(AS_ROOT) n=$$(cat); $$s /usr/local/bin/setding founder-invite "$$n" 2>&1' | \
		grep -o '{"id".*}' || { echo "Creating the founder invitation failed"; exit 1; }

server-ssh: server-target ## Open a shell on the server (TARGET=prod|staging)
	$(SSH) $(SRV)
