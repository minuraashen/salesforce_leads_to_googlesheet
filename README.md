# Export Salesforce Leads to Google Sheets

A Ballerina automation integration that exports Salesforce Lead records to a Google Sheets spreadsheet on a configurable cron schedule.

## Description

This integration automatically syncs Salesforce Lead data to Google Sheets, enabling easy reporting, analysis, and sharing of lead information with stakeholders who may not have direct Salesforce access.

## What It Does

- Queries Salesforce Lead records using customizable SOQL filters
- Maps selected Salesforce Lead fields to Google Sheets columns
- Creates a new Google Sheets spreadsheet with a timestamped name (e.g., "Salesforce Leads 2025-01-17 14:30")
- Optionally appends to an existing spreadsheet as a new sheet
- Handles timezone conversion for spreadsheet naming
- Filters converted leads based on configuration
- Provides detailed logging of export operations

## Prerequisites

### Salesforce OAuth Setup

1. Log in to your Salesforce account
2. Navigate to **Setup** → **Apps** → **App Manager**
3. Click **New Connected App**
4. Fill in the required fields:
   - Connected App Name: `Ballerina Salesforce Integration`
   - API Name: Auto-populated
   - Contact Email: Your email
5. Enable **OAuth Settings**:
   - Callback URL: `https://login.salesforce.com/services/oauth2/callback`
   - Selected OAuth Scopes:
     - `Access and manage your data (api)`
     - `Perform requests on your behalf at any time (refresh_token, offline_access)`
6. Save and note the **Consumer Key** (Client ID) and **Consumer Secret** (Client Secret)
7. Obtain a **Refresh Token** using OAuth 2.0 authorization flow
8. Note your Salesforce instance URL (e.g., `https://yourinstance.salesforce.com`)

**Required Scopes:**
- `api` - Access and manage your data
- `refresh_token` - Perform requests on your behalf at any time

### Google Cloud Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Google Sheets API** and **Google Drive API**
4. Navigate to **APIs & Services** → **Credentials**
5. Click **Create Credentials** → **OAuth 2.0 Client ID**
6. Configure the OAuth consent screen if prompted
7. Select **Application type**: Web application
8. Add authorized redirect URI: `https://developers.google.com/oauthplayground`
9. Note the **Client ID** and **Client Secret**
10. Use [OAuth 2.0 Playground](https://developers.google.com/oauthplayground) to obtain a **Refresh Token**:
    - Select **Google Sheets API v4** and **Google Drive API v3** scopes
    - Authorize and exchange authorization code for tokens

**Required Scopes:**
- `https://www.googleapis.com/auth/spreadsheets` - Read and write spreadsheets
- `https://www.googleapis.com/auth/drive` - Create and manage files in Google Drive

## Configuration

| Configuration | Type | Required | Default | Description |
|--------------|------|----------|---------|-------------|
| `salesforceConfig.refreshToken` | string | Yes | - | Salesforce OAuth refresh token |
| `salesforceConfig.clientId` | string | Yes | - | Salesforce OAuth client ID |
| `salesforceConfig.clientSecret` | string | Yes | - | Salesforce OAuth client secret |
| `salesforceConfig.refreshUrl` | string | Yes | - | Salesforce token refresh URL (e.g., `https://login.salesforce.com/services/oauth2/token`) |
| `salesforceConfig.baseUrl` | string | Yes | - | Salesforce instance base URL (e.g., `https://yourinstance.salesforce.com`) |
| `googleConfig.refreshToken` | string | Yes | - | Google OAuth refresh token |
| `googleConfig.clientId` | string | Yes | - | Google OAuth client ID |
| `googleConfig.clientSecret` | string | Yes | - | Google OAuth client secret |
| `spreadsheetId` | string | No | `()` | Target spreadsheet ID. If provided, uses the existing spreadsheet. If not provided, creates a new spreadsheet |
| `tabName` | string | No | `"Leads"` | Target sheet tab name within the spreadsheet |
| `timezone` | string | No | `"UTC"` | IANA timezone string for spreadsheet timestamp naming (e.g., "America/New_York", "Asia/Colombo") |
| `fieldMapping` | string[] | No | See below | Ordered list of Salesforce Lead field API names to export |
| `filterMode` | enum | No | `SOQL` | Lead filter mode: `SOQL` (use SOQL filter) or `LIST_VIEW` (use Salesforce List View ID) |
| `soqlFilter` | string | No | `""` | Additional SOQL WHERE clause fragment (used when filterMode = SOQL, e.g., "Rating = 'Hot'") |
| `listViewId` | string | No | `""` | Salesforce List View ID (used when filterMode = LIST_VIEW, e.g., "00B5g00000A1B2C") |
| `includeConverted` | boolean | No | `false` | Whether to include converted leads |
| `enableIncrementalSync` | boolean | No | `false` | Enable incremental sync (only fetch leads modified since last sync) |
| `lastSyncTimestamp` | string | No | `""` | Last sync timestamp in ISO 8601 format (e.g., "2025-01-17T10:30:00Z"). Used when enableIncrementalSync is true |
| `syncMode` | enum | No | `APPEND` | Sync mode: `APPEND` (add new rows), `FULL_REPLACE` (replace all data), or `UPSERT_BY_EMAIL` (update by email, append new) |
| `enableAutoFormat` | boolean | No | `true` | Enable auto-formatting (prepares sheet for manual formatting of headers) |
| `splitBy` | string | No | `""` | Split leads into multiple sheets by field (e.g., "LeadSource", "Status"). Leave empty to disable |

**Default Field Mapping:**
```
["Id", "FirstName", "LastName", "Email", "Phone", "Company", "Title", "Status", "LeadSource", "Industry", "Rating", "CreatedDate", "LastModifiedDate"]
```

**Filter Modes:**
- `SOQL`: Use custom SOQL WHERE clause via `soqlFilter` parameter. Provides maximum flexibility for complex queries.
- `LIST_VIEW`: Use existing Salesforce List View via `listViewId` parameter. Easier for non-technical users who have pre-configured List Views.

**Sync Modes:**
- `APPEND`: Adds new rows to the end of the sheet. Headers are added only if the sheet is empty. Best for cumulative historical tracking.
- `FULL_REPLACE`: Deletes the existing sheet and creates a new one with fresh data. Best for maintaining a current snapshot.
- `UPSERT_BY_EMAIL`: Updates existing leads by email and appends new ones. Requires "Email" field in `fieldMapping`. Best for maintaining up-to-date lead information without duplicates.

**Advanced Features:**

**Incremental Sync:**
When `enableIncrementalSync` is enabled, only leads modified since `lastSyncTimestamp` are fetched. This reduces API calls and data transfer.
- Set `enableIncrementalSync = true`
- After each sync, check logs for the next timestamp to use
- Update `lastSyncTimestamp` with the logged value for the next run
- Example: `lastSyncTimestamp = "2025-01-17T10:30:00Z"`

**Auto-Formatting:**
When `enableAutoFormat` is enabled, the integration prepares sheets for optimal viewing:
- Headers are placed in the first row
- Sheet structure is optimized for manual formatting
- Note: Manual bold formatting and row freezing can be applied in Google Sheets UI

**Multi-Sheet Split:**
When `splitBy` is configured, leads are automatically organized into separate sheets:
- Set `splitBy` to a field name from `fieldMapping` (e.g., "LeadSource", "Status", "Industry")
- Each unique value creates a separate sheet named "{tabName} - {value}"
- Example: If `splitBy = "Status"`, creates sheets like "Leads - Open", "Leads - Contacted", etc.
- Works with all sync modes (APPEND, FULL_REPLACE, UPSERT_BY_EMAIL)

## Deploying on WSO2 Devant

1. **Create a New Integration**
   - Log in to WSO2 Devant
   - Navigate to **Integrations** → **Create**
   - Select **Automation** integration type
   - Choose **Import from GitHub** or **Upload** this project

2. **Configure Credentials**
   - Navigate to the **Configuration** tab
   - Fill in all required Salesforce and Google OAuth credentials
   - Configure optional settings as needed

3. **Set Up Scheduling**
   - Navigate to the **Triggers** tab
   - Click **Add Trigger** → **Cron Schedule**
   - Configure the cron expression (e.g., `0 0 9 * * ?` for daily at 9 AM)
   - Save the trigger

4. **Deploy**
   - Click **Deploy** to activate the integration
   - Monitor execution logs in the **Logs** tab

5. **Test**
   - Trigger a manual execution from the **Executions** tab
   - Verify data appears in Google Sheets
   - Check logs for any errors

## Schedule Frequency Configuration

The `scheduleFrequency` parameter is **NOT** a Ballerina configurable. Instead, it must be configured via the **WSO2 Devant UI** in the Triggers section:

1. Navigate to **Integrations** → Select your integration → **Triggers** tab
2. Click **Add Trigger** → **Cron Schedule**
3. Configure the cron expression based on your desired frequency:
   - **DAILY**: `0 0 9 * * ?` (9 AM daily)
   - **WEEKLY**: `0 0 9 ? * MON` (9 AM every Monday)
   - **MONTHLY**: `0 0 9 1 * ?` (9 AM on the 1st of each month)
4. Save the trigger

You can create multiple triggers with different schedules if needed.

## Example Configuration

```toml
[salesforceConfig]
refreshToken = "your_salesforce_refresh_token"
clientId = "your_salesforce_client_id"
clientSecret = "your_salesforce_client_secret"
refreshUrl = "https://login.salesforce.com/services/oauth2/token"
baseUrl = "https://yourinstance.salesforce.com"

[googleConfig]
refreshToken = "your_google_refresh_token"
clientId = "your_google_client_id"
clientSecret = "your_google_client_secret"

spreadsheetId = "1abc123xyz456"
tabName = "Hot Leads"
timezone = "America/New_York"

# Option 1: Use SOQL filter
filterMode = "SOQL"
soqlFilter = "Rating = 'Hot'"

# Option 2: Use List View (comment out SOQL option above)
# filterMode = "LIST_VIEW"
# listViewId = "00B5g00000A1B2C"

includeConverted = false

# Advanced Features
enableIncrementalSync = false
lastSyncTimestamp = ""  # Update after each sync with logged timestamp
enableAutoFormat = true
splitBy = ""  # e.g., "LeadSource" or "Status" to split into multiple sheets

syncMode = "UPSERT_BY_EMAIL"
fieldMapping = ["Id", "FirstName", "LastName", "Email", "Phone", "Company", "Status"]
```

## License

Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com)

Licensed under the Apache License, Version 2.0.
