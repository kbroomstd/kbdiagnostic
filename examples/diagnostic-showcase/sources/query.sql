WITH ranked AS (
  SELECT
    e.id, e.name, e.score, e.dept_id,
    ROW_NUMBER() OVER (PARTITION BY e.dept_id ORDER BY e.score DESC) AS rn
  FROM employees e
  WHERE e.status = 'active'
)
SELECT r.id, r.name, r.score, d.name AS dept_name
FROM ranked r
JOIN departments d ON r.dept_id = d.id
WHERE r.rn <= 3
ORDER BY r.score DESC;
