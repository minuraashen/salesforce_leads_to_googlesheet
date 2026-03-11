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

import ballerina/time;

// Get formatted current timestamp in the configured timezone
public function getFormattedCurrentTimeStamp() returns string|error {
    time:Zone? zone = time:getZone(timezone);
    if zone is time:Zone {
        time:Civil currentTime = zone.utcToCivil(time:utcNow());
        return string 
            `${currentTime.year.toString()}-${currentTime.month.toString().padZero(2)}-${currentTime.day.toString().padZero(2)} ${currentTime.hour.toString().padZero(2)}:${currentTime.minute.toString().padZero(2)}`;
    }
    return error("Invalid time zone");
}

// Build SOQL query based on configuration
public function buildSoqlQuery() returns string|error {
    string selectClause = string:'join(", ", ...fieldMapping);
    string query = string `SELECT ${selectClause} FROM Lead`;
    
    string[] whereConditions = [];
    
    // Apply filter based on mode
    match filterMode {
        SOQL => {
            // Filter out converted leads if configured
            if !includeConverted {
                whereConditions.push("IsConverted = false");
            }
            
            // Add custom SOQL filter if provided
            if soqlFilter != "" {
                whereConditions.push(soqlFilter);
            }
        }
        LIST_VIEW => {
            // Validate list view ID is provided
            if listViewId == "" {
                return error("List View ID is required when filterMode is LIST_VIEW");
            }
            
            // Use list view filtering
            whereConditions.push(string `Id IN (SELECT Id FROM Lead WHERE Id IN (SELECT WhatId FROM ListView WHERE Id = '${listViewId}'))`);
            
            // Filter out converted leads if configured
            if !includeConverted {
                whereConditions.push("IsConverted = false");
            }
        }
    }
    
    // Combine WHERE conditions
    if whereConditions.length() > 0 {
        string whereClause = string:'join(" AND ", ...whereConditions);
        query = string `${query} WHERE ${whereClause}`;
    }
    
    return query;
}
