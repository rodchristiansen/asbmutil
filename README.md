# ASBMUtil

A swift app and `asbmutil` cli for [Apple School & Business Manager API](https://developer.apple.com/documentation/apple-school-and-business-manager-api)

Get devices info, assign/unassign MDM servers, and resolve device-to-server assignments across your fleet.

![ASBMUtil app interface](https://github.com/rodchristiansen/asbmutil/blob/feature/swiftui-gui/resources/main.png?raw=true)

## Features

* Pure Swift 6 binary, no external runtime dependencies
* Secure and store credentials in macOS Keychain
* Multiple profile support for managing different AxM instances
* Automatic OAuth 2 client‑assertion handling
* Paginated device fetch for large inventories
* Bulk operations with CSV support or directly in the GUI app
* StrictConcurrency enabled
* Bulk device-to-server resolution via server-side device listing (4-5 API calls regardless of fleet size)
* Bulk AppleCare enrichment for whole fleets via `list-devices --include-applecare` (two-pass fan-out, no CSV required)
* **NEW (API 1.5)**: MAC addresses support multiple values (array format) for devices with multiple network interfaces
* **NEW (API 1.4)**: Wi-Fi, Bluetooth, and built-in Ethernet MAC addresses for macOS
* **NEW (API 1.3)**: AppleCare coverage lookup for devices (single-serial via `get-devices-info`, whole-fleet via `list-devices --include-applecare`)
* **NEW (API 1.2)**: Wi-Fi and Bluetooth MAC addresses for iOS, iPadOS, tvOS, and visionOS

![ASBMUtil bulk reassignment interface](https://github.com/rodchristiansen/asbmutil/blob/feature/swiftui-gui/resources/bulk.png?raw=true)

## Quick setup

### Build

```bash
git clone https://github.com/rodchristiansen/asbmutil.git
cd asbmutil
swift build -c release
```

Binary: `.build/release/asbmutil`

### Build with Makefile

The included Makefile provides easy targets for building, signing, notarizing, and installing:

```bash
# Build, sign, notarize, and install to /usr/local/bin in one command
make release

# Individual steps
make build          # Build release binary
make sign           # Build and sign
make notarize       # Build, sign, and notarize
make install        # Complete process and install to /usr/local/bin
make clean          # Remove build artifacts
make help           # Show all available targets
```

**First-time setup for code signing and notarization:**

1. Copy the environment template:
```bash
cp .env.example .env
```

2. Edit `.env` and fill in your Apple Developer credentials:
```bash
# Find your signing identity
security find-identity -v -p codesigning

# Then edit .env with your values:
# APPLE_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM123456)"
# APPLE_TEAM_ID=TEAM123456
# APPLE_NOTARY_PROFILE=notarization_credentials
```

3. Set up notarization credentials:
```bash
# Show setup instructions
make setup-notary

# Then follow the instructions to store your credentials
xcrun notarytool store-credentials notarization_credentials \
  --apple-id YOUR_APPLE_ID \
  --team-id YOUR_TEAM_ID
```

**Alternative:** You can also provide credentials via command line without using `.env`:
```bash
make release \
  SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  TEAM_ID=TEAMID \
  NOTARY_PROFILE=your-profile-name
```

### Save your Credentials to Keychain

```bash
cd .build/release/
./asbmutil config set \
  --client-id  SCHOOLAPI.27f3a3b2-801f-4e0b-a23e-e526faaee089 \
  --key-id     c12e9107-5d5e-421c-969c-7196b59bde98 \
  --pem-path   ~/Downloads/axm_private_key.pem
```

### Multiple Profile Support

For organizations managing multiple ABM instances, you can create named profiles:

```bash
# Set up credentials for school district
./asbmutil config set \
  --profile "school-unit-2" \
  --client-id  SCHOOLAPI.27f3a3b2-801f-4e0b-a23e-e526faaee089 \
  --key-id     c12e9107-5d5e-421c-969c-7196b59bde98 \
  --pem-path   ~/Downloads/school_private_key.pem

# Set up credentials for business division
./asbmutil config set \
  --profile "business-unit-3" \
  --client-id  BUSINESSAPI.84c7b9e1-402a-4f1c-b56d-f839e77abc12 \
  --key-id     a89f6254-2c1e-481b-856c-4297f66cda87 \
  --pem-path   ~/Downloads/business_private_key.pem

# List all profiles
./asbmutil config list-profiles

# Switch current active profile
./asbmutil config set-profile "business-unit-3"

# Show current profile
./asbmutil config show-profile
```

![ASBMUtil profiles](https://github.com/rodchristiansen/asbmutil/blob/feature/swiftui-gui/resources/profiles.png?raw=true))

## Commands

```bash
# Profile Management
./asbmutil config list-profiles              # List all credential profiles
./asbmutil config set-profile "profile-name" # Set current active profile
./asbmutil config show-profile               # Show current active profile

# Device Operations (using current profile)
./asbmutil list-devices
./asbmutil list-devices --devices-per-page 200
./asbmutil list-devices --total-limit 50
./asbmutil list-devices --total-limit 1000 --devices-per-page 100
./asbmutil list-devices --show-pagination
./asbmutil list-devices --include-applecare                            # Enrich every device with AppleCare coverage (4 parallel)
./asbmutil list-devices --include-applecare --applecare-concurrency 2  # Lower concurrency for flakier networks
./asbmutil list-devices --include-applecare --no-applecare-retry       # Skip the sequential second-pass retry

# Device Operations (using specific profile)
./asbmutil list-devices --profile "school-district-2"
./asbmutil assign --serials P8R2K47NF5X9 --mdm "Intune" --profile "business-unit-2"

# MDM Server Operations
./asbmutil list-mdm-servers
./asbmutil list-devices-servers --mdm "MicroMDM"         # Devices assigned to a named MDM server
./asbmutil list-devices-servers --server-id A47B2E83F9  # Devices assigned to a server by ID
./asbmutil list-devices-servers --all                    # Devices for all MDM servers
./asbmutil list-devices-servers --serials P8R2K47NF5X9,Q7M5V83WH4L2  # Look up MDM for specific devices
./asbmutil list-devices-servers --csv-file devices.csv  # Look up MDM from CSV

# Get Device Info (device attributes + AppleCare + assigned MDM)
./asbmutil get-devices-info --serials P8R2K47NF5X9
./asbmutil get-devices-info --serials P8R2K47NF5X9,Q7M5V83WH4L2
./asbmutil get-devices-info --csv-file devices.csv
./asbmutil get-devices-info --mdm --serials P8R2K47NF5X9  # MDM info only

# Credential Management
./asbmutil config show                           # Show current profile credentials
./asbmutil config show --profile "profile-name"  # Show specific profile
./asbmutil config clear                          # Clear all profiles
./asbmutil config clear --profile "profile-name" # Clear specific profile

# Assignment Operations
./asbmutil assign --serials P8R2K47NF5X9,Q7M5V83WH4L2 --mdm "Intune"
./asbmutil assign --csv-file devices.csv --mdm "Intune"
./asbmutil unassign --serials P8R2K47NF5X9,Q7M5V83WH4L2 --mdm "MicroMDM"
./asbmutil unassign --csv-file devices.csv --mdm "MicroMDM"

# Activity Status
./asbmutil batch-status 361c8b76-55c6-4d07-9c1a-2ea9755c34e3
```

## Profile System

The profile system allows you to manage credentials for multiple ABM instances:

* **Default Profile**: If no profile is specified, uses the "default" profile
* **Named Profiles**: Create profiles with descriptive names like "school-east", "business-unit-3", etc.
* **Current Profile**: One profile is always "current" and used by default
* **Per-Command Override**: Use `--profile` on any command to override the current profile

### Profile Commands

```bash
# Create/update a profile
./asbmutil config set --profile "my-school" --client-id ... --key-id ... --pem-path ...

# List all profiles
./asbmutil config list-profiles

# Set current active profile  
./asbmutil config set-profile "my-school"

# Show current profile info
./asbmutil config show-profile

# Show specific profile credentials
./asbmutil config show --profile "my-school"

# Clear specific profile
./asbmutil config clear --profile "my-school"

# Clear all profiles
./asbmutil config clear
```

### Sample Profile Output

```bash
./asbmutil config list-profiles

Available profiles:
  business-unit-2 - business.api - created Dec 15, 2024 at 2:30 PM
  default - school.api - created Dec 10, 2024 at 10:15 AM
  school-district-2 (current) - school.api - created Dec 12, 2024 at 9:45 AM
```

### Scripting with Multiple Profiles

For automation and scripts, you can use the `--profile` option to work with multiple ABM instances without switching the current profile:

```bash
#!/bin/bash

# Script to manage multiple ABM instances
SCHOOL_PROFILE="school-district-2"
BUSINESS_PROFILE="business-unit-3"

# List devices from school instance
echo "School devices:"
asbmutil list-devices --profile "$SCHOOL_PROFILE"

# List devices from business instance  
echo "Business devices:"
asbmutil list-devices --profile "$BUSINESS_PROFILE"

# Assign devices to different MDM servers per instance
asbmutil assign --serials ABC123,DEF456 --mdm "School MDM" --profile "$SCHOOL_PROFILE"
asbmutil assign --serials GHI789,JKL012 --mdm "Business MDM" --profile "$BUSINESS_PROFILE"

# Check status on both instances
asbmutil batch-status "$ACTIVITY_ID_1" --profile "$SCHOOL_PROFILE"
asbmutil batch-status "$ACTIVITY_ID_2" --profile "$BUSINESS_PROFILE"
```

This approach is particularly useful for:

* **CI/CD pipelines** managing multiple organizations
* **Scheduled scripts** that need to operate across different ABM instances
* **Administrative tools** that aggregate data from multiple sources
* **Testing environments** where you need to validate against different ABM setups

## Export reports

Use the share sheet export button to export selection or filtered results to many formats
![ASBMUtil export](https://github.com/rodchristiansen/asbmutil/blob/feature/swiftui-gui/resources/export.png?raw=true)

## CSV File Format

For bulk operations, you can use a CSV file where the first column contains device serial numbers:

```csv
P8R2K47NF5X9,MacBook Air,2023
Q7M5V83WH4L2,MacBook Pro,2022
T3N6Y94KM8P1,iMac,2024
Z9B4C72HXFW5,Mac Studio,2023
```

The tool will read only the first column (serial numbers) and ignore any additional columns.

## Sample Output

### Config Show

```bash
./asbmutil config show

SBM_CLIENT_ID=SCHOOLAPI.27f3a3b2-801f-4e0b-a23e-e526faaee089
SBM_KEY_ID=c12e9107-5d5e-421c-969c-7196b59bde98
PRIVATE_KEY=[-----BEGIN PRIVATE KEY-----…]
```

### Config Clear

```bash
./asbmutil config clear

credentials cleared
```

### List Devices

```bash
./asbmutil list-devices | jq

Page 1: found 100 devices (devices per page: 100), total so far: 100
Page 2: found 100 devices (devices per page: 100), total so far: 200
Page 3: found 100 devices (devices per page: 100), total so far: 300
Page 4: found 100 devices (devices per page: 100), total so far: 400
Page 5: found 100 devices (devices per page: 100), total so far: 500
Page 6: found 100 devices (devices per page: 100), total so far: 600
Page 7: found 100 devices (devices per page: 100), total so far: 700
Page 8: found 100 devices (devices per page: 100), total so far: 800
Page 9: found 68 devices (devices per page: 100), total so far: 868
Pagination complete: 868 total devices across 9 pages
[
  {
    "serialNumber": "P8R2K47NF5X9",
    "partNumber": "Z0RT"
  },
  {
    "serialNumber": "Q7M5V83WH4L2",
    "partNumber": "MD455C/A"
  },
  {
    "serialNumber": "T3N6Y94KM8P1",
    "partNumber": "MC834C/A"
  },
  {
    "serialNumber": "Z9B4C72HXFW5",
    "partNumber": "Z0QX"
  },
  {
    "serialNumber": "M4L8D63JKV7Q",
    "partNumber": "MQ2K2C/A"
  }
]
```

### List Devices with Total Limit

```bash
./asbmutil list-devices --total-limit 10 --show-pagination

Starting device listing with pagination details...
Total device limit: 10
Page 1: retrieved 10/100 devices (devices per page: 100), total so far: 10 [limit: 10]
  No more pages available
Reached total limit of 10 devices
Pagination complete: 10 total devices across 1 pages (limited to 10)
```

### List Devices with AppleCare Coverage

Apple's API has no bulk AppleCare endpoint (`/v1/orgDevices/{serial}/appleCareCoverage`
is one serial per call), so `--include-applecare` lists devices as usual and then fans
out per-device coverage lookups in two passes:

1. **Parallel pass** (default 4 concurrent) — fast, but Apple's HTTP/2 endpoint drops
   streams under higher concurrency, so ~10-15% of requests typically exhaust retries.
   Empirically, raising concurrency past ~4 makes failure rates much worse, not better.
2. **Sequential pass** (concurrency 1) — retries only the failed serials one at a time;
   recovers the vast majority because single in-flight requests don't trigger HTTP/2
   stream resets. Skip with `--no-applecare-retry`.

Devices without coverage omit the `appleCareCoverage` field; the built-in 429 backoff
still applies; and a stderr summary at the end distinguishes "no coverage" from
"lookup failed (retries exhausted after both passes)" so the two aren't conflated.

All progress, pass summaries, and failure lines are written to stderr — the JSON
array on stdout stays clean for `jq` or any other consumer:

```bash
./asbmutil list-devices --include-applecare | jq

# --- stderr ---
Page 1: found 100 devices ...
Pagination complete: 817 total devices across 9 pages
Fetching AppleCare coverage for 817 devices (concurrency: 4)...
  AppleCare: 25/817
  AppleCare: 50/817
  ...
AppleCare pass 1: 573 with coverage, 138 without, 106 errored
AppleCare pass 2: retrying 106 failed serials sequentially...
AppleCare pass 2: recovered 97, 9 still errored
AppleCare final: 670 with coverage, 138 without, 9 errored (retries exhausted)
Failed serials: ABC123,DEF456,...
Rerun with: asbmutil get-devices-info --serials ABC123,DEF456,...

# --- stdout (piped to jq) ---
[
  {
    "serialNumber": "P8R2K47NF5X9",
    "partNumber": "Z0RT",
    "appleCareCoverage": [
      {
        "agreementNumber": "0000000001",
        "description": "AppleCare+",
        "status": "ACTIVE",
        "startDateTime": "2025-04-17T00:00:00Z",
        "endDateTime": "2026-04-17T00:00:00Z",
        "isRenewable": true,
        "isCanceled": false
      }
    ]
  },
  {
    "serialNumber": "Q7M5V83WH4L2",
    "partNumber": "MD455C/A"
  }
]
```

`--applecare-concurrency` accepts 1-32 and defaults to 4. Lower it (e.g. 2) on
flakier networks or if you're seeing many pass-1 failures. Raising it is usually
counterproductive for this API: Apple's HTTP/2 endpoint multiplexes over one TCP
connection per host and drops streams aggressively under concurrent load, so more
parallelism means more pass-1 failures (which pass 2 then has to re-serialize
anyway). The 429/backoff retry path still applies on top of the two-pass model.

### List MDM Servers

```bash
./asbmutil list-mdm-servers | jq

[
  {
    "serverName": "Devices Added by Apple Configurator 2",
    "serverType": "APPLE_CONFIGURATOR",
    "id": "A47B2E83F92D4C1AB5E638F7C294D8E9",
    "updatedDateTime": "2023-08-15T09:22:31.045Z",
    "createdDateTime": "2023-08-15T09:22:31.042Z"
  },
  {
    "serverName": "Intune",
    "serverType": "MDM",
    "id": "B92F7A64E81C4D3F9067C2B5E8F43A71",
    "updatedDateTime": "2024-11-22T14:45:17.893Z",
    "createdDateTime": "2022-09-08T16:28:42.156Z"
  },
  {
    "serverName": "MicroMDM",
    "serverType": "MDM",
    "id": "C5E8B39F4A7D4E2C8931F6D4A2B8E5F7",
    "updatedDateTime": "2024-12-03T18:17:55.674Z",
    "createdDateTime": "2020-05-14T11:45:28.923Z"
  },
  {
    "serverName": "SimpleMDM",
    "serverType": "MDM",
    "id": "D74A1C96B8E54F3D7429E8C6F1A4B7D9",
    "updatedDateTime": "2024-11-22T14:45:17.889Z",
    "createdDateTime": "2019-03-27T13:52:18.761Z"
  }
]
```

![ASBMUtil servers list](https://github.com/rodchristiansen/asbmutil/blob/feature/swiftui-gui/resources/servers.png?raw=true)

### Get Assigned MDM

> **Note:** `get-assigned-mdm` is now a hidden alias. Assigned MDM info is included in `get-devices-info` output.

```bash
./asbmutil get-assigned-mdm P8R2K47NF5X9 | jq

{
  "data": {
    "serverType": "MDM",
    "type": "mdmServers",
    "id": "C5E8B39F4A7D4E2C8931F6D4A2B8E5F7",
    "serverName": "MicroMDM"
  },
  "links": {
    "related": "https://api-school.apple.com/v1/orgDevices/P8R2K47NF5X9/assignedServer",
    "self": "https://api-school.apple.com/v1/orgDevices/P8R2K47NF5X9/relationships/assignedServer"
  }
}
```

### Get Devices Info (device attributes + AppleCare + assigned MDM)

```bash
./asbmutil get-devices-info --serials P8R2K47NF5X9 | jq

{
  "serialNumber": "P8R2K47NF5X9",
  "partNumber": "Z0RT",
  "assetTag": "ASSET-001",
  "os": "macOS",
  "deviceFamily": "Mac",
  "status": "ASSIGNED",
  "color": "SPACE_GRAY",
  "wifiMacAddress": "AA:BB:CC:DD:EE:FF",
  "bluetoothMacAddress": "FF:EE:DD:CC:BB:AA",
  "ethernetMacAddress": "11:22:33:44:55:66",
  "appleCareCoverage": [
    {
      "agreementNumber": "AC123456789",
      "description": "AppleCare+ for Mac",
      "startDateTime": "2024-01-15T00:00:00Z",
      "endDateTime": "2027-01-15T00:00:00Z",
      "status": "ACTIVE",
      "paymentType": "PAID",
      "isRenewable": true,
      "isCanceled": false
    }
  ],
  "assignedMdm": {
    "id": "C5E8B39F4A7D4E2C8931F6D4A2B8E5F7",
    "serverName": "MicroMDM",
    "serverType": "MDM"
  }
}
```

Use `--mdm` to output only assigned MDM info:

```bash
./asbmutil get-devices-info --mdm --serials P8R2K47NF5X9 | jq

{
  "id": "C5E8B39F4A7D4E2C8931F6D4A2B8E5F7",
  "serverName": "MicroMDM",
  "serverType": "MDM"
}
```

### List Devices Servers

Query device-to-server assignments in two directions:

**Which devices are on a server?** Use `--mdm`, `--server-id`, or `--all`:

```bash
./asbmutil list-devices-servers --mdm "MicroMDM" | jq

[
  {
    "serverId": "C5E8B39F4A7D4E2C8931F6D4A2B8E5F7",
    "serverName": "MicroMDM",
    "serverType": "MDM",
    "deviceCount": 727,
    "devices": [
      "P8R2K47NF5X9",
      "Z9B4C72HXFW5",
      "M4L8D63JKV7Q"
    ]
  }
]
```

**Which server is each device on?** Use `--serials` or `--csv-file`:

```bash
./asbmutil list-devices-servers --serials P8R2K47NF5X9,Q7M5V83WH4L2,NOTREAL123 | jq

Fetched 4 MDM servers
  Devices Added by Apple Configurator 2: 1 devices
  Intune: 62 devices
  MicroMDM: 727 devices
  SimpleMDM: 10 devices
[
  {
    "serialNumber": "P8R2K47NF5X9",
    "assignedMdm": {
      "id": "C5E8B39F4A7D4E2C8931F6D4A2B8E5F7",
      "serverName": "MicroMDM",
      "serverType": "MDM"
    }
  },
  {
    "serialNumber": "Q7M5V83WH4L2",
    "assignedMdm": {
      "id": "B92F7A64E81C4D3F9067C2B5E8F43A71",
      "serverName": "Intune",
      "serverType": "MDM"
    }
  },
  {
    "serialNumber": "NOTREAL123",
    "assignedMdm": null
  }
]
Done: 2/3 devices have MDM assignments
```

Both modes use efficient server-side device listing (4-5 API calls regardless of device count).

### Assign Devices

```bash
./asbmutil assign --serials P8R2K47NF5X9 --mdm Intune | jq

{
  "id": "f8a29c74-3b7e-4d2a-9c8f-1e5d4a7b2c9e",
  "createdDateTime": "2025-01-15T14:32:18.45Z",
  "mdmServerId": "B92F7A64E81C4D3F9067C2B5E8F43A71",
  "activityType": "ASSIGN_DEVICES",
  "status": "IN_PROGRESS",
  "mdmServerName": "Intune",
  "deviceCount": 1,
  "mdmServerType": "MDM",
  "updatedDateTime": "",
  "deviceSerials": [
    "P8R2K47NF5X9"
  ]
}
```

## Requirements

* macOS 14 or newer  
* Xcode 16 or newer (Swift 6 toolchain)  
* AxM API Account

## Code Signing & Notarization

### Using Makefile (Recommended)

The easiest way to build a signed and notarized binary:

```bash
# One command to build, sign, notarize, and install
make release

# Or step by step
make build      # Build release binary
make sign       # Sign with Developer ID
make notarize   # Submit for notarization
make install    # Install to /usr/local/bin
```

See the [Quick setup](#quick-setup) section for notarization credential setup.

### Manual Process

For distribution, sign and notarize the binary manually:

```bash
# Sign the binary
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" .build/release/asbmutil

# Verify signing
codesign --verify --verbose .build/release/asbmutil

# Create a zip for notarization
zip asbmutil.zip .build/release/asbmutil

# Submit for notarization using API key
xcrun notarytool submit asbmutil.zip \
  --key AuthKey_KEY_ID.p8 \
  --key-id KEY_ID \
  --issuer ISSUER_ID \
  --wait

# OR submit for notarization using keychain profile
xcrun notarytool submit asbmutil.zip \
  --keychain-profile "notarytool-profile" \
  --wait

# Staple the notarization ticket
xcrun stapler staple .build/release/asbmutil
```

To set up a keychain profile for notarization:

```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "your-apple-id@example.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password"
```

## Contributing

PRs welcomed!

## License

MIT
