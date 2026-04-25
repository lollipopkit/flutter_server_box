SHELL := /bin/bash

.DEFAULT_GOAL := help

FLUTTER ?= flutter
DART ?= dart
DEVICE ?=
TEST ?=
PLATFORM ?=
ENV_FILE ?=
XCARCHIVE_PATH ?=
APP_PATH ?=
DMG_PATH ?=
TAP_REPO_PATH ?=

.PHONY: help deps pub-get run run-device analyze test test-one coverage \
	gen gen-build gen-build-clean gen-l10n build build-android build-ios \
	build-macos build-linux build-windows clean release-macos-dmg package-dmg \
	sync-homebrew-cask

help:
	@printf '%s\n' \
		'Usage: make <target> [VAR=value]' \
		'' \
		'Common targets:' \
		'  deps               Install Dart/Flutter dependencies' \
		'  run                Run app on default device' \
		'  run-device         Run app on a specific device: make run-device DEVICE=<id>' \
		'  analyze            Run static analysis for lib/ and test/' \
		'  test               Run all tests' \
		'  test-one           Run a single test: make test-one TEST=test/foo_test.dart' \
		'  coverage           Run tests with coverage output' \
		'' \
		'Code generation:' \
		'  gen                Run build_runner and gen-l10n' \
		'  gen-build          Run build_runner build --delete-conflicting-outputs' \
		'  gen-build-clean    Run build_runner build with --clean' \
		'  gen-l10n           Regenerate localization files' \
		'' \
		'Build targets:' \
		'  build              Build via fl_build: make build PLATFORM=<android|ios|macos|linux|windows>' \
		'  build-android      Build Android package' \
		'  build-ios          Build iOS package' \
		'  build-macos        Build macOS package' \
		'  build-linux        Build Linux package' \
		'  build-windows      Build Windows package' \
		'  clean              Run flutter clean' \
		'' \
		'Release scripts:' \
		'  release-macos-dmg  Run scripts/release/release-macos-dmg.sh' \
		'                     Optional: make release-macos-dmg ENV_FILE=.env.release' \
		'  package-dmg        Run scripts/release/package-dmg-from-xcarchive.sh' \
		'                     Example: make package-dmg APP_PATH="/path/Server Box.app"' \
		'                     Example: make package-dmg XCARCHIVE_PATH=/path/Runner.xcarchive' \
		'  sync-homebrew-cask Generate ~/proj/homebrew-taps/Casks/server-box.rb from a built DMG' \
		'                     Example: make sync-homebrew-cask APP_PATH="/path/Server Box.app"' \
		'                     Example: make sync-homebrew-cask XCARCHIVE_PATH=/path/Runner.xcarchive' \
		'                     Example: make sync-homebrew-cask DMG_PATH=build/artifacts/ServerBox-1.0.1.dmg'

deps pub-get:
	$(FLUTTER) pub get

run:
	$(FLUTTER) run

run-device:
	@if [ -z "$(DEVICE)" ]; then \
		echo 'DEVICE is required. Example: make run-device DEVICE=<id>'; \
		exit 1; \
	fi
	$(FLUTTER) run -d $(DEVICE)

analyze:
	$(FLUTTER) analyze lib test

test:
	$(FLUTTER) test

test-one:
	@if [ -z "$(TEST)" ]; then \
		echo 'TEST is required. Example: make test-one TEST=test/cpu_test.dart'; \
		exit 1; \
	fi
	$(FLUTTER) test $(TEST)

coverage:
	$(FLUTTER) test --coverage

gen: gen-build gen-l10n

gen-build:
	$(DART) run build_runner build --delete-conflicting-outputs

gen-build-clean:
	$(DART) run build_runner build --delete-conflicting-outputs --clean

gen-l10n:
	$(FLUTTER) gen-l10n

build:
	@if [ -z "$(PLATFORM)" ]; then \
		echo 'PLATFORM is required. Example: make build PLATFORM=android'; \
		exit 1; \
	fi
	$(DART) run fl_build -p $(PLATFORM)

build-android:
	$(DART) run fl_build -p android

build-ios:
	$(DART) run fl_build -p ios

build-macos:
	$(DART) run fl_build -p macos

build-linux:
	$(DART) run fl_build -p linux

build-windows:
	$(DART) run fl_build -p windows

clean:
	$(FLUTTER) clean

release-macos-dmg:
	@if [ -n "$(ENV_FILE)" ]; then \
		SERVERBOX_RELEASE_ENV_FILE="$(ENV_FILE)" bash scripts/release/release-macos-dmg.sh; \
	else \
		bash scripts/release/release-macos-dmg.sh; \
	fi

package-dmg:
	@if [ -z "$(APP_PATH)" ] && [ -z "$(XCARCHIVE_PATH)" ]; then \
		echo 'APP_PATH or XCARCHIVE_PATH is required.'; \
		echo 'Example: make package-dmg APP_PATH="/path/Server Box.app"'; \
		echo 'Example: make package-dmg XCARCHIVE_PATH=/path/Runner.xcarchive'; \
		exit 1; \
	fi
	@if [ -n "$(APP_PATH)" ]; then \
		APP_PATH="$(APP_PATH)" bash scripts/release/package-dmg-from-xcarchive.sh; \
	else \
		XCARCHIVE_PATH="$(XCARCHIVE_PATH)" bash scripts/release/package-dmg-from-xcarchive.sh; \
	fi

sync-homebrew-cask:
	@if [ -z "$(APP_PATH)" ] && [ -z "$(XCARCHIVE_PATH)" ] && [ -z "$(DMG_PATH)" ]; then \
		echo 'APP_PATH, XCARCHIVE_PATH, or DMG_PATH is required.'; \
		echo 'Example: make sync-homebrew-cask APP_PATH="/path/Server Box.app"'; \
		echo 'Example: make sync-homebrew-cask XCARCHIVE_PATH=/path/Runner.xcarchive'; \
		echo 'Example: make sync-homebrew-cask DMG_PATH=build/artifacts/ServerBox-1.0.1.dmg'; \
		exit 1; \
	fi
	@if [ -n "$(APP_PATH)" ]; then \
		APP_PATH="$(APP_PATH)" DMG_PATH="$(DMG_PATH)" TAP_REPO_PATH="$(TAP_REPO_PATH)" bash scripts/release/sync-homebrew-cask.sh; \
	elif [ -n "$(XCARCHIVE_PATH)" ]; then \
		XCARCHIVE_PATH="$(XCARCHIVE_PATH)" DMG_PATH="$(DMG_PATH)" TAP_REPO_PATH="$(TAP_REPO_PATH)" bash scripts/release/sync-homebrew-cask.sh; \
	else \
		DMG_PATH="$(DMG_PATH)" TAP_REPO_PATH="$(TAP_REPO_PATH)" bash scripts/release/sync-homebrew-cask.sh; \
	fi
