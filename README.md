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

## Getting Your Spreadsheet ID

To use an existing Google Spreadsheet:

1. Open your Google Spreadsheet in a browser
2. Look at the URL in the address bar
3. The spreadsheet ID is the long string between `/d/` and `/edit`

**Example URL:**
```
https://docs.google.com/spreadsheets/d/1abc123xyz456def789ghi012jkl345mno678pqr/edit#gid=0
                                      ↑_____________________________________↑
                                              This is your spreadsheet ID
```

4. Copy this ID and use it in your `spreadsheetId` configuration

**Note:** If you don't provide a spreadsheet ID (or leave it empty), the integration will automatically create a new spreadsheet with a timestamped name each time it runs.

## Configuration

| Configuration | Type | Required | Default | Description |
|--------------|------|----------|---------|-------------|
| `salesforceRefreshToken` | string | Yes | - | Salesforce OAuth refresh token |
| `salesforceClientId` | string | Yes | - | Salesforce OAuth client ID |
| `salesforceClientSecret` | string | Yes | - | Salesforce OAuth client secret |
| `salesforceRefreshUrl` | string | Yes | - | Salesforce token refresh URL (e.g., `https://login.salesforce.com/services/oauth2/token`) |
| `salesforceBaseUrl` | string | Yes | - | Salesforce instance base URL (e.g., `https://yourinstance.salesforce.com`) |
| `googleRefreshToken` | string | Yes | - | Google OAuth refresh token |
| `googleClientId` | string | Yes | - | Google OAuth client ID |
| `googleClientSecret` | string | Yes | - | Google OAuth client secret |
| `spreadsheetId` | string | No | `()` | Target spreadsheet ID (e.g., "1abc123xyz456"). If provided, uses the existing spreadsheet. If not provided or empty, creates a new timestamped spreadsheet |
| `tabName` | string | No | `"Leads"` | Target sheet tab name within the spreadsheet |
| `timezone` | string | No | `"UTC"` | IANA timezone string for spreadsheet timestamp naming (e.g., "America/New_York", "Asia/Colombo") |
| `fieldMapping` | string[] | No | See below | Ordered list of Salesforce Lead field API names to export |
| `soqlFilter` | string | No | `""` | Additional SOQL WHERE clause fragment for filtering leads (e.g., "Rating = 'Hot' AND LeadSource = 'Web'") |
| `includeConverted` | boolean | No | `false` | Whether to include converted leads |
| `enableIncrementalSync` | boolean | No | `false` | Enable incremental sync (only fetch leads modified since last sync) |
| `lastSyncTimestamp` | string | No | `""` | Last sync timestamp in ISO 8601 format (e.g., "2025-01-17T10:30:00Z"). Used when enableIncrementalSync is true |
| `syncMode` | string | No | `"APPEND"` | Sync mode: `"APPEND"` (add new rows), `"FULL_REPLACE"` (replace all data), or `"UPSERT_BY_EMAIL"` (update by email, append new). If left empty or not specified, defaults to `"APPEND"` |
| `enableAutoFormat` | boolean | No | `true` | Enable auto-formatting (prepares sheet for manual formatting of headers) |
| `splitBy` | string | No | `""` | Split leads into multiple sheets by field (e.g., "LeadSource", "Status"). Leave empty to disable |

**Default Field Mapping:**
```
["Id", "FirstName", "LastName", "Email", "Phone", "Company", "Title", "Status", "LeadSource", "Industry", "Rating", "CreatedDate", "LastModifiedDate"]
```

**SOQL Filtering:**

Use the `soqlFilter` parameter to add custom WHERE clause conditions to filter leads. This provides maximum flexibility for complex queries.

**Examples:**
- Single condition: `soqlFilter = "Rating = 'Hot'"`
- Multiple conditions: `soqlFilter = "Rating = 'Hot' AND LeadSource = 'Web'"`
- Date filters: `soqlFilter = "CreatedDate > 2025-01-01"`
- Complex queries: `soqlFilter = "(Rating = 'Hot' OR Rating = 'Warm') AND Industry = 'Technology'"`

**Filtering Options:**
- Use `soqlFilter` to add custom WHERE clause conditions
- Set `includeConverted = true` to include converted leads (default is `false`)
- Combine both for precise filtering

**Sync Modes:**

The integration supports three sync modes. Choose based on your use case:

**1. APPEND Mode (Default)**
- **What it does**: Adds new rows to the end of the sheet without modifying existing data
- **When to use**: 
  - Creating a new spreadsheet OR using an existing one
  - Building a historical log of all leads over time
  - You want to keep all records, including duplicates
- **Requirements**: None (works with or without `spreadsheetId`)
- **Behavior**: 
  - If sheet is empty: Adds headers + data
  - If sheet has data: Appends new rows only
- **Example use case**: Daily export of new leads for historical tracking

**2. FULL_REPLACE Mode**
- **What it does**: Completely replaces all data in the sheet with fresh data from Salesforce
- **When to use**:
  - Creating a new spreadsheet OR using an existing one
  - You want a current snapshot (not historical data)
  - You need to refresh the entire dataset
- **Requirements**: None (works with or without `spreadsheetId`)
- **Behavior**:
  - Clears all existing data in the sheet
  - Writes fresh headers + current data
  - If it's the only sheet in spreadsheet: Clears and rewrites data
  - If multiple sheets exist: Deletes and recreates the sheet
- **Example use case**: Weekly refresh of all open leads

**3. UPSERT_BY_EMAIL Mode**
- **What it does**: Updates existing leads (matched by email) and adds new ones
- **When to use**:
  - You want to keep data up-to-date without duplicates
  - You need to track changes to existing leads
  - You're syncing the same leads repeatedly
- **Requirements**:
  - ⚠️ **MUST provide `spreadsheetId`** (requires existing spreadsheet to compare data)
  - ⚠️ **MUST include "Email" in `fieldMapping`**
  - Leads are matched by email address
- **Behavior**:
  - If email exists: Updates that row with new data
  - If email is new: Appends as new row
  - If no email: Appends as new row
- **Example use case**: Daily sync to keep lead status and details current

**Quick Decision Guide:**

| Scenario | Recommended Mode | Requires spreadsheetId? |
|----------|------------------|-------------------------|
| Creating new spreadsheet each time | `APPEND` or `FULL_REPLACE` | No |
| Want historical log of all leads | `APPEND` | No |
| Want current snapshot, replace old data | `FULL_REPLACE` | No |
| Want to update existing leads, avoid duplicates | `UPSERT_BY_EMAIL` | **Yes** |
| Syncing same leads daily to track changes | `UPSERT_BY_EMAIL` | **Yes** |

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
# Salesforce OAuth Configuration
salesforceRefreshToken = "your_salesforce_refresh_token"
salesforceClientId = "your_salesforce_client_id"
salesforceClientSecret = "your_salesforce_client_secret"
salesforceRefreshUrl = "https://login.salesforce.com/services/oauth2/token"
salesforceBaseUrl = "https://yourinstance.salesforce.com"

# Google OAuth Configuration
googleRefreshToken = "your_google_refresh_token"
googleClientId = "your_google_client_id"
googleClientSecret = "your_google_client_secret"

# Spreadsheet Configuration
# Option 1: Use existing spreadsheet (required for UPSERT_BY_EMAIL mode)
spreadsheetId = "1abc123xyz456"  # Replace with your actual spreadsheet ID

# Option 2: Create new spreadsheet each time (works with APPEND and FULL_REPLACE modes)
# spreadsheetId = ""  # Leave empty or comment out

tabName = "Hot Leads"
timezone = "America/New_York"

# Filter Configuration
soqlFilter = "Rating = 'Hot' AND LeadSource = 'Web'"
includeConverted = false

# Sync Mode Configuration
# Choose based on your use case:
# - APPEND: Add new rows (works with new or existing spreadsheets)
# - FULL_REPLACE: Replace all data (requires existing spreadsheetId)
# - UPSERT_BY_EMAIL: Update existing + add new (requires existing spreadsheetId and "Email" in fieldMapping)
syncMode = "UPSERT_BY_EMAIL"

# Field Mapping (MUST include "Email" if using UPSERT_BY_EMAIL mode)
fieldMapping = ["Id", "FirstName", "LastName", "Email", "Phone", "Company", "Status"]

# Advanced Features
enableIncrementalSync = false
lastSyncTimestamp = ""  # Update after each sync with logged timestamp
enableAutoFormat = true
splitBy = ""  # e.g., "LeadSource" or "Status" to split into multiple sheets
```

## License

Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com)

Licensed under the Apache License, Version 2.0.
