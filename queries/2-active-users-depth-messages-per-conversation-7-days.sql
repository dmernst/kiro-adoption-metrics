-- 2 - Active users, depth, messages per conversation (7 days)
-- Database: kiro_usage (Glue), table: user_report
-- Last 7 complete UTC days. Rows are per user, per day, per client; the daily CTE combines them.
-- Returns unique active users (the numerator). Divide by assigned seats from Kiro Access management for the 7-day active rate.
-- Day-level percentiles are over active user-days; per-developer percentiles are over people.
WITH daily AS (
  SELECT userid, "date",
         SUM(total_messages)     AS messages,
         SUM(chat_conversations) AS conversations,
         SUM(credits_used)       AS credits
  FROM user_report
  -- last 7 complete UTC days; today's report hasn't landed yet
  WHERE CAST("date" AS date) BETWEEN date(current_timestamp AT TIME ZONE 'UTC') - INTERVAL '7' DAY
                                 AND date(current_timestamp AT TIME ZONE 'UTC') - INTERVAL '1' DAY
  GROUP BY userid, "date"
),
active_days AS (SELECT * FROM daily WHERE messages > 0),
per_dev AS (   -- one row per developer for the week
  SELECT userid, SUM(messages) AS week_messages FROM active_days GROUP BY userid
)
SELECT
  d.active_users, d.p50_messages_per_day, d.p90_messages_per_day,
  d.depth_gap, d.depth_ratio,
  w.p50_week_messages_per_dev, w.p90_week_messages_per_dev,
  d.messages_per_conversation, d.credits_per_conversation
FROM (
  SELECT
    COUNT(DISTINCT userid)                                  AS active_users,
    approx_percentile(messages, 0.5)                        AS p50_messages_per_day,
    approx_percentile(messages, 0.9)                        AS p90_messages_per_day,
    approx_percentile(messages, 0.9) - approx_percentile(messages, 0.5) AS depth_gap,
    approx_percentile(messages, 0.9) * 1.0
      / NULLIF(approx_percentile(messages, 0.5), 0)        AS depth_ratio,
    SUM(messages) * 1.0 / NULLIF(SUM(conversations), 0)     AS messages_per_conversation,
    SUM(credits)  * 1.0 / NULLIF(SUM(conversations), 0)     AS credits_per_conversation
  FROM active_days
) d
CROSS JOIN (
  SELECT approx_percentile(week_messages, 0.5) AS p50_week_messages_per_dev,
         approx_percentile(week_messages, 0.9) AS p90_week_messages_per_dev
  FROM per_dev
) w;
