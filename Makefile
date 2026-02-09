.PHONY: all build sign notarize install clean help

# Configuration
BINARY_NAME = asbmutil
BUILD_DIR = .build/release
BINARY_PATH = $(BUILD_DIR)/$(BINARY_NAME)
ZIP_FILE = $(BINARY_NAME).zip
INSTALL_PATH = /usr/local/bin/$(BINARY_NAME)

# Code signing
SIGNING_IDENTITY = "Developer ID Application: Emily Carr University of Art and Design (7TF6CSP83S)"
TEAM_ID = 7TF6CSP83S
ENTITLEMENTS = entitlements.plist
# Override with: make release NOTARY_PROFILE=your-profile-name
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
	@echo "  $(YELLOW)sign$(NC)           - Sign the binary"
	@echo "  $(YELLOW)notarize$(NC)       - Submit for notarization"
	@echo "  $(YELLOW)install$(NC)        - Install to $(INSTALL_PATH)"
	@echo "  $(YELLOW)release$(NC)        - Build, sign, notarize, and install"
	@echo "  $(YELLOW)clean$(NC)          - Remove build artifacts"
	@echo "  $(YELLOW)setup-notary$(NC)   - Instructions for notarization setup"
	@echo ""
	@echo "$(GREEN)Environment Variables:$(NC)"
	@echo "  $(YELLOW)NOTARY_PROFILE$(NC) - Keychain profile name (default: AC_PASSWORD)"
	@echo "                   Usage: make release NOTARY_PROFILE=my-profile"
	@echo ""
	@echo "$(GREEN)Quick start:$(NC) make release"

build:
	@echo "$(GREEN)Building $(BINARY_NAME)...$(NC)"
	swift build -c release
	@echo "$(GREEN)✓ Build complete$(NC)"

sign: build
	@echo "$(GREEN)Signing binary...$(NC)"
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
