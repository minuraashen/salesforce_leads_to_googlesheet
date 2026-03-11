# Integration Flow Diagram

```mermaid
flowchart TD
    Start([Begin Export]):::startNode
    BuildQuery[Build SOQL Query]:::processNode
    FetchLeads[Fetch Leads from Salesforce]:::processNode
    CheckLeads{Leads Found?}:::decisionNode
    NoLeads[Log Warning & Exit]:::processNode
    ResolveSheet[Resolve Target Spreadsheet]:::processNode
    CheckSplit{Split by Field?}:::decisionNode
    GroupLeads[Group Leads by Field Value]:::processNode
    WriteSingle[Write to Single Tab]:::processNode
    WriteMultiple[Write to Multiple Tabs]:::processNode
    FormatHeaders[Format Headers & Freeze Row 1]:::processNode
    Complete([Export Complete]):::endNode

    Start --> BuildQuery
    BuildQuery --> FetchLeads
    FetchLeads --> CheckLeads
    CheckLeads -->|No| NoLeads
    NoLeads --> Complete
    CheckLeads -->|Yes| ResolveSheet
    ResolveSheet --> CheckSplit
    CheckSplit -->|NONE| WriteSingle
    CheckSplit -->|LeadSource or Status| GroupLeads
    GroupLeads --> WriteMultiple
    WriteSingle --> FormatHeaders
    WriteMultiple --> FormatHeaders
    FormatHeaders --> Complete

    classDef startNode fill:#90EE90,stroke:#333,stroke-width:2px,color:#000
    classDef endNode fill:#FFB6C1,stroke:#333,stroke-width:2px,color:#000
    classDef processNode fill:#87CEEB,stroke:#333,stroke-width:2px,color:#000
    classDef decisionNode fill:#FFD700,stroke:#333,stroke-width:2px,color:#000
```

## Flow Description

1. **Begin Export**: Integration starts execution
2. **Build SOQL Query**: Constructs SOQL query based on configuration (field mapping, filters, incremental sync)
3. **Fetch Leads**: Queries Salesforce for Lead records
4. **Leads Found?**: Checks if any leads match the query criteria
5. **Log Warning & Exit**: If no leads found, logs warning and exits gracefully
6. **Resolve Target Spreadsheet**: Uses existing spreadsheet ID or creates new one
7. **Split by Field?**: Checks if leads should be split into multiple tabs
8. **Group Leads**: Groups leads by LeadSource or Status field value
9. **Write to Single Tab**: Writes all leads to configured tab name
10. **Write to Multiple Tabs**: Writes each group to separate tabs
11. **Format Headers & Freeze Row 1**: Applies formatting to spreadsheet
12. **Export Complete**: Integration execution completes successfully
