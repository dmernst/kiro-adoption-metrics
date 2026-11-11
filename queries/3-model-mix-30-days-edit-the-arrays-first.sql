-- 3 - Model mix (30 days) - add your model columns
-- Database: kiro_usage (Glue), table: user_report
-- Runs as-is against a table with only auto_messages.
-- For each other <model>_messages column from query 1, add a label to the first array and the column to the second, same order.
-- Until every model column is included, treat the result as a partial breakdown.
SELECT m.model,
       SUM(m.messages) AS messages,
       ROUND(100.0 * SUM(m.messages) / SUM(SUM(m.messages)) OVER (), 1) AS pct
FROM user_report
CROSS JOIN UNNEST(
  ARRAY['auto'],          -- add one label per model column from query 1
  ARRAY[auto_messages]    -- add the matching <model>_messages column, same order
) AS m(model, messages)
WHERE CAST("date" AS date) BETWEEN date(current_timestamp AT TIME ZONE 'UTC') - INTERVAL '30' DAY
                               AND date(current_timestamp AT TIME ZONE 'UTC') - INTERVAL '1' DAY
GROUP BY m.model
ORDER BY messages DESC;
