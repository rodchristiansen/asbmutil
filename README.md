# `asbmutil`

Swift command‑line interface for [Apple School & Business Manager (AxM) API](https://developer.apple.com/documentation/apple-school-and-business-manager-api)

Get devices info and assign/unassign MDM servers in bulk.

## Features

* Pure Swift 6 binary, no external runtime dependencies
* Secure and store credentials in macOS Keychain
* Automatic OAuth 2 client‑assertion handling
* Paginated device fetch for large inventories
* CSV file support for bulk operations
* StrictConcurrency enabled

## Quick setup

### Build

```bash
git clone https://github.com/rodchristiansen/asbmutil.git
cd asbmutil
swift build -c release
```

Binary: `.build/release/asbmutil`

### Save your Credentials to Keychain

```bash
cd .build/release/
./asbmutil config set \
  --client-id  SCHOOLAPI.27f3a3b2-801f-4e0b-a23e-e526faaee089 \
  --key-id     c12e9107-5d5e-421c-969c-7196b59bde98 \
  --pem-path   ~/Downloads/axm_private_key.pem
```

## Common commands

```bash
# list every device serial
./asbmutil list-devices

# list all device management services
./asbmutil list-mdm-servers

# get assigned MDM server for a device
./asbmutil get-assigned-mdm F4K9X72HG3M5

# assign two serials to an MDM server
./asbmutil assign --serials F4K9X72HG3M5,XY789ABC123D --mdm "Intune"

# assign serials from CSV file to an MDM server
./asbmutil assign --csv-file devices.csv --mdm "Intune"

# unassign two serials from an MDM server
./asbmutil unassign --serials F4K9X72HG3M5,XY789ABC123D --mdm "MicroMDM"

# unassign serials from CSV file from an MDM server
./asbmutil unassign --csv-file devices.csv --mdm "MicroMDM"

# check activity progress
./asbmutil batch-status 361c8b76-55c6-4d07-9c1a-2ea9755c34e3
```

`asbmutil --help` shows full usage.

## CSV File Format

For bulk operations, you can use a CSV file where the first column contains device serial numbers:

```csv
F4K9X72HG3M5,MacBook Air,2023
QWER234ASDF8,MacBook Pro,2022
MN8L5V92HKJP,iMac,2024
C02TY67HGFR4,Mac Studio,2023
```

The tool will read only the first column (serial numbers) and ignore any additional columns.

## Sample Output

### List Devices

```bash
./asbmutil list-devices | jq

Page 1: found 100 devices
Page 2: found 100 devices
Page 3: found 100 devices
Page 4: found 100 devices
Page 5: found 100 devices
Page 6: found 100 devices
Page 7: found 100 devices
Page 8: found 100 devices
Page 9: found 68 devices
[
  {
    "serialNumber": "F4K9X72HG3M5",
    "partNumber": "Z0RT"
  },
  {
    "serialNumber": "QWER234ASDF8",
    "partNumber": "MD455C/A"
  },
  {
    "serialNumber": "MN8L5V92HKJP",
    "partNumber": "MC834C/A"
  },
  {
    "serialNumber": "C02TY67HGFR4",
    "partNumber": "Z0QX"
  },
  {
    "serialNumber": "XY789ABC123D",
    "partNumber": "MQ2K2C/A"
  }
]
```

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

### Get Assigned MDM

```bash
./asbmutil get-assigned-mdm F4K9X72HG3M5 | jq

{
  "data": {
    "id": "C5E8B39F4A7D4E2C8931F6D4A2B8E5F7",
    "type": "mdmServers"
  }
}
```

## Requirements

* macOS 14 or newer  
* Xcode 16 beta (Swift 6 toolchain)  
* AxM API Account

## Code Signing & Notarization

For distribution, sign and notarize the binary:

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
