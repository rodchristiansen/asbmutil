#!/usr/bin/make -f
#
# ASBMUtil Build System
# Builds, signs, and notarizes CLI + GUI app
#

# Load environment variables from .env file if it exists
-include .env
export

# Version from environment or generate timestamp
VERSION := $(or $(VERSION),$(shell date '+%Y.%m.%d.%H%M'))
MARKETING_VERSION := $(shell echo $(VERSION) | sed 's/\.[^.]*$$//')
BUILD_NUMBER := $(shell echo $(VERSION) | sed 's/.*\.//')

# Paths
DIST_DIR = dist
BUILD_ARTIFACTS = build
CLI_NAME = asbmutil
APP_NAME = ASBMUtilApp
HELPER_NAME = ASBMUtilHelper
APP_BUNDLE = ASBMUtil.app
SWIFT_BUILD_DIR = .build/release
SWIFT_CLI = $(SWIFT_BUILD_DIR)/$(CLI_NAME)
SWIFT_APP = $(SWIFT_BUILD_DIR)/$(APP_NAME)
SWIFT_HELPER = $(SWIFT_BUILD_DIR)/$(HELPER_NAME)
VERSION_FILE = Sources/core/Utilities/Version.swift

# App bundle paths
APP_BUNDLE_PATH = $(DIST_DIR)/$(APP_BUNDLE)
APP_CONTENTS = $(APP_BUNDLE_PATH)/Contents
APP_MACOS = $(APP_CONTENTS)/MacOS
APP_RESOURCES = $(APP_CONTENTS)/Resources
APP_LAUNCHDAEMONS = $(APP_CONTENTS)/Library/LaunchDaemons

# Icon
ICON_DIR = resources/ASBMUtil.icon
ICON_NAME = ASBMUtil
ACTOOL_OUT = $(BUILD_ARTIFACTS)/actool-out

# Packaging
PKG_STAGING = $(DIST_DIR)/pkg-staging
PKG_NAME = ASBMUtil-$(VERSION).pkg
DMG_NAME = ASBMUtil-$(VERSION).dmg
CLI_ZIP_NAME = asbmutil-$(VERSION)-macos-arm64.zip
PKG_PATH = $(DIST_DIR)/$(PKG_NAME)
DMG_PATH = $(DIST_DIR)/$(DMG_NAME)
CLI_ZIP_PATH = $(DIST_DIR)/$(CLI_ZIP_NAME)
PKG_SCRIPTS_DIR = scripts

# Install paths
CLI_INSTALL_PATH = /usr/local/bin/$(CLI_NAME)
APP_INSTALL_PATH = /Applications/$(APP_BUNDLE)

# Signing (from .env)
ENTITLEMENTS = entitlements.plist

# Colors
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m

.PHONY: all build build-unsigned clean swift-build compile-icon sign-binaries create-app-bundle sign-app notarize verify install create-pkg create-dmg create-cli-zip help check-signing-config

all: build

help:
	@echo "ASBMUtil Build System"
	@echo ""
	@echo "Targets:"
	@echo "  build             - Build, sign, and notarize (default)"
	@echo "  swift-build       - Compile Swift binaries only"
	@echo "  compile-icon      - Compile icon with actool"
	@echo "  create-app-bundle - Create GUI app bundle"
	@echo "  sign-app          - Sign the app bundle"
	@echo "  notarize          - Notarize and staple"
	@echo "  verify            - Verify signature and notarization"
	@echo "  install           - Install CLI and App"
	@echo "  build-unsigned    - Build all unsigned artifacts (.app, .pkg, .dmg, .zip)"
	@echo "  create-pkg        - Create .pkg installer"
	@echo "  create-dmg        - Create .dmg disk image"
	@echo "  create-cli-zip    - Create CLI-only .zip"
	@echo "  clean             - Remove build artifacts"
	@echo ""
	@echo "Configuration:"
	@echo "  Create a .env file with your signing credentials"
	@echo ""
	@echo "Required Variables (set in .env or environment):"
	@echo "  SIGNING_IDENTITY_APP    - Developer ID Application cert"
	@echo "  SIGNING_IDENTITY_PKG    - Developer ID Installer cert (optional)"
	@echo "  NOTARIZATION_PROFILE    - Notarytool profile name"
	@echo "  NOTARIZATION_TEAM_ID    - Apple Developer Team ID"
	@echo ""
	@echo "Optional Variables:"
	@echo "  VERSION                 - Build version (default: timestamp)"

check-signing-config:
	@if [ -z "$(SIGNING_IDENTITY_APP)" ]; then \
		echo "$(RED)Error: SIGNING_IDENTITY_APP not set$(NC)"; \
		echo "$(YELLOW)Create a .env file with your signing credentials$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(NOTARIZATION_PROFILE)" ]; then \
		echo "$(RED)Error: NOTARIZATION_PROFILE not set$(NC)"; \
		echo "$(YELLOW)Create a .env file with your signing credentials$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Signing configuration validated$(NC)"

build: check-signing-config swift-build compile-icon sign-binaries create-app-bundle sign-app notarize verify
	@echo "$(GREEN)Build complete: $(APP_BUNDLE_PATH)$(NC)"

swift-build:
	@echo "$(BLUE)Generating version $(VERSION)...$(NC)"
	@echo "// This file is auto-generated during build" > $(VERSION_FILE)
	@echo "// Do not edit manually - changes will be overwritten" >> $(VERSION_FILE)
	@echo "" >> $(VERSION_FILE)
	@echo "public enum AppVersion {" >> $(VERSION_FILE)
	@echo "    public static let version = \"$(VERSION)\"" >> $(VERSION_FILE)
	@echo "}" >> $(VERSION_FILE)
	@echo "$(BLUE)Building Swift binaries...$(NC)"
	swift build -c release
	@echo "$(GREEN)Swift build complete$(NC)"

compile-icon:
	@echo "$(BLUE)Compiling icon with actool...$(NC)"
	@mkdir -p $(ACTOOL_OUT)
	@if [ -d "$(ICON_DIR)" ] && [ -n "$$(ls $(ICON_DIR)/Assets/ 2>/dev/null)" ]; then \
		xcrun actool \
			--compile $(ACTOOL_OUT) \
			--platform macosx \
			--minimum-deployment-target 14.0 \
			--app-icon $(ICON_NAME) \
			--output-partial-info-plist $(ACTOOL_OUT)/partial-info.plist \
			--warnings --errors \
			$(ICON_DIR) > /dev/null && \
		echo "$(GREEN)Icon compiled: Assets.car + $(ICON_NAME).icns$(NC)"; \
	else \
		echo "$(YELLOW)No icon assets found in $(ICON_DIR)/Assets/ - skipping$(NC)"; \
	fi

sign-binaries: swift-build
	@echo "$(BLUE)Signing binaries...$(NC)"
	@codesign --force --sign "$(SIGNING_IDENTITY_APP)" \
		--options runtime --timestamp --entitlements $(ENTITLEMENTS) \
		--identifier com.github.rodchristiansen.asbmutil \
		$(SWIFT_CLI)
	@codesign --force --sign "$(SIGNING_IDENTITY_APP)" \
		--options runtime --timestamp --entitlements $(ENTITLEMENTS) \
		--identifier com.github.rodchristiansen.asbmutil.app \
		$(SWIFT_APP)
	@codesign --force --sign "$(SIGNING_IDENTITY_APP)" \
		--options runtime --timestamp --entitlements $(ENTITLEMENTS) \
		--identifier com.github.rodchristiansen.asbmutil.helper \
		$(SWIFT_HELPER)
	@echo "$(GREEN)Binaries signed$(NC)"

create-app-bundle: swift-build compile-icon
	@echo "$(BLUE)Creating app bundle...$(NC)"
	@rm -rf $(APP_BUNDLE_PATH)
	@mkdir -p $(APP_MACOS) $(APP_RESOURCES) $(APP_LAUNCHDAEMONS)
	@# Copy binaries
	@cp $(SWIFT_APP) $(APP_MACOS)/
	@cp $(SWIFT_HELPER) $(APP_MACOS)/
	@cp $(SWIFT_CLI) $(APP_MACOS)/
	@chmod 755 $(APP_MACOS)/*
	@# Create Info.plist
	@/usr/libexec/PlistBuddy -c "Clear dict" $(APP_CONTENTS)/Info.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(APP_NAME)" $(APP_CONTENTS)/Info.plist
	@/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.github.rodchristiansen.asbmutil" $(APP_CONTENTS)/Info.plist
	@/usr/libexec/PlistBuddy -c "Add :CFBundleName string ASBMUtil" $(APP_CONTENTS)/Info.plist
	@/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" $(APP_CONTENTS)/Info.plist
	@/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $(MARKETING_VERSION)" $(APP_CONTENTS)/Info.plist
	@/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $(BUILD_NUMBER)" $(APP_CONTENTS)/Info.plist
	@/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 14.0" $(APP_CONTENTS)/Info.plist
	@/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" $(APP_CONTENTS)/Info.plist
	@# Copy icon assets if compiled
	@if [ -f "$(ACTOOL_OUT)/Assets.car" ]; then \
		cp $(ACTOOL_OUT)/Assets.car $(APP_RESOURCES)/; \
		echo "  Copied Assets.car"; \
	fi
	@if [ -f "$(ACTOOL_OUT)/$(ICON_NAME).icns" ]; then \
		cp $(ACTOOL_OUT)/$(ICON_NAME).icns $(APP_RESOURCES)/; \
		/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $(ICON_NAME)" $(APP_CONTENTS)/Info.plist; \
		/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string $(ICON_NAME)" $(APP_CONTENTS)/Info.plist; \
		echo "  Copied $(ICON_NAME).icns"; \
	fi
	@# Helper LaunchDaemon plist
	@/usr/libexec/PlistBuddy -c "Clear dict" $(APP_LAUNCHDAEMONS)/com.github.rodchristiansen.asbmutil.helper.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :Label string com.github.rodchristiansen.asbmutil.helper" $(APP_LAUNCHDAEMONS)/com.github.rodchristiansen.asbmutil.helper.plist
	@/usr/libexec/PlistBuddy -c "Add :MachServices dict" $(APP_LAUNCHDAEMONS)/com.github.rodchristiansen.asbmutil.helper.plist
	@/usr/libexec/PlistBuddy -c "Add :MachServices:com.github.rodchristiansen.asbmutil.helper bool true" $(APP_LAUNCHDAEMONS)/com.github.rodchristiansen.asbmutil.helper.plist
	@echo "$(GREEN)App bundle created$(NC)"

sign-app: create-app-bundle
	@echo "$(BLUE)Signing app bundle...$(NC)"
	@codesign --force --sign "$(SIGNING_IDENTITY_APP)" \
		--options runtime --timestamp --deep \
		$(APP_BUNDLE_PATH)
	@echo "$(GREEN)App bundle signed$(NC)"

notarize: sign-app
	@echo "$(BLUE)Notarizing (this may take several minutes)...$(NC)"
	@rm -f $(DIST_DIR)/asbmutil-app.zip
	@ditto -c -k --keepParent $(APP_BUNDLE_PATH) $(DIST_DIR)/asbmutil-app.zip
	@xcrun notarytool submit $(DIST_DIR)/asbmutil-app.zip \
		--keychain-profile "$(NOTARIZATION_PROFILE)" \
		--wait
	@echo "$(BLUE)Stapling notarization ticket...$(NC)"
	@xcrun stapler staple $(APP_BUNDLE_PATH)
	@rm -f $(DIST_DIR)/asbmutil-app.zip
	@echo "$(GREEN)Notarization complete$(NC)"

verify: notarize
	@echo "$(BLUE)Verifying security...$(NC)"
	@codesign --verify --deep --verbose $(APP_BUNDLE_PATH) && echo "$(GREEN)App signature valid$(NC)" || echo "$(RED)App signature invalid$(NC)"
	@xcrun stapler validate $(APP_BUNDLE_PATH) && echo "$(GREEN)Notarization valid$(NC)" || echo "$(RED)Notarization invalid$(NC)"
	@spctl --assess --type execute $(APP_BUNDLE_PATH) && echo "$(GREEN)Gatekeeper approved$(NC)" || echo "$(YELLOW)Gatekeeper check skipped$(NC)"
	@echo "$(GREEN)Security checks complete$(NC)"

install:
	@echo "$(BLUE)Installing...$(NC)"
	@sudo cp $(SWIFT_CLI) $(CLI_INSTALL_PATH)
	@sudo chmod +x $(CLI_INSTALL_PATH)
	@echo "$(GREEN)CLI installed to $(CLI_INSTALL_PATH)$(NC)"
	@sudo rm -rf $(APP_INSTALL_PATH)
	@sudo cp -R $(APP_BUNDLE_PATH) $(APP_INSTALL_PATH)
	@echo "$(GREEN)App installed to $(APP_INSTALL_PATH)$(NC)"

clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_ARTIFACTS) $(DIST_DIR) || true
	@chmod -R u+w .build 2>/dev/null || true
	@rm -rf .build || true
	@echo "$(GREEN)Clean complete$(NC)"

build-unsigned: swift-build compile-icon create-app-bundle create-pkg create-dmg create-cli-zip
	@echo "$(GREEN)Unsigned build complete$(NC)"
	@echo "  $(APP_BUNDLE_PATH)"
	@echo "  $(PKG_PATH)"
	@echo "  $(DMG_PATH)"
	@echo "  $(CLI_ZIP_PATH)"

create-pkg: create-app-bundle
	@echo "$(BLUE)Creating installer package...$(NC)"
	@rm -rf $(PKG_STAGING)
	@mkdir -p $(PKG_STAGING) $(DIST_DIR)
	@cp -R $(APP_BUNDLE_PATH) $(PKG_STAGING)/
	@chmod +x $(PKG_SCRIPTS_DIR)/postinstall
	@pkgbuild \
		--root $(PKG_STAGING) \
		--install-location /Applications \
		--scripts $(PKG_SCRIPTS_DIR) \
		--identifier com.github.rodchristiansen.asbmutil.pkg \
		--version $(VERSION) \
		$(PKG_PATH)
	@rm -rf $(PKG_STAGING)
	@echo "$(GREEN)Package created: $(PKG_PATH)$(NC)"

create-dmg: create-app-bundle
	@echo "$(BLUE)Creating disk image...$(NC)"
	@mkdir -p $(DIST_DIR)
	@rm -f $(DMG_PATH)
	@hdiutil create \
		-volname "ASBMUtil" \
		-srcfolder $(APP_BUNDLE_PATH) \
		-ov \
		-format UDZO \
		$(DMG_PATH)
	@echo "$(GREEN)Disk image created: $(DMG_PATH)$(NC)"

create-cli-zip: swift-build
	@echo "$(BLUE)Creating CLI zip...$(NC)"
	@mkdir -p $(DIST_DIR)
	@rm -f $(CLI_ZIP_PATH)
	@zip -j $(CLI_ZIP_PATH) $(SWIFT_CLI)
	@echo "$(GREEN)CLI zip created: $(CLI_ZIP_PATH)$(NC)"
