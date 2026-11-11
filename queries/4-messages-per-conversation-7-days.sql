-- 4 - Messages per conversation (7 days)
-- Database: kiro_usage (Glue), table: user_report
-- Last 7 complete UTC days. Messages include prompts, tool calls, and responses,
-- so this is a proxy for interaction depth, not literal back-and-forth turns.
WITH daily AS (   -- one row per developer per day, IDE/CLI/Plugin rows combined
  SELECT userid, "date",
         SUM(total_messages)     AS messages,
         SUM(chat_conversations) AS conversations,
         SUM(credits_used)       AS credits
  FROM user_report
  WHERE CAST("date" AS date) BETWEEN date(current_timestamp AT TIME ZONE 'UTC') - INTERVAL '7' DAY
                                 AND date(current_timestamp AT TIME ZONE 'UTC') - INTERVAL '1' DAY
  GROUP BY userid, "date"
),
active_days AS (SELECT * FROM daily WHERE messages > 0)
SELECT SUM(conversations)                                    AS conversations,
       SUM(messages)                                         AS messages,
       ROUND(SUM(messages) * 1.0 / NULLIF(SUM(conversations), 0), 1) AS messages_per_conversation,
       ROUND(SUM(credits)  * 1.0 / NULLIF(SUM(conversations), 0), 1) AS credits_per_conversation
FROM active_days;
