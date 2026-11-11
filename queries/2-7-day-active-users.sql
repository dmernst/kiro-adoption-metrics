-- 2 - 7-day active users
-- Database: kiro_usage (Glue), table: user_report
-- Last 7 complete UTC days; today's report hasn't landed yet.
-- Returns unique active users (the numerator). Divide by assigned seats from Kiro Access management for the 7-day active rate.
SELECT COUNT(DISTINCT userid) AS active_users_7d
FROM user_report
WHERE CAST("date" AS date) BETWEEN date(current_timestamp AT TIME ZONE 'UTC') - INTERVAL '7' DAY
                               AND date(current_timestamp AT TIME ZONE 'UTC') - INTERVAL '1' DAY
  AND total_messages > 0;
