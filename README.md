# Comm-Log Send Reconciliation

## Objective

Reproduce Finance's target_base of 22 for:

- Merchant: 501
- Period: October 2026
- Campaigns: Diwali
- Communication type: Campaign (`2`)

## Data

The repository contains:

- `data/comm_log.db`
- `data/campaign.csv`
- `data/communication_log.csv`

## Approach

The reconciliation was performed in three stages:

1. Start with the naive count of communication-log rows.
2. Apply campaign reporting eligibility.
3. Reconcile retry chains while preserving legitimate repeated
   sends from standalone campaigns.

## Reconciliation Bridge

| Step | Description | Result | Reason |
|---|---|---:|---|
| 0 | Naive count | 30 | All raw communication-log rows |
| 1 | Apply campaign eligibility | 26 | Exclude 4 rows from campaign 9004 |
| 2 | Reconcile retry chains | 22 | Deduplicate customers within retry families |
| Final | Finance target_base | 22 | Reconciled |

## Retry Family Breakdown

| Family | Raw Attempts | Qualifying Sends |
|---|---:|---:|
| 9001 → 9002 → 9003 | 13 | 10 |
| 9101 standalone | 7 | 7 |
| 9201 → 9202 | 6 | 5 |
| **Total** | **26** | **22** |

## Key Findings

### Pending campaign

Campaign 9004 has communication-log rows but is still
`approval_awaiting`, so its four rows are excluded.

### Retry chains

A customer appearing across campaigns in the same retry chain
represents one underlying communication.

### Standalone campaign

Repeated customers within standalone campaign 9101 are separate
events and should not be globally deduplicated.

## Result

The reconciled Finance `target_base` is:

**22**
