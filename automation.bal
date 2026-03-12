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
        string soqlQuery = check buildSoqlQuery();
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
        string targetSheetName = tabName;
        string trimmedSpreadsheetId = spreadsheetId.trim();
        
        if trimmedSpreadsheetId != "" {
            // Use existing spreadsheet
            workingSpreadsheetId = trimmedSpreadsheetId;
            log:printInfo("Using existing spreadsheet with ID: " + workingSpreadsheetId);
        } else {
            // Create new spreadsheet
            string currentTimeStamp = check getFormattedCurrentTimeStamp();
            string spreadSheetName = string `Salesforce Leads ${currentTimeStamp}`;
            sheets:Spreadsheet spreadsheet = check sheetsClient->createSpreadsheet(spreadSheetName);
            log:printInfo("Spreadsheet created with name: " + spreadSheetName);
            workingSpreadsheetId = spreadsheet.spreadsheetId;
        }
        
        // Determine effective sync mode (default to APPEND if empty)
        string effectiveSyncMode = syncMode.trim() == "" ? "APPEND" : syncMode;
        
        // Validate sync mode compatibility
        boolean isNewSpreadsheet = trimmedSpreadsheetId == "";
        
        // UPSERT_BY_EMAIL requires an existing spreadsheet to compare and update data
        if isNewSpreadsheet && effectiveSyncMode == "UPSERT_BY_EMAIL" {
            return error("UPSERT_BY_EMAIL mode requires an existing spreadsheet (spreadsheetId must be provided). This mode updates existing leads by email and cannot work with a new spreadsheet. Use APPEND or FULL_REPLACE mode for new spreadsheets.");
        }
        
        // Execute sync based on mode and split configuration
        if splitBy != "" {
            // Split leads into multiple sheets
            check syncLeadsSplit(workingSpreadsheetId, targetSheetName, leadValues, effectiveSyncMode, isNewSpreadsheet);
        } else {
            // Single sheet sync
            if effectiveSyncMode == "APPEND" {
                check appendLeads(workingSpreadsheetId, targetSheetName, leadValues, isNewSpreadsheet);
            } else if effectiveSyncMode == "FULL_REPLACE" {
                check fullReplaceLeads(workingSpreadsheetId, targetSheetName, leadValues, isNewSpreadsheet);
            } else if effectiveSyncMode == "UPSERT_BY_EMAIL" {
                check upsertLeadsByEmail(workingSpreadsheetId, targetSheetName, leadValues);
            } else {
                return error(string `Invalid syncMode: ${effectiveSyncMode}. Must be "APPEND", "FULL_REPLACE", or "UPSERT_BY_EMAIL"`);
            }
        }
        
        log:printInfo(string `${leadValues.length()} ${leadValues.length() == 1 ? "lead" : "leads"} synced to the spreadsheet successfully using ${effectiveSyncMode} mode.`);
        
        // Log incremental sync info
        if enableIncrementalSync {
            string currentTimestamp = check getCurrentTimestamp();
            log:printInfo(string `Incremental sync completed. Next sync should use lastSyncTimestamp: "${currentTimestamp}"`);
        }
        
    } on fail error e {
        log:printError("Error occurred", 'error = e);
        return e;
    }
}

// Append leads to a new sheet with timestamped name
function appendLeads(string spreadsheetId, string sheetName, SheetRow[] leadValues, boolean isNewSpreadsheet) returns error? {
    sheets:Sheet targetSheet;
    string newSheetName;
    
    if isNewSpreadsheet {
        // For new spreadsheet, use and rename the default sheet
        sheets:Spreadsheet spreadsheet = check sheetsClient->openSpreadsheetById(spreadsheetId);
        sheets:Sheet defaultSheet = spreadsheet.sheets[0];
        
        // Create timestamped sheet name
        string currentTimeStamp = check getFormattedCurrentTimeStamp();
        newSheetName = string `${sheetName} ${currentTimeStamp}`;
        
        // Rename the default sheet
        int sheetId = defaultSheet.properties.sheetId;
        _ = check sheetsClient->renameSheet(spreadsheetId, sheetId.toString(), newSheetName);
        log:printInfo(string `Renamed default sheet to: ${newSheetName}`);
        
        // Fetch the updated sheet to get the correct structure
        sheets:Spreadsheet updatedSpreadsheet = check sheetsClient->openSpreadsheetById(spreadsheetId);
        targetSheet = updatedSpreadsheet.sheets[0];
    } else {
        // For existing spreadsheet, create a new sheet with timestamped name
        string currentTimeStamp = check getFormattedCurrentTimeStamp();
        newSheetName = string `${sheetName} ${currentTimeStamp}`;
        
        targetSheet = check sheetsClient->addSheet(spreadsheetId, newSheetName);
        log:printInfo(string `Created new sheet: ${newSheetName}`);
    }
    
    // Prepare data with headers
    SheetRow[] dataToAppend = [columns, ...leadValues];
    
    // Append data to the sheet
    _ = check sheetsClient->appendValues(spreadsheetId, dataToAppend, {sheetName: targetSheet.properties.title});
    
    // Apply formatting to sheet
    check applySheetFormatting(spreadsheetId, targetSheet.properties.sheetId);
}

// Replace all data in the sheet
function fullReplaceLeads(string spreadsheetId, string sheetName, SheetRow[] leadValues, boolean isNewSpreadsheet) returns error? {
    // Prepare all data (headers + leads)
    SheetRow[] allValues = [columns, ...leadValues];
    
    if isNewSpreadsheet {
        // For new spreadsheet, use and rename the default sheet to the target sheet name
        sheets:Spreadsheet spreadsheet = check sheetsClient->openSpreadsheetById(spreadsheetId);
        sheets:Sheet defaultSheet = spreadsheet.sheets[0];
        
        // Rename the default sheet to the target sheet name (no timestamp)
        int sheetId = defaultSheet.properties.sheetId;
        _ = check sheetsClient->renameSheet(spreadsheetId, sheetId.toString(), sheetName);
        log:printInfo(string `Renamed default sheet to: ${sheetName}`);
        
        // Fetch the updated sheet
        sheets:Spreadsheet updatedSpreadsheet = check sheetsClient->openSpreadsheetById(spreadsheetId);
        sheets:Sheet targetSheet = updatedSpreadsheet.sheets[0];
        
        // Write headers and data
        _ = check sheetsClient->appendValues(spreadsheetId, allValues, {sheetName: targetSheet.properties.title});
        
        // Apply formatting
        check applySheetFormatting(spreadsheetId, targetSheet.properties.sheetId);
    } else {
        // For existing spreadsheet, delete ALL sheets and create a fresh new sheet
        sheets:Spreadsheet spreadsheet = check sheetsClient->openSpreadsheetById(spreadsheetId);
        
        log:printInfo(string `Deleting all ${spreadsheet.sheets.length()} existing sheet(s) from the spreadsheet.`);
        
        // Create a temporary sheet first (Google Sheets requires at least one sheet)
        sheets:Sheet tempSheet = check sheetsClient->addSheet(spreadsheetId, "TempSheet_DeleteMe");
        
        // Delete all original sheets
        foreach sheets:Sheet sheet in spreadsheet.sheets {
            _ = check sheetsClient->removeSheet(spreadsheetId, sheet.properties.sheetId);
        }
        
        // Create new sheet with target name
        sheets:Sheet newSheet = check sheetsClient->addSheet(spreadsheetId, sheetName);
        
        // Write headers and data
        _ = check sheetsClient->appendValues(spreadsheetId, allValues, {sheetName: newSheet.properties.title});
        
        // Apply formatting
        check applySheetFormatting(spreadsheetId, newSheet.properties.sheetId);
        
        // Delete the temporary sheet
        _ = check sheetsClient->removeSheet(spreadsheetId, tempSheet.properties.sheetId);
        
        log:printInfo(string `All existing sheets deleted. Created fresh sheet: ${sheetName}`);
    }
}

// Upsert leads by email (update existing, append new)
function upsertLeadsByEmail(string spreadsheetId, string sheetName, SheetRow[] leadValues) returns error? {
    sheets:Sheet sheet = check getOrCreateSheet(spreadsheetId, sheetName);
    
    // Check if sheet is empty
    boolean isEmpty = check isSheetEmpty(spreadsheetId, sheet.properties.title);
    
    if isEmpty {
        // If sheet is empty, just append headers and data
        SheetRow[] dataToAppend = [columns, ...leadValues];
        _ = check sheetsClient->appendValues(spreadsheetId, dataToAppend, {sheetName: sheet.properties.title});
        check applySheetFormatting(spreadsheetId, sheet.properties.sheetId);
        log:printInfo("Sheet is empty. Added headers and all leads.");
        return;
    }
    
    // Get existing data from sheet
    sheets:Range existingRange = check sheetsClient->getRange(spreadsheetId, sheet.properties.title, a1Notation = "A:Z");
    (int|string|decimal)[][] existingValues = existingRange.values;
    
    if existingValues.length() <= 1 {
        // Only headers exist, append all data
        _ = check sheetsClient->appendValues(spreadsheetId, leadValues, {sheetName: sheet.properties.title});
        log:printInfo("Only headers found. Appended all leads.");
        return;
    }
    
    // Find email column index
    int emailColumnIndex = getEmailColumnIndex();
    
    if emailColumnIndex == -1 {
        log:printWarn("Email field not found in fieldMapping. Falling back to APPEND mode.");
        _ = check sheetsClient->appendValues(spreadsheetId, leadValues, {sheetName: sheet.properties.title});
        return;
    }
    
    // Build ordered list of existing rows with email tracking
    SheetRow[] existingRows = [];
    map<int> emailToRowIndex = {};
    
    int rowIndex = 0;
    foreach (int|string|decimal)[] row in existingValues.slice(1) {
        SheetRow convertedRow = [];
        foreach (int|string|decimal) cell in row {
            convertedRow.push(cell);
        }
        
        // Track email to row index mapping
        if row.length() > emailColumnIndex {
            (int|string|decimal) emailValue = row[emailColumnIndex];
            string email = emailValue.toString();
            if email != "" {
                emailToRowIndex[email] = rowIndex;
            }
        }
        
        existingRows.push(convertedRow);
        rowIndex = rowIndex + 1;
    }
    
    // Process new leads: update existing or collect new ones
    SheetRow[] newLeads = [];
    int updatedCount = 0;
    
    foreach SheetRow leadRow in leadValues {
        if leadRow.length() > emailColumnIndex {
            int|string|decimal|boolean|float emailValue = leadRow[emailColumnIndex];
            string email = emailValue.toString();
            
            if email != "" && emailToRowIndex.hasKey(email) {
                // Update existing row in place
                int existingRowIndex = emailToRowIndex.get(email);
                existingRows[existingRowIndex] = leadRow;
                updatedCount = updatedCount + 1;
            } else {
                // Collect new lead for appending
                newLeads.push(leadRow);
            }
        } else {
            // No email, append as new
            newLeads.push(leadRow);
        }
    }
    
    // Rebuild all data with updates (preserving original order)
    SheetRow[] allData = [columns];
    foreach SheetRow row in existingRows {
        allData.push(row);
    }
    
    // Clear sheet and write updated data
    _ = check sheetsClient->clearRange(spreadsheetId, sheet.properties.title, a1Notation = "A:Z");
    _ = check sheetsClient->appendValues(spreadsheetId, allData, {sheetName: sheet.properties.title});
    
    // Apply formatting after clearing and rewriting
    check applySheetFormatting(spreadsheetId, sheet.properties.sheetId);
    
    // Append new leads
    if newLeads.length() > 0 {
        _ = check sheetsClient->appendValues(spreadsheetId, newLeads, {sheetName: sheet.properties.title});
    }
    
    log:printInfo(string `UPSERT completed: ${updatedCount} lead(s) updated, ${newLeads.length()} new lead(s) added.`);
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

// Check if sheet is empty
function isSheetEmpty(string spreadsheetId, string sheetName) returns boolean|error {
    sheets:Range|error result = sheetsClient->getRange(spreadsheetId, sheetName, "A1:A1");
    
    if result is error {
        // If error occurs, assume sheet is empty
        return true;
    }
    
    sheets:Range range = result;
    // Check if values array is empty or first cell is empty
    if range.values.length() == 0 {
        return true;
    }
    
    (int|string|decimal)[] firstRow = range.values[0];
    if firstRow.length() == 0 {
        return true;
    }
    
    return false;
}

// Get email column index from fieldMapping
function getEmailColumnIndex() returns int {
    int index = 0;
    foreach string fieldName in fieldMapping {
        if fieldName == "Email" {
            return index;
        }
        index = index + 1;
    }
    return -1;
}

// Sync leads split into multiple sheets by a field
function syncLeadsSplit(string spreadsheetId, string baseSheetName, SheetRow[] leadValues, string mode, boolean isNewSpreadsheet) returns error? {
    // Find the split field column index
    int splitFieldIndex = getSplitFieldIndex();
    
    if splitFieldIndex == -1 {
        log:printWarn(string `Split field "${splitBy}" not found in fieldMapping. Falling back to single sheet sync.`);
        if mode == "APPEND" {
            check appendLeads(spreadsheetId, baseSheetName, leadValues, isNewSpreadsheet);
        } else if mode == "FULL_REPLACE" {
            check fullReplaceLeads(spreadsheetId, baseSheetName, leadValues, isNewSpreadsheet);
        } else if mode == "UPSERT_BY_EMAIL" {
            check upsertLeadsByEmail(spreadsheetId, baseSheetName, leadValues);
        }
        return;
    }
    
    // Group leads by split field value
    map<SheetRow[]> groupedLeads = {};
    
    foreach SheetRow leadRow in leadValues {
        if leadRow.length() > splitFieldIndex {
            int|string|decimal|boolean|float fieldValue = leadRow[splitFieldIndex];
            string groupKey = fieldValue.toString();
            
            if groupKey == "" {
                groupKey = "Unknown";
            }
            
            if !groupedLeads.hasKey(groupKey) {
                groupedLeads[groupKey] = [];
            }
            
            SheetRow[] existingGroup = groupedLeads.get(groupKey);
            existingGroup.push(leadRow);
            groupedLeads[groupKey] = existingGroup;
        }
    }
    
    // Sync each group to its own sheet
    boolean isFirstGroup = true;
    foreach string groupKey in groupedLeads.keys() {
        SheetRow[] groupLeads = groupedLeads.get(groupKey);
        string sheetName = string `${baseSheetName} - ${groupKey}`;
        
        log:printInfo(string `Syncing ${groupLeads.length()} lead(s) to sheet: ${sheetName}`);
        
        if mode == "APPEND" {
            // Only the first group uses the default sheet if it's a new spreadsheet
            check appendLeads(spreadsheetId, sheetName, groupLeads, isNewSpreadsheet && isFirstGroup);
            isFirstGroup = false;
        } else if mode == "FULL_REPLACE" {
            // Only the first group uses the default sheet if it's a new spreadsheet
            check fullReplaceLeads(spreadsheetId, sheetName, groupLeads, isNewSpreadsheet && isFirstGroup);
            isFirstGroup = false;
        } else if mode == "UPSERT_BY_EMAIL" {
            check upsertLeadsByEmail(spreadsheetId, sheetName, groupLeads);
        }
    }
    
    log:printInfo(string `Split sync completed. Created/updated ${groupedLeads.keys().length()} sheet(s) based on ${splitBy}.`);
}

// Get split field column index from fieldMapping
function getSplitFieldIndex() returns int {
    int index = 0;
    foreach string fieldName in fieldMapping {
        if fieldName == splitBy {
            return index;
        }
        index = index + 1;
    }
    return -1;
}

// Apply formatting to sheet (bold headers, freeze first row)
function applySheetFormatting(string spreadsheetId, int sheetId) returns error? {
    if !enableAutoFormat {
        return;
    }
    
    // Note: Advanced formatting (bold, freeze) requires Google Sheets API batchUpdate
    // which is not directly available in the current connector version.
    // This is a placeholder for future enhancement when the API is available.
    // For now, we log that formatting would be applied.
    
    log:printInfo("Auto-formatting enabled. Headers will appear in first row (manual formatting recommended for bold/freeze).");
    
    // Future implementation would use:
    // - batchUpdate API with repeatCell request for bold headers
    // - updateSheetProperties request for frozen rows
}
