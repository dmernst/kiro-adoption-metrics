-- 2 - Active users, depth, turns per conversation (7 days)
-- Database: kiro_usage (Glue), table: user_report
WITH daily AS (
  SELECT userid, "date",
         SUM(total_messages)     AS messages,
         SUM(chat_conversations) AS conversations,
         SUM(credits_used)       AS credits
  FROM user_report
  WHERE CAST("date" AS date) >= current_date - INTERVAL '7' DAY
  GROUP BY userid, "date"
)
SELECT
  COUNT(DISTINCT userid)                             AS active_users,
  approx_percentile(messages, 0.5)                   AS p50_messages_per_day,
  approx_percentile(messages, 0.9)                   AS p90_messages_per_day,
  SUM(messages) * 1.0 / NULLIF(SUM(conversations),0) AS turns_per_conversation,
  SUM(credits)  * 1.0 / NULLIF(SUM(conversations),0) AS credits_per_conversation
FROM daily
WHERE messages > 0;
