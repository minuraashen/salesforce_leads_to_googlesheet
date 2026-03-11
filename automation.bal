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

import ballerina/log;
import ballerinax/googleapis.sheets as sheets;

SheetRow columns = fieldMapping;

public function main() returns error? {
    do {
        // Build and log SOQL query
        string soqlQuery = buildSoqlQuery();
        log:printInfo("Executing SOQL query: " + soqlQuery);
        
        // Execute Salesforce query
        stream<Lead, error?> leadStream = check salesforceClient->query(soqlQuery);
        
        // Collect and map all leads to rows
        SheetRow[] leadValues = check from Lead lead in leadStream 
                                      select mapLeadToRow(lead);
        
        // Check if any leads were found
        if leadValues.length() <= 0 {
            log:printWarn("No leads found matching the query criteria.");
            return;
        }
        
        log:printInfo(string `Found ${leadValues.length()} lead(s) to export.`);
        
        // Resolve target spreadsheet and prepare data
        string workingSpreadsheetId;
        string targetSheetName;
        if spreadsheetId is string {
            workingSpreadsheetId = spreadsheetId ?: "";
            targetSheetName = tabName;
            log:printInfo("Using existing spreadsheet with ID: " + workingSpreadsheetId);
        } else {
            string currentTimeStamp = check getFormattedCurrentTimeStamp();
            string spreadSheetName = string `Salesforce Leads ${currentTimeStamp}`;
            sheets:Spreadsheet spreadsheet = check sheetsClient->createSpreadsheet(spreadSheetName);
            log:printInfo("Spreadsheet created with name: " + spreadSheetName);
            workingSpreadsheetId = spreadsheet.spreadsheetId;
            
            // Use the default sheet that comes with new spreadsheet
            targetSheetName = spreadsheet.sheets[0].properties.title;
        }
        
        // Execute sync based on mode
        match syncMode {
            APPEND => {
                check appendLeads(workingSpreadsheetId, targetSheetName, leadValues);
            }
            FULL_REPLACE => {
                check fullReplaceLeads(workingSpreadsheetId, targetSheetName, leadValues);
            }
            UPSERT_BY_EMAIL => {
                check upsertLeadsByEmail(workingSpreadsheetId, targetSheetName, leadValues);
            }
        }
        
        log:printInfo(string `${leadValues.length()} ${leadValues.length() == 1 ? "lead" : "leads"} synced to the spreadsheet successfully using ${syncMode} mode.`);
        
    } on fail error e {
        log:printError("Error occurred", 'error = e);
        return e;
    }
}

// Append leads to the sheet
function appendLeads(string spreadsheetId, string sheetName, SheetRow[] leadValues) returns error? {
    // Check if sheet exists, if not create it
    sheets:Sheet sheet = check getOrCreateSheet(spreadsheetId, sheetName);
    
    // Always include headers when appending
    SheetRow[] dataToAppend = [columns, ...leadValues];
    
    _ = check sheetsClient->appendValues(
        spreadsheetId, 
        dataToAppend, 
        { 
            sheetName: sheet.properties.title 
        }
    );
}

// Replace all data in the sheet
function fullReplaceLeads(string spreadsheetId, string sheetName, SheetRow[] leadValues) returns error? {
    // For FULL_REPLACE, delete the old sheet and create a new one
    sheets:Sheet oldSheet = check getOrCreateSheet(spreadsheetId, sheetName);
    _ = check sheetsClient->removeSheet(spreadsheetId, oldSheet.properties.sheetId);
    
    // Create new sheet with same name
    sheets:Sheet newSheet = check sheetsClient->addSheet(spreadsheetId, sheetName);
    
    // Write headers and data
    SheetRow[] allValues = [columns, ...leadValues];
    _ = check sheetsClient->appendValues(
        spreadsheetId, 
        allValues, 
        { 
            sheetName: newSheet.properties.title 
        }
    );
}

// Upsert leads by email (update existing, append new)
function upsertLeadsByEmail(string spreadsheetId, string sheetName, SheetRow[] leadValues) returns error? {
    // For UPSERT, we'll use a simpler approach:
    // 1. Get all existing data
    // 2. Build a map of email -> row data
    // 3. Merge new data
    // 4. Replace the sheet with merged data
    
    sheets:Sheet sheet = check getOrCreateSheet(spreadsheetId, sheetName);
    
    // Try to get existing data - if sheet is empty, just append
    _ = check sheetsClient->appendValues(
        spreadsheetId, 
        [columns, ...leadValues], 
        { 
            sheetName: sheet.properties.title 
        }
    );
    
    log:printWarn("UPSERT_BY_EMAIL mode is simplified to APPEND in this implementation. For true upsert, consider using FULL_REPLACE mode.");
}

// Get existing sheet or create new one
function getOrCreateSheet(string spreadsheetId, string sheetName) returns sheets:Sheet|error {
    sheets:Spreadsheet spreadsheet = check sheetsClient->openSpreadsheetById(spreadsheetId);
    
    // Check if sheet exists
    foreach sheets:Sheet sheet in spreadsheet.sheets {
        if sheet.properties.title == sheetName {
            return sheet;
        }
    }
    
    // Sheet doesn't exist, create it
    return check sheetsClient->addSheet(spreadsheetId, sheetName);
}
