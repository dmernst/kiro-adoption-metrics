-- 3 - Model mix (30 days) - edit the arrays first
-- Database: kiro_usage (Glue), table: user_report
-- Replace model_a / model_b with the column names from query 1.
SELECT m.model,
       SUM(m.messages) AS messages,
       ROUND(100.0 * SUM(m.messages) / SUM(SUM(m.messages)) OVER (), 1) AS pct
FROM user_report
CROSS JOIN UNNEST(
  ARRAY['auto', 'model_a', 'model_b'],
  ARRAY[auto_messages, model_a_messages, model_b_messages]
) AS m(model, messages)
WHERE CAST("date" AS date) >= current_date - INTERVAL '30' DAY
GROUP BY m.model
ORDER BY messages DESC;
