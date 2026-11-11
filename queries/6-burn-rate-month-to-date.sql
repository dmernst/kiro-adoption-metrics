-- 6 - Burn rate (month to date)
-- Database: kiro_usage (Glue), table: user_report
-- Individual subscriptions with overage DISABLED only. Excludes subscription_tier = 'POOLING' (credit sharing reports overage_cap = 0).
-- Credit sharing: no per-user cap; use the Kiro console Credit sharing dashboard.
-- IMPORTANT: assumes the billing cycle aligns with the calendar month. Adjust the window for subscriptions with different renewal dates.
-- Before trusting this, verify overage_cap is constant per user this month:
--   SELECT userid, COUNT(DISTINCT overage_cap) FROM user_report WHERE <this month> GROUP BY userid HAVING COUNT(DISTINCT overage_cap) > 1;
-- Overage enabled: track overage_credits_used against the configured overage limit instead.
-- est_days_remaining is an estimate at the current average daily pace, not a forecast. 75% of cap or more is "at risk".
WITH mtd AS (
  SELECT userid, subscription_tier,
         SUM(credits_used)       AS credits_mtd,
         MAX(overage_cap)        AS cap,
         COUNT(DISTINCT "date")  AS active_days
  FROM user_report
  WHERE date_trunc('month', CAST("date" AS date)) = date_trunc('month', date(current_timestamp AT TIME ZONE 'UTC'))
    AND CAST("date" AS date) < date(current_timestamp AT TIME ZONE 'UTC')          -- complete UTC days only
    AND credits_used > 0
    AND overage_enabled = false                -- overage-disabled users only
    AND subscription_tier <> 'POOLING'      -- credit sharing has no per-user cap
  GROUP BY userid, subscription_tier
), paced AS (
  SELECT *,
         credits_mtd / GREATEST(day(date(current_timestamp AT TIME ZONE 'UTC')) - 1, 1) AS avg_daily_credits,
         GREATEST(cap - credits_mtd, 0)                   AS remaining_credits,
         ROUND(100.0 * credits_mtd / NULLIF(cap, 0), 1)   AS pct_of_cap
  FROM mtd
)
SELECT userid, subscription_tier, credits_mtd, cap, active_days, pct_of_cap,
       remaining_credits,
       ROUND(remaining_credits / NULLIF(avg_daily_credits, 0), 1) AS est_days_remaining,
       pct_of_cap >= 75                                           AS at_risk
FROM paced
ORDER BY pct_of_cap DESC;
