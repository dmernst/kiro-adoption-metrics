-- 4 - Burn rate and tier fit (month to date)
-- Database: kiro_usage (Glue), table: user_report
-- When overage is off, overage_cap is the plan's included credits.
-- Sort ascending for tier fit.
WITH mtd AS (
  SELECT userid, subscription_tier,
         SUM(credits_used) AS credits_mtd,
         MAX(overage_cap)  AS cap
  FROM user_report
  WHERE date_trunc('month', CAST("date" AS date)) = date_trunc('month', current_date)
  GROUP BY userid, subscription_tier
)
SELECT userid, subscription_tier, credits_mtd, cap,
       ROUND(100.0 * credits_mtd / NULLIF(cap,0), 1) AS pct_of_cap,
       ROUND(cap / NULLIF(credits_mtd / day(current_date), 0), 1) AS projected_days_to_cap
FROM mtd
ORDER BY pct_of_cap DESC;
