-- 3 - Model mix (30 days) - edit the arrays first
-- Database: kiro_usage (Glue), table: user_report
-- model_a / model_b are placeholders. Replace them with the columns from query 1.
-- Re-run query 1 after new models launch; until the arrays are updated, new models are missing from the mix.
SELECT m.model,
       SUM(m.messages) AS messages,
       ROUND(100.0 * SUM(m.messages) / SUM(SUM(m.messages)) OVER (), 1) AS pct
FROM user_report
CROSS JOIN UNNEST(
  ARRAY['auto', 'model_a', 'model_b'],                      -- labels: replace
  ARRAY[auto_messages, model_a_messages, model_b_messages]  -- columns: replace
) AS m(model, messages)
WHERE CAST("date" AS date) BETWEEN current_date - INTERVAL '30' DAY
                               AND current_date - INTERVAL '1' DAY
GROUP BY m.model
ORDER BY messages DESC;
