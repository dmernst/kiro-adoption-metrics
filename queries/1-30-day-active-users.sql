-- 1 - 30-day active users
-- Database: kiro_usage (Glue), table: user_report
-- Last 30 complete UTC days. Returns unique active users (the numerator).
-- Divide by assigned seats from Kiro Access management for the 30-day active adoption rate.
SELECT COUNT(DISTINCT userid) AS active_users_30d
FROM user_report
WHERE CAST("date" AS date) BETWEEN date(current_timestamp AT TIME ZONE 'UTC') - INTERVAL '30' DAY
                               AND date(current_timestamp AT TIME ZONE 'UTC') - INTERVAL '1' DAY
  AND total_messages > 0;
