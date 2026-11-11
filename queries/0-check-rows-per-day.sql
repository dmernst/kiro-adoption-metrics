-- 0 - Check rows per day
-- Database: kiro_usage (Glue), table: user_report
SELECT "date", COUNT(*) AS user_rows
FROM user_report
GROUP BY 1 ORDER BY 1 DESC LIMIT 7;
