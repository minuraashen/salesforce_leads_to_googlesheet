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

configurable record {
    string refreshToken;
    string clientId;
    string clientSecret;
    string refreshUrl;
    string baseUrl;
} salesforceConfig = ?;

configurable record {
    string refreshToken;
    string clientId;
    string clientSecret;
} googleConfig = ?;

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

// Additional SOQL WHERE clause fragment
configurable string soqlFilter = "";

// Include converted leads
configurable boolean includeConverted = false;

// Sync mode: APPEND, FULL_REPLACE, or UPSERT_BY_EMAIL
configurable SyncMode syncMode = APPEND;
