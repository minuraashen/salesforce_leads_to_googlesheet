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

// Map a Salesforce Lead record to a Google Sheets row
public function mapLeadToRow(Lead lead) returns SheetRow {
    map<int|string|decimal|boolean|float> leadMap = {
        "Id": lead?.Id ?: "",
        "FirstName": lead?.FirstName ?: "",
        "LastName": lead?.LastName ?: "",
        "Email": lead?.Email ?: "",
        "Phone": lead?.Phone ?: "",
        "Company": lead?.Company ?: "",
        "Title": lead?.Title ?: "",
        "Status": lead?.Status ?: "",
        "LeadSource": lead?.LeadSource ?: "",
        "Industry": lead?.Industry ?: "",
        "Rating": lead?.Rating ?: "",
        "OwnerId": lead?.OwnerId ?: "",
        "Description": lead?.Description ?: "",
        "Website": lead?.Website ?: "",
        "Country": lead?.Country ?: "",
        "City": lead?.City ?: "",
        "State": lead?.State ?: "",
        "IsConverted": lead?.IsConverted ?: false,
        "ConvertedDate": lead?.ConvertedDate ?: "",
        "CreatedDate": lead?.CreatedDate ?: "",
        "LastModifiedDate": lead?.LastModifiedDate ?: "",
        "LastActivityDate": lead?.LastActivityDate ?: "",
        "NumberOfEmployees": lead?.NumberOfEmployees ?: 0,
        "AnnualRevenue": lead?.AnnualRevenue ?: 0.0
    };

    SheetRow row = [];
    foreach string fieldName in fieldMapping {
        int|string|decimal|boolean|float fieldValue = leadMap.hasKey(fieldName) ? leadMap.get(fieldName) : "";
        row.push(fieldValue);
    }
    return row;
}
