.PHONY: all build sign notarize install clean help

# Configuration
BINARY_NAME = asbmutil
BUILD_DIR = .build/release
BINARY_PATH = $(BUILD_DIR)/$(BINARY_NAME)
ZIP_FILE = $(BINARY_NAME).zip
INSTALL_PATH = /usr/local/bin/$(BINARY_NAME)
VERSION_FILE = Sources/asbmutil/Version.swift

# Generate version in YYYY.MM.DD.HHMM format
VERSION := $(shell date +'%Y.%m.%d.%H%M')

# Load environment variables from .env if it exists
-include .env
export

# Code signing - provide it via environment variables or command line
# Example: make release SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" TEAM_ID=YOURTEAMID
SIGNING_IDENTITY ?= $(APPLE_SIGNING_IDENTITY)
TEAM_ID ?= $(APPLE_TEAM_ID)
ENTITLEMENTS = entitlements.plist
NOTARY_PROFILE ?= $(APPLE_NOTARY_PROFILE)
NOTARY_PROFILE ?= notarization_credentials

# Colors
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m

all: help

help:
	@echo "$(GREEN)asbmutil Build Targets:$(NC)"
	@echo "  $(YELLOW)build$(NC)          - Build release binary"
	@echo "  $(YELLOW)sign$(NC)           - Sign the binary (requires SIGNING_IDENTITY)"
	@echo "  $(YELLOW)notarize$(NC)       - Submit for notarization (requires TEAM_ID)"
	@echo "  $(YELLOW)install$(NC)        - Install to $(INSTALL_PATH)"
	@echo "  $(YELLOW)release$(NC)        - Build, sign, notarize, and install"
	@echo "  $(YELLOW)clean$(NC)          - Remove build artifacts"
	@echo "  $(YELLOW)setup-notary$(NC)   - Instructions for notarization setup"
	@echo ""
	@echo "$(GREEN)Required Environment Variables (set in .env or command line):$(NC)"
	@echo "  $(YELLOW)SIGNING_IDENTITY$(NC) or $(YELLOW)APPLE_SIGNING_IDENTITY$(NC)"
	@echo "    - Your Apple Developer ID certificate name"
	@echo "    - Example: 'Developer ID Application: Your Name (TEAMID)'"
	@echo "  $(YELLOW)TEAM_ID$(NC) or $(YELLOW)APPLE_TEAM_ID$(NC)"
	@echo "    - Your Apple Developer Team ID"
	@echo "  $(YELLOW)NOTARY_PROFILE$(NC) or $(YELLOW)APPLE_NOTARY_PROFILE$(NC)"
	@echo "    - Keychain profile name (default: notarization_credentials)"
	@echo ""
	@echo "$(GREEN)Setup:$(NC)"
	@echo "  1. Copy .env.example to .env and fill in your values"
	@echo "  2. Run: $(YELLOW)make setup-notary$(NC) to configure notarization"
	@echo "  3. Run: $(YELLOW)make release$(NC) to build and install"
	@echo ""
	@echo "$(GREEN)Or use command line:$(NC)"
	@echo "  make release SIGNING_IDENTITY='...' TEAM_ID=... NOTARY_PROFILE=..."

build:
	@echo "$(GREEN)Generating version $(VERSION)...$(NC)"
	@echo "// This file is auto-generated during build" > $(VERSION_FILE)
	@echo "// Do not edit manually - changes will be overwritten" >> $(VERSION_FILE)
	@echo "" >> $(VERSION_FILE)
	@echo "enum AppVersion {" >> $(VERSION_FILE)
	@echo "    static let version = \"$(VERSION)\"" >> $(VERSION_FILE)
	@echo "}" >> $(VERSION_FILE)
	@echo "$(GREEN)Building $(BINARY_NAME) version $(VERSION)...$(NC)"
	swift build -c release
	@echo "$(GREEN)✓ Build complete$(NC)"

sign: build
	@echo "$(GREEN)Signing binary...$(NC)"
	@if [ -z "$(SIGNING_IDENTITY)" ]; then \
		echo "$(RED)Error: SIGNING_IDENTITY not set!$(NC)"; \
		echo "$(YELLOW)Set it via .env file or command line:$(NC)"; \
		echo "  make sign SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'"; \
		exit 1; \
	fi
	codesign --force --options runtime \
		--sign $(SIGNING_IDENTITY) \
		--entitlements $(ENTITLEMENTS) \
		--timestamp \
		$(BINARY_PATH)
	@echo "$(GREEN)Verifying signature...$(NC)"
	codesign --verify --verbose $(BINARY_PATH)
	@echo "$(GREEN)✓ Signature complete$(NC)"

notarize: sign
	@echo "$(GREEN)Creating zip for notarization...$(NC)"
	@if [ -z "$(TEAM_ID)" ]; then \
		echo "$(RED)Error: TEAM_ID not set!$(NC)"; \
		echo "$(YELLOW)Set it via .env file or command line:$(NC)"; \
		echo "  make notarize TEAM_ID=YOURTEAMID"; \
		exit 1; \
	fi
	@rm -f $(ZIP_FILE)
	ditto -c -k --keepParent $(BINARY_PATH) $(ZIP_FILE)
	@echo "$(YELLOW)Submitting for notarization (this may take a few minutes)...$(NC)"
	@echo "$(YELLOW)Using profile: $(NOTARY_PROFILE)$(NC)"
	@if ! xcrun notarytool history --keychain-profile $(NOTARY_PROFILE) &> /dev/null; then \
		echo "$(RED)Error: Notarization profile '$(NOTARY_PROFILE)' not found!$(NC)"; \
		echo "$(YELLOW)Available options:$(NC)"; \
		echo "  1. Run: make setup-notary"; \
		echo "  2. Use a different profile: make release NOTARY_PROFILE=your-profile-name"; \
		echo "  3. List existing profiles with: security find-generic-password -s \"altool\" -w"; \
		exit 1; \
	fi
	xcrun notarytool submit $(ZIP_FILE) \
		--keychain-profile $(NOTARY_PROFILE) \
		--wait
	@echo "$(GREEN)Stapling notarization ticket...$(NC)"
	@if xcrun stapler staple $(BINARY_PATH) 2>/dev/null; then \
		echo "$(GREEN)✓ Stapling successful$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Stapling failed (Error 73) - this is normal for command-line tools$(NC)"; \
		echo "$(YELLOW)  The binary is notarized and will verify online when first run$(NC)"; \
	fi
	@echo "$(GREEN)✓ Notarization complete$(NC)"

install: notarize
	@echo "$(GREEN)Installing to $(INSTALL_PATH)...$(NC)"
	sudo cp $(BINARY_PATH) $(INSTALL_PATH)
	sudo chmod +x $(INSTALL_PATH)
	@echo "$(GREEN)Verifying installation...$(NC)"
	@which $(BINARY_NAME)
	@$(BINARY_NAME) --help
	@echo "$(GREEN)✓ Installation complete!$(NC)"

release: install
	@echo "$(GREEN)✓ Build, sign, notarize, and install complete!$(NC)"

clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	swift package clean
	rm -rf .build
	rm -f $(ZIP_FILE)
	@echo "$(GREEN)✓ Clean complete$(NC)"

setup-notary:
	@echo "$(GREEN)Notarization Setup Instructions:$(NC)"
	@echo ""
	@echo "1. Go to $(YELLOW)https://appleid.apple.com$(NC)"
	@echo "2. Sign in and generate an app-specific password"
	@echo "3. Run this command with your Apple ID:"
	@echo ""
	@echo "   $(YELLOW)xcrun notarytool store-credentials \\"
	@echo "     --apple-id YOUR_APPLE_ID \\"
	@echo "     --team-id $(TEAM_ID) \\"
	@echo "     $(NOTARY_PROFILE)$(NC)"
	@echo ""
	@echo "   Or use a custom profile name:"
	@echo ""
	@echo "   $(YELLOW)xcrun notarytool store-credentials \\"
	@echo "     --apple-id YOUR_APPLE_ID \\"
	@echo "     --team-id $(TEAM_ID) \\"
	@echo "     my-profile-name$(NC)"
	@echo ""
	@echo "4. Enter the app-specific password when prompted"
	@echo "5. After setup, run: $(GREEN)make release$(NC)"
	@echo "   Or with custom profile: $(GREEN)make release NOTARY_PROFILE=my-profile-name$(NC)"
