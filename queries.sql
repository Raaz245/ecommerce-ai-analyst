
-- ================================================================
-- SQL ANALYSIS — OLIST E-COMMERCE
-- Project: E-Commerce Intelligence Platform
-- ================================================================

-- Q1: COMPLETE ORDER FUNNEL
SELECT
    order_status,
    COUNT(*)                                              AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)   AS pct_of_total,
    ROUND(SUM(p.payment_value), 2)                       AS revenue
FROM orders o
LEFT JOIN payments p ON o.order_id = p.order_id
GROUP BY order_status
ORDER BY order_count DESC;

-- Q2: SELLER QUALITY SCORECARD
SELECT
    s.seller_id,
    s.seller_state,
    COUNT(DISTINCT oi.order_id)                          AS total_orders,
    ROUND(SUM(oi.price), 2)                              AS total_revenue,
    ROUND(AVG(r.review_score), 2)                        AS avg_review,
    ROUND(AVG(julianday(o.order_delivered_customer_date)
          - julianday(o.order_purchase_timestamp)), 1)   AS avg_delivery_days,
    ROUND(SUM(CASE WHEN o.order_delivered_customer_date
                        > o.order_estimated_delivery_date
                   THEN 1.0 ELSE 0 END)
          * 100.0 / COUNT(*), 2)                         AS late_pct
FROM sellers s
JOIN order_items oi  ON s.seller_id  = oi.seller_id
JOIN orders o        ON oi.order_id  = o.order_id
JOIN reviews r       ON o.order_id   = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_state
HAVING COUNT(DISTINCT oi.order_id) >= 50
ORDER BY avg_review DESC;

-- Q3: CUSTOMER RETENTION RATE
WITH first_orders AS (
    SELECT
        customer_id,
        MIN(strftime('%Y-%m', order_purchase_timestamp)) AS first_month
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY customer_id
),
monthly_orders AS (
    SELECT DISTINCT
        o.customer_id,
        strftime('%Y-%m', o.order_purchase_timestamp) AS order_month
    FROM orders o
    WHERE o.order_status = 'delivered'
)
SELECT
    f.first_month,
    COUNT(DISTINCT f.customer_id)                        AS new_customers,
    COUNT(DISTINCT m.customer_id)                        AS returning_customers,
    ROUND(COUNT(DISTINCT m.customer_id) * 100.0
          / COUNT(DISTINCT f.customer_id), 2)            AS retention_rate_pct
FROM first_orders f
LEFT JOIN monthly_orders m
       ON f.customer_id = m.customer_id
      AND m.order_month > f.first_month
GROUP BY f.first_month
ORDER BY f.first_month;

-- Q4: REVENUE QUALITY BY STATE
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id)                           AS total_orders,
    ROUND(SUM(p.payment_value), 2)                       AS total_revenue,
    ROUND(SUM(p.payment_value)
          / COUNT(DISTINCT o.customer_id), 2)            AS revenue_per_customer,
    ROUND(AVG(r.review_score), 2)                        AS avg_review
FROM orders o
JOIN customers c  ON o.customer_id = c.customer_id
JOIN payments p   ON o.order_id    = p.order_id
JOIN reviews r    ON o.order_id    = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 100
ORDER BY revenue_per_customer DESC;

-- Q5: DELIVERY ROOT CAUSE
SELECT
    s.seller_state,
    c.customer_state,
    COUNT(*)                                             AS total_orders,
    ROUND(AVG(oi.product_weight_g), 0)                  AS avg_weight_g,
    ROUND(AVG(julianday(o.order_delivered_customer_date)
          - julianday(o.order_purchase_timestamp)), 1)   AS avg_days,
    ROUND(SUM(CASE WHEN o.order_delivered_customer_date
                        > o.order_estimated_delivery_date
                   THEN 1.0 ELSE 0 END)
          * 100.0 / COUNT(*), 2)                         AS late_pct
FROM orders o
JOIN order_items oi ON o.order_id    = oi.order_id
JOIN products p     ON oi.product_id = p.product_id
JOIN sellers s      ON oi.seller_id  = s.seller_id
JOIN customers c    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_state, c.customer_state
HAVING COUNT(*) >= 100
ORDER BY late_pct DESC;

-- Q6: 1-STAR REVIEW ROOT CAUSE
SELECT
    COALESCE(cat.product_category_name_english, 'Unknown') AS category,
    COUNT(*)                                               AS total_reviews,
    SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END)   AS one_star_count,
    ROUND(SUM(CASE WHEN r.review_score = 1
                   THEN 1.0 ELSE 0 END)
          * 100.0 / COUNT(*), 2)                           AS one_star_pct,
    ROUND(AVG(r.review_score), 2)                          AS avg_review
FROM reviews r
JOIN orders o       ON r.order_id    = o.order_id
JOIN order_items oi ON o.order_id    = oi.order_id
JOIN products p     ON oi.product_id = p.product_id
LEFT JOIN category cat
       ON p.product_category_name = cat.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
HAVING COUNT(*) >= 100
ORDER BY one_star_pct DESC;
