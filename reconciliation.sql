-- Comm-Log Send Reconciliation
-- Finance target_base:
-- Merchant 501, October 2026, Diwali campaigns
-- Expected result: 22


------------------------------------------------------------
-- 1. NAIVE COUNT
------------------------------------------------------------

SELECT COUNT(*) AS naive_count
FROM communication_log;


------------------------------------------------------------
-- 2. ELIGIBLE COMMUNICATION LOG ROWS
--
-- A campaign is reportable only when:
-- creation_status is finalized
-- AND processing_status = processed
------------------------------------------------------------

SELECT COUNT(*) AS eligible_attempts
FROM communication_log cl
JOIN campaign c
    ON c.id = cl.communication_id
WHERE c.merchant_id = 501
  AND c.creation_status IN (
      'approved',
      'aborted',
      'resumed',
      'stopped'
  )
  AND c.processing_status = 'processed';


------------------------------------------------------------
-- 3. BUILD RETRY FAMILIES
--
-- parent_id defines the retry relationship.
-- Recursive CTE allows chains deeper than one level.
------------------------------------------------------------

WITH RECURSIVE campaign_tree AS (

    -- Root campaigns
    SELECT
        id AS campaign_id,
        id AS root_id
    FROM campaign
    WHERE parent_id IS NULL

    UNION ALL

    -- Follow retry relationships
    SELECT
        c.id AS campaign_id,
        ct.root_id
    FROM campaign c
    JOIN campaign_tree ct
        ON c.parent_id = ct.campaign_id
)

SELECT *
FROM campaign_tree
ORDER BY root_id, campaign_id;


------------------------------------------------------------
-- 4. FINAL TARGET_BASE
------------------------------------------------------------

WITH RECURSIVE campaign_tree AS (

    SELECT
        id AS campaign_id,
        id AS root_id
    FROM campaign
    WHERE parent_id IS NULL

    UNION ALL

    SELECT
        c.id AS campaign_id,
        ct.root_id
    FROM campaign c
    JOIN campaign_tree ct
        ON c.parent_id = ct.campaign_id
),

eligible_logs AS (

    SELECT
        cl.id,
        cl.customer_id,
        cl.communication_id,
        ct.root_id
    FROM communication_log cl

    JOIN campaign c
        ON c.id = cl.communication_id

    JOIN campaign_tree ct
        ON ct.campaign_id = cl.communication_id

    WHERE c.merchant_id = 501
      AND c.creation_status IN (
          'approved',
          'aborted',
          'resumed',
          'stopped'
      )
      AND c.processing_status = 'processed'

      AND cl.merchant_id = 501
      AND cl.communication_type = '2'

      AND cl.sent_time >= '2026-10-01'
      AND cl.sent_time < '2026-11-01'
),

retry_roots AS (

    SELECT
        root_id
    FROM campaign_tree
    GROUP BY root_id
    HAVING COUNT(*) > 1
),

retry_family_count AS (

    SELECT
        COUNT(DISTINCT el.customer_id) AS count_value
    FROM eligible_logs el
    JOIN retry_roots rr
        ON rr.root_id = el.root_id
),

standalone_count AS (

    SELECT
        COUNT(*) AS count_value
    FROM eligible_logs el
    LEFT JOIN retry_roots rr
        ON rr.root_id = el.root_id
    WHERE rr.root_id IS NULL
)

SELECT
    (SELECT count_value FROM retry_family_count)
    +
    (SELECT count_value FROM standalone_count)
    AS target_base;
