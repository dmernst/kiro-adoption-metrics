-- 4 - Burn rate and tier fit (month to date)
-- Database: kiro_usage (Glue), table: user_report
-- When overage is off, overage_cap is the plan's included credits.
-- Sort ascending for tier fit: users consistently below 25% are candidates for a tier-fit review.
WITH mtd AS (
  SELECT userid, subscription_tier,
         SUM(credits_used)       AS credits_mtd,
         MAX(overage_cap)        AS cap,
         COUNT(DISTINCT "date")  AS active_days
  FROM user_report
  WHERE date_trunc('month', CAST("date" AS date)) = date_trunc('month', current_date)
    AND credits_used > 0
  GROUP BY userid, subscription_tier
)
SELECT userid, subscription_tier, credits_mtd, cap, active_days,
       ROUND(100.0 * credits_mtd / NULLIF(cap,0), 1) AS pct_of_cap,
       -- estimate, not a forecast: assumes the current average daily pace continues
       ROUND(cap / NULLIF(credits_mtd / GREATEST(day(current_date) - 1, 1), 0), 1)
         AS est_days_to_cap_at_current_avg
FROM mtd
ORDER BY pct_of_cap DESC;
