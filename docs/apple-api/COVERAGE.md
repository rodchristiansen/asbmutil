# Apple API coverage

Generated from `docs/apple-api/coverage.json` by `scripts/apple-api-watch.py render`; edit the JSON, not this file.

Latest Apple release on record: **2.6 (Apple Business) - 2026/9/24**.

Done: 10, To do: 46, Skipped: 1

| Endpoint | Apple title | Platforms | Status | Where / note |
|---|---|---|---|---|
| `GET /v1/apps` | Get Apps | AB | To do |  |
| `GET /v1/apps/{id}` | Get App Information | AB | To do |  |
| `GET /v1/auditEvents` | Get Audit Events | AB | Done | listAuditEvents · audit-events, app Audit Events |
| `GET /v1/blueprints` | Get Blueprints | AB | To do |  |
| `POST /v1/blueprints` | Create a Blueprint | AB | To do |  |
| `DELETE /v1/blueprints/{id}` | Delete a Blueprint | AB | To do |  |
| `GET /v1/blueprints/{id}` | Get Blueprint Information | AB | To do |  |
| `PATCH /v1/blueprints/{id}` | Update a Blueprint | AB | To do |  |
| `DELETE /v1/blueprints/{id}/relationships/apps` | Remove Apps from a Blueprint | AB | To do |  |
| `GET /v1/blueprints/{id}/relationships/apps` | Get App IDs for a Blueprint | AB | To do |  |
| `POST /v1/blueprints/{id}/relationships/apps` | Add Apps to a Blueprint | AB | To do |  |
| `DELETE /v1/blueprints/{id}/relationships/configurations` | Remove Configurations from a Blueprint | AB | To do |  |
| `GET /v1/blueprints/{id}/relationships/configurations` | Get Configuration IDs for a Blueprint | AB | To do |  |
| `POST /v1/blueprints/{id}/relationships/configurations` | Add Configurations to a Blueprint | AB | To do |  |
| `DELETE /v1/blueprints/{id}/relationships/orgDevices` | Remove Devices from a Blueprint | AB | To do |  |
| `GET /v1/blueprints/{id}/relationships/orgDevices` | Get Device IDs for a Blueprint | AB | To do |  |
| `POST /v1/blueprints/{id}/relationships/orgDevices` | Add Devices to a Blueprint | AB | To do |  |
| `DELETE /v1/blueprints/{id}/relationships/packages` | Remove Packages from a Blueprint | AB | To do |  |
| `GET /v1/blueprints/{id}/relationships/packages` | Get Package IDs for a Blueprint | AB | To do |  |
| `POST /v1/blueprints/{id}/relationships/packages` | Add Packages to a Blueprint | AB | To do |  |
| `DELETE /v1/blueprints/{id}/relationships/userGroups` | Remove User Groups from a Blueprint | AB | To do |  |
| `GET /v1/blueprints/{id}/relationships/userGroups` | Get User Group IDs for a Blueprint | AB | To do |  |
| `POST /v1/blueprints/{id}/relationships/userGroups` | Add User Groups to a Blueprint | AB | To do |  |
| `DELETE /v1/blueprints/{id}/relationships/users` | Remove Users from a Blueprint | AB | To do |  |
| `GET /v1/blueprints/{id}/relationships/users` | Get User IDs for a Blueprint | AB | To do |  |
| `POST /v1/blueprints/{id}/relationships/users` | Add Users to a Blueprint | AB | To do |  |
| `GET /v1/configurations` | Get Configurations | AB | To do |  |
| `POST /v1/configurations` | Create a Configuration | AB | To do |  |
| `DELETE /v1/configurations/{id}` | Delete a Configuration | AB | To do |  |
| `GET /v1/configurations/{id}` | Get Configuration Information | AB | To do |  |
| `PATCH /v1/configurations/{id}` | Update a Configuration | AB | To do |  |
| `GET /v1/mdmDevices` | Get Devices Enrolled in Apple Device Management Service | AB | To do |  |
| `GET /v1/mdmDevices/{id}/details` | Get Details for a Device Enrolled in Apple Device Management Service | AB | To do |  |
| `GET /v1/mdmServers` | Get Device Management Services | AB + ASM | Done | listMdmServers · list-mdm-servers, app Servers |
| `POST /v1/mdmServers` | Create a Device Management Service | AB | To do |  |
| `DELETE /v1/mdmServers/{id}` | Delete a Device Management Service | AB | To do |  |
| `GET /v1/mdmServers/{id}` | Get Device Management Service Information | AB + ASM | To do |  |
| `PATCH /v1/mdmServers/{id}` | Update a Device Management Service | AB | To do |  |
| `GET /v1/mdmServers/{id}/relationships/devices` | Get All Device IDs for a Device Management Service | AB + ASM | Done | listMdmServerDevices · list-devices-servers |
| `POST /v1/orgDeviceActivities` | Assign or Unassign Devices to a Device Management Service | AB + ASM | Done | createDeviceActivity · assign, unassign, migration, release-devices |
| `GET /v1/orgDeviceActivities/{id}` | Get Organization Device Activity Information | AB + ASM | Done | activityStatus · batch-status |
| `GET /v1/orgDevices` | Get Organization Devices | AB + ASM | Done | listDevices · list-devices, app Devices |
| `GET /v1/orgDevices/{id}` | Get Device Information | AB + ASM | Done | getDevice · get-device-info, migration-status |
| `GET /v1/orgDevices/{id}/activationLockStatus` | Get the Activation Lock Status for a Device | AB + ASM | Done | getActivationLockStatus · activation-lock |
| `GET /v1/orgDevices/{id}/appleCareCoverage` | Get AppleCare Coverage Information for a Device | AB + ASM | Done | getAppleCareCoverage · get-device-info --applecare |
| `GET /v1/orgDevices/{id}/assignedServer` | Get the Assigned Device Management Service Information for a Device | AB + ASM | Skipped | Same data as the relationships/assignedServer linkage we use |
| `GET /v1/orgDevices/{id}/relationships/assignedServer` | Get the Assigned Device Management Service ID for a Device | AB + ASM | Done | getAssignedMdm · get-assigned-mdm |
| `GET /v1/organizationalUnits` | Get Organizational Units | AB | To do |  |
| `GET /v1/organizationalUnits/{id}` | Get Organizational Unit Information | AB | To do |  |
| `GET /v1/organizationalUnits/{id}/relationships/users` | Get User IDs for an Organizational Unit | AB | To do |  |
| `GET /v1/packages` | Get Packages | AB | To do |  |
| `GET /v1/packages/{id}` | Get Package Information | AB | To do |  |
| `GET /v1/userGroups` | Get User Groups | AB | To do |  |
| `GET /v1/userGroups/{id}` | Get User Group Information | AB | To do |  |
| `GET /v1/userGroups/{id}/relationships/users` | Get User IDs for a User Group | AB | To do |  |
| `GET /v1/users` | Get Users | AB | To do |  |
| `GET /v1/users/{id}` | Get User Information | AB | To do |  |

## Releases on record

- 2.6 (Apple Business) - 2026/9/24
- 2.5 (Apple Business) - 2026/9/15
- 1.7 (Apple School Manager) - 2026/9/15
- 2.4 (Apple Business) - 2026/8/26
- 2.3 (Apple Business) - 2026/8/12
- 1.6 (Apple School Manager) - 2026/8/12
- 2.2 (Apple Business) - 2026/7/15
- 2.1 (Apple Business) - 2026/6/3
- 2.0 (Apple Business) - 2026/4/14
- 1.5 (Apple School Manager and Apple Business) - 2026/1/20
- 1.4 (Apple School Manager and Apple Business) - 2025/12/17
- 1.3 (Apple School Manager and Apple Business) - 2025/11/5
- 1.2 (Apple School Manager and Apple Business) - 2025/07/16
- 1.1 (Apple School Manager and Apple Business) - 2025/07/10

## Enums on record

- **ActivationLockType**: `MDM`, `USER`, `NONE`
- **AppleCareCoveragePaymentType**: `ABE_SUBSCRIPTION`, `PAID_UP_FRONT`, `SUBSCRIPTION`, `NONE`
- **AppleCareCoverageStatus**: `ACTIVE`, `INACTIVE`
- **AuditEventActorType**: `USER`, `API_USER`, `SYSTEM`
- **AuditEventCategory**: `ORGANIZATION`, `ACCOUNT_ACTIVITY`, `DEVICE_INVENTORY`, `PURCHASING`, `DEVICE_MANAGEMENT`
- **AuditEventIdpProtocol**: `OIDC`, `SAML`
- **AuditEventIdpVendorName**: `GOOGLE`, `MICROSOFT`, `MICROSOFT_OIDC`, `GENERIC_IDP`
- **AuditEventOutcome**: `SUCCESS`, `FAILURE`
- **AuditEventPurchaseSourceType**: `APPLE`, `MANUALLY_ADDED`, `RESELLER`
- **AuditEventReleaseEntityType**: `USER`, `MDM`, `RESELLER`, `API`, `REPLACEMENT`
- **AuditEventSubjectType**: `ORGANIZATION`, `USER`, `LOCATION`, `DEVICE`, `COLLECTION`, `DEVICE_MANAGEMENT_SETTING`, `SUBSCRIPTION`, `DOMAIN`, `API_USER`
- **AuditEventType**: `DEVICE_ADDED_TO_ORG`, `DEVICE_REMOVED_FROM_ORG`, `DEVICE_ASSIGNED_TO_SERVER`, `DEVICE_UNASSIGNED_FROM_SERVER`, `SUBJECT_HAS_ICLOUD_STORAGE_PURCHASE_ADDED`, `SUBJECT_HAS_ICLOUD_STORAGE_PURCHASE_REMOVED`, `SUBJECT_HAS_APPLECARE_PURCHASE_ADDED`, `SUBJECT_HAS_APPLECARE_PURCHASE_REMOVED`, `DEVICE_IS_ERASED`, `CONFIG_SETTINGS_CREATED`, `CONFIG_SETTINGS_UPDATED`, `CONFIG_SETTINGS_DELETED`, `COLLECTION_CREATED`, `COLLECTION_UPDATED`, `COLLECTION_DELETED`, `SUBSCRIPTION_CREATED`, `SUBSCRIPTION_UPDATED`, `SUBSCRIPTION_DELETED`, `ACCOUNT_ROLE_LOCATION_CHANGED`, `ACCOUNT_ADDED`, `ACCOUNT_DELETED`, `EXTERNAL_ACCOUNT_ASSOCIATED`, `EXTERNAL_ACCOUNT_DISASSOCIATED`, `DOMAIN_ADDED`, `DOMAIN_REMOVED`, `DOMAIN_VERIFIED`, `API_ACCOUNT_CREATED_WITH_KEY`, `API_ACCOUNT_CREATED_WITHOUT_KEY`, `API_ACCOUNT_DELETED`, `API_ACCOUNT_KEY_REVOKED`, `API_ACCOUNT_KEY_GENERATED`, `API_ACCOUNT_ROLE_LOCATION_CHANGED`, `API_ACCOUNT_NAME_CHANGED`, `ROLE_CREATED`, `ROLE_UPDATED`, `TERMS_ACCEPTED`, `DOMAIN_FEDERATION_ENABLED`, `DOMAIN_FEDERATION_DISABLED`, `BATCH_PASSWORD_RESET_INITIATED`, `EXTERNAL_ACCOUNT_INVITED`, `ACCOUNT_IMAGE_SET`, `ACCOUNT_IMAGE_REPLACED`, `ACCOUNT_IMAGE_REMOVED`, `IDP_CREATED`, `IDP_UPDATED`, `IDP_DELETED`, `IDP_ACCOUNT_SYNC_ENABLED`, `IDP_ACCOUNT_SYNC_DISABLED`, `APPLE_SERVICES_SETTINGS_UPDATED`, `ACCOUNT_PASSWORD_CHANGED`
- **BlueprintStatus**: `ACTIVE`, `TO_BE_DELETED`
- **ConfigurationPlatform**: `PLATFORM_MACOS`, `PLATFORM_IOS`, `PLATFORM_TVOS`, `PLATFORM_VISIONOS`
- **ConfigurationType**: `AIR_DROP`, `AIR_PRINT`, `APP_ACCESS`, `APPLE_INTELLIGENCE_SIRI`, `APPLICATION_LAYER_FIREWALL`, `AUTHENTICATION_SCREEN_LOCK`, `CERTIFICATE`, `CONFERENCE_ROOM_DISPLAY`, `CONTENT_CACHING`, `CUSTOM_PROFILE`, `CUSTOM_SETTING`, `DATA_MANAGEMENT`, `ENERGY_SAVER`, `FILE_VAULT`, `GATE_KEEPER`, `ICLOUD`, `LOGIN_WINDOW`, `MEDIA_MANAGEMENT`, `SOFTWARE_UPDATE`, `VPN`, `WEB_CLIP`, `WEB_FILTER`, `WIFI`
- **DeviceEraseStatus**: `NOT_ERASED`, `ERASED`
- **DeviceLockStatus**: `LOCKED`, `UNLOCKED`
- **LostModeStatus**: `ENABLED`, `DISABLED`
- **MdmMigrationStatus**: `REQUESTED`, `STARTED`, `SUCCESS`, `FAILED`
- **OrgDeviceActivityType**: `ASSIGN_DEVICES`, `UNASSIGN_DEVICES`, `ASSIGN_DEVICES_WITH_MDM_MIGRATION_DEADLINE`, `UPDATE_MDM_MIGRATION_DEADLINE`, `CANCEL_MDM_MIGRATION`, `RELEASE_DEVICES`
- **SupportedOS**: `SUPPORTED_OS_UNSPECIFIED`, `SUPPORTED_OS_IPADOS`, `SUPPORTED_OS_IOS`, `SUPPORTED_OS_MACOS`, `SUPPORTED_OS_TVOS`, `SUPPORTED_OS_WATCHOS`, `SUPPORTED_OS_VISIONOS`
- **UserGroupStatus**: `ACTIVE`
- **UserGroupType**: `STANDARD`, `SMART`
- **UserPhoneNumberType**: `WORK`, `HOME`, `MOBILE`
- **UserStatus**: `NEW`, `RELEASED`, `ACTIVE`, `DEACTIVATED`, `LOCKED`, `LOCKED_FOR_SHARED_IPAD`
