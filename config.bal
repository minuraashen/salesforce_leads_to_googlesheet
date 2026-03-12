// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

// Salesforce OAuth Configuration
configurable string salesforceRefreshToken = ?;
configurable string salesforceClientId = ?;
configurable string salesforceClientSecret = ?;
configurable string salesforceRefreshUrl = ?;
configurable string salesforceBaseUrl = ?;

// Google OAuth Configuration
configurable string googleRefreshToken = ?;
configurable string googleClientId = ?;
configurable string googleClientSecret = ?;

configurable string timezone = "UTC";
configurable string? spreadsheetId = ();

// Target sheet tab name
configurable string tabName = "Leads";

// Ordered list of Salesforce Lead field API names to export
configurable string[] fieldMapping = [
    "Id",
    "FirstName",
    "LastName",
    "Email",
    "Phone",
    "Company",
    "Title",
    "Status",
    "LeadSource",
    "Industry",
    "Rating",
    "CreatedDate",
    "LastModifiedDate"
];

// Lead filter mode: SOQL or LIST_VIEW
configurable LeadFilterMode filterMode = SOQL;

// Additional SOQL WHERE clause fragment (used when filterMode = SOQL)
configurable string soqlFilter = "";

// Salesforce List View ID (used when filterMode = LIST_VIEW)
configurable string listViewId = "";

// Include converted leads
configurable boolean includeConverted = false;

// Enable incremental sync (only fetch leads modified since last sync)
configurable boolean enableIncrementalSync = false;

// Last sync timestamp (ISO 8601 format, e.g., "2025-01-17T10:30:00Z")
configurable string lastSyncTimestamp = "";

// Sync mode: APPEND, FULL_REPLACE, or UPSERT_BY_EMAIL
configurable SyncMode syncMode = APPEND;

// Enable auto-formatting (bold headers, freeze first row)
configurable boolean enableAutoFormat = true;

// Split leads into multiple sheets by field (e.g., "LeadSource", "Status", or "" to disable)
configurable string splitBy = "";
