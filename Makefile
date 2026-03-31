# mozilla/readability commit hash
READABILITY_COMMIT := 08be6b4bdb204dd333c9b7a0cfbc0e730b257252
TARGET_COMMIT := readability/.git/_target_commit/$(READABILITY_COMMIT)

# Source files
LIB_SOURCES := $(shell find lib -name '*.dart' 2>/dev/null)
CLI_SOURCE := bin/cli.dart
JS_SOURCE := lib/src/readability_js.dart

# Build outputs
BUILD_DIR := build
CLI_BINARY := $(BUILD_DIR)/readability
JS_BUNDLE := $(BUILD_DIR)/readability.js
WASM_BUNDLE := $(BUILD_DIR)/readability.wasm
JS_TAR := $(BUILD_DIR)/readability-js.tar.gz
WASM_TAR := $(BUILD_DIR)/readability-wasm.tar.gz
JS_TYPES := $(BUILD_DIR)/readability.d.ts

.PHONY: all get lint fix clean help ci coverage test-unit test-e2e run-example bump-version changelog

all: lint test-unit ## Run lint and tests (default)

get: pubspec.lock ## Install Dart dependencies

pubspec.lock: pubspec.yaml
	dart pub get
	@touch $@

test-unit: get ## Run unit tests
	dart test test/unit/*.dart

test-e2e: get $(TARGET_COMMIT) readability/node_modules/jsdom ## Run e2e tests (requires Node.js)
	dart test test/e2e/*.dart

lint: get ## Check formatting and analyze code
	dart format --set-exit-if-changed .
	dart analyze

fix: get ## Auto-fix lint issues and format code
	dart fix --apply
	dart format .

# Build CLI binary (depends on source files)
$(CLI_BINARY): get $(CLI_SOURCE) $(LIB_SOURCES) | $(BUILD_DIR)
	dart compile exe $(CLI_SOURCE) -o $@

# Build CLI binary with custom suffix (e.g., make build/readability-x212)
$(CLI_BINARY)_%: get $(CLI_SOURCE) $(LIB_SOURCES) | $(BUILD_DIR)
	dart compile exe $(CLI_SOURCE) -o $@

# Build JS bundle (depends on source files)
$(JS_BUNDLE): get $(JS_SOURCE) $(LIB_SOURCES) | $(BUILD_DIR)
	dart compile js $(JS_SOURCE) -o $@

# Build WASM bundle (depends on source files, experimental)
$(WASM_BUNDLE): get $(JS_SOURCE) $(LIB_SOURCES) | $(BUILD_DIR)
	dart compile wasm $(JS_SOURCE) -o $@

$(BUILD_DIR):
	mkdir -p $@

build-cli: $(CLI_BINARY) ## Compile CLI to native executable

build-js: $(JS_BUNDLE) ## Compile to JavaScript

build-wasm: $(WASM_BUNDLE) ## Compile to WebAssembly

# Create JS distribution archive
$(JS_TAR): $(JS_BUNDLE) $(JS_TYPES)
	tar -czf $@ -C $(BUILD_DIR) readability.js readability.d.ts

# Create WASM distribution archive
$(WASM_TAR): $(WASM_BUNDLE) $(JS_TYPES)
	tar -czf $@ -C $(BUILD_DIR) readability.wasm readability.mjs readability.support.js readability.d.ts

# Copies Types file for JS to build dir
$(JS_TYPES): readability.d.ts
	cp -f readability.d.ts $(JS_TYPES)

dist-js: $(JS_TAR) ## Create JS distribution archive

dist-wasm: $(WASM_TAR) ## Create WASM distribution archive

build-all: $(CLI_BINARY) $(JS_BUNDLE) $(WASM_BUNDLE) ## Build everything

clean: ## Remove build artifacts
	rm -rf $(BUILD_DIR)/
	rm -rf .dart_tool/
	rm -rf readability/

run-example: get ## Run the example
	dart run example/readability_example.dart

ci: lint test-unit ## Full CI check (lint + test)

# Clone mozilla/readability at specific commit
$(TARGET_COMMIT):
	rm -rf readability
	git clone https://github.com/mozilla/readability.git readability
	cd readability && git checkout --quiet $(READABILITY_COMMIT)
	mkdir -p readability/.git/_target_commit
	touch $(TARGET_COMMIT)

# Install jsdom for JS parity tests
readability/node_modules/jsdom: $(TARGET_COMMIT)
	cd readability && npm install jsdom

coverage: get ## Generate code coverage report
	dart pub global activate coverage
	dart test --coverage=coverage/lcov.info
	dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.dart_tool/package_config.json --report-on=lib
	@echo "Coverage report generated in coverage/lcov.info"
	@echo "View with: genhtml coverage/lcov.info -o coverage/html"
	@echo "Or use: lcov --summary coverage/lcov.info"

help: ## Show this help message
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-15s %s\n", $$1, $$2}'

# Version management
bump-version: ## Bump version (BUMP=patch|minor|major)
	@if [ -z "$(BUMP)" ]; then echo "Usage: make bump-version BUMP=patch|minor|major"; exit 1; fi
	@CURRENT=$$(grep '^version:' pubspec.yaml | sed 's/version: //'); \
	MAJOR=$$(echo $$CURRENT | cut -d. -f1); \
	MINOR=$$(echo $$CURRENT | cut -d. -f2); \
	PATCH=$$(echo $$CURRENT | cut -d. -f3); \
	case "$(BUMP)" in \
		major) MAJOR=$$((MAJOR + 1)); MINOR=0; PATCH=0 ;; \
		minor) MINOR=$$((MINOR + 1)); PATCH=0 ;; \
		patch) PATCH=$$((PATCH + 1)) ;; \
		*) echo "Invalid BUMP type: $(BUMP)"; exit 1 ;; \
	esac; \
	VERSION="$$MAJOR.$$MINOR.$$PATCH"; \
	sed "s/^version: .*/version: $$VERSION/" pubspec.yaml > pubspec.yaml.tmp && mv pubspec.yaml.tmp pubspec.yaml; \
	echo "$$VERSION"

changelog: ## Generate full changelog from git history
	@echo "# Changelog"; \
	echo ""; \
	set -- $$(git tag --sort=-v:refname); \
	while [ $$# -gt 0 ]; do \
		TAG=$$1; shift; \
		NEXT=$$1; \
		VERSION=$${TAG#v}; \
		if [ -z "$$NEXT" ]; then \
			COMMITS=$$(git log --pretty=format:"- %s" "$$TAG" --no-merges); \
		else \
			COMMITS=$$(git log --pretty=format:"- %s" "$$NEXT..$$TAG" --no-merges); \
		fi; \
		if [ -n "$$COMMITS" ]; then \
			echo "## $$VERSION"; \
			echo ""; \
			echo "$$COMMITS"; \
			echo ""; \
		fi; \
	done
