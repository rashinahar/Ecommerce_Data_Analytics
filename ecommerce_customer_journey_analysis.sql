--checking PostgreSQL version
SELECT version();

-- creating the events table
CREATE TABLE events (
    timestamp BIGINT,
    visitorid BIGINT,
    event VARCHAR(20),
    itemid BIGINT,
    transactionid BIGINT
);


SELECT COUNT(*) FROM events;
SELECT *
FROM events
LIMIT 10;
SELECT
    event,
    COUNT(*) AS event_count
FROM events
GROUP BY event
ORDER BY event_count DESC;

SELECT
    COUNT(DISTINCT visitorid) AS total_users,
    COUNT(*) FILTER (WHERE event = 'view') AS product_views,
    COUNT(*) FILTER (WHERE event = 'addtocart') AS cart_adds,
    COUNT(*) FILTER (WHERE event = 'transaction') AS purchases
FROM events;

SELECT
    ROUND(
        COUNT(*) FILTER (WHERE event = 'addtocart') * 100.0
        / COUNT(*) FILTER (WHERE event = 'view'),
        2
    ) AS view_to_cart_rate,

    ROUND(
        COUNT(*) FILTER (WHERE event = 'transaction') * 100.0
        / COUNT(*) FILTER (WHERE event = 'addtocart'),
        2
    ) AS cart_to_purchase_rate,

    ROUND(
        COUNT(*) FILTER (WHERE event = 'transaction') * 100.0
        / COUNT(*) FILTER (WHERE event = 'view'),
        2
    ) AS view_to_purchase_rate
FROM events;

SELECT
    TO_TIMESTAMP(timestamp / 1000)::date AS activity_date,
    COUNT(*) AS total_events,
    COUNT(*) FILTER (WHERE event = 'view') AS views,
    COUNT(*) FILTER (WHERE event = 'addtocart') AS cart_adds,
    COUNT(*) FILTER (WHERE event = 'transaction') AS purchases
FROM events
GROUP BY activity_date
ORDER BY activity_date;


WITH first_activity AS (
    SELECT
        visitorid,
        MIN(timestamp) AS first_timestamp
    FROM events
    GROUP BY visitorid
)

SELECT *
FROM first_activity
LIMIT 10;


WITH sessions AS (
    SELECT
        visitorid,
        TO_TIMESTAMP(timestamp / 1000) AS event_time,
        FLOOR(
            EXTRACT(
                EPOCH FROM (
                    TO_TIMESTAMP(timestamp / 1000)
                    - LAG(TO_TIMESTAMP(timestamp / 1000))
                      OVER (
                          PARTITION BY visitorid
                          ORDER BY timestamp
                      )
                )
            ) / 60
        ) AS gap_minutes
    FROM events
)

SELECT *
FROM sessions
LIMIT 20;



WITH session_gaps AS (
    SELECT
        visitorid,
        timestamp,
        event,
        CASE
            WHEN LAG(timestamp) OVER (
                PARTITION BY visitorid
                ORDER BY timestamp
            ) IS NULL THEN 1

            WHEN (
                timestamp -
                LAG(timestamp) OVER (
                    PARTITION BY visitorid
                    ORDER BY timestamp
                )
            ) > 30 * 60 * 1000 THEN 1

            ELSE 0
        END AS new_session
    FROM events
)

SELECT
    visitorid,
    timestamp,
    event,
    new_session,
    SUM(new_session) OVER (
        PARTITION BY visitorid
        ORDER BY timestamp
    ) AS session_number
FROM session_gaps
LIMIT 20;


WITH session_gaps AS (
    SELECT
        visitorid,
        timestamp,
        event,
        CASE
            WHEN LAG(timestamp) OVER (
                PARTITION BY visitorid
                ORDER BY timestamp
            ) IS NULL THEN 1

            WHEN (
                timestamp -
                LAG(timestamp) OVER (
                    PARTITION BY visitorid
                    ORDER BY timestamp
                )
            ) > 30 * 60 * 1000 THEN 1

            ELSE 0
        END AS new_session
    FROM events
),

sessionized AS (
    SELECT
        visitorid,
        timestamp,
        event,
        SUM(new_session) OVER (
            PARTITION BY visitorid
            ORDER BY timestamp
        ) AS session_number
    FROM session_gaps
)

SELECT
    visitorid,
    timestamp,
    event,
    session_number,
    CASE
        WHEN session_number = 1 THEN 'New'
        ELSE 'Returning'
    END AS user_type
FROM sessionized
LIMIT 20;



WITH session_gaps AS (
    SELECT
        visitorid,
        timestamp,
        event,
        CASE
            WHEN LAG(timestamp) OVER (
                PARTITION BY visitorid
                ORDER BY timestamp
            ) IS NULL THEN 1
            WHEN timestamp - LAG(timestamp) OVER (
                PARTITION BY visitorid
                ORDER BY timestamp
            ) > 30 * 60 * 1000 THEN 1
            ELSE 0
        END AS new_session
    FROM events
),

sessionized AS (
    SELECT
        visitorid,
        timestamp,
        event,
        SUM(new_session) OVER (
            PARTITION BY visitorid
            ORDER BY timestamp
        ) AS session_number
    FROM session_gaps
),

session_summary AS (
    SELECT
        visitorid,
        session_number,
        MAX(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS has_purchase
    FROM sessionized
    GROUP BY visitorid, session_number
)

SELECT
    CASE
        WHEN session_number = 1 THEN 'New'
        ELSE 'Returning'
    END AS user_type,
    COUNT(*) AS sessions,
    SUM(has_purchase) AS purchases,
    ROUND(
        SUM(has_purchase) * 100.0 / COUNT(*),
        2
    ) AS purchase_rate
FROM session_summary
GROUP BY user_type
ORDER BY user_type;


SELECT
    itemid,

    COUNT(*) FILTER (WHERE event = 'view') AS views,

    COUNT(*) FILTER (WHERE event = 'addtocart') AS cart_adds,

    COUNT(*) FILTER (WHERE event = 'transaction') AS purchases

FROM events

GROUP BY itemid

ORDER BY purchases DESC

LIMIT 20;


-- User-level Purchase Behavior
-- Finding the number of unique users who made at least one purchase

SELECT
    COUNT(DISTINCT visitorid) AS purchasing_users
FROM events
WHERE event = 'transaction';

-- Finding how many purchases each user made

SELECT
    visitorid,
    COUNT(*) AS purchase_count
FROM events
WHERE event = 'transaction'
GROUP BY visitorid
ORDER BY purchase_count DESC;


-- Finding the distribution of purchase frequency among users

WITH user_purchases AS (
    SELECT
        visitorid,
        COUNT(*) AS purchase_count
    FROM events
    WHERE event = 'transaction'
    GROUP BY visitorid
)

SELECT
    purchase_count,
    COUNT(*) AS users
FROM user_purchases
GROUP BY purchase_count
ORDER BY purchase_count;


-- Comparing one-time buyers with repeat buyers

WITH user_purchases AS (
    SELECT
        visitorid,
        COUNT(*) AS purchase_count
    FROM events
    WHERE event = 'transaction'
    GROUP BY visitorid
)

SELECT
    CASE
        WHEN purchase_count = 1 THEN 'One-time Buyer'
        ELSE 'Repeat Buyer'
    END AS customer_type,
    COUNT(*) AS users
FROM user_purchases
GROUP BY customer_type
ORDER BY users DESC;


-- Finding the top customers by number of purchases

SELECT
    visitorid,
    COUNT(*) AS total_purchases
FROM events
WHERE event = 'transaction'
GROUP BY visitorid
ORDER BY total_purchases DESC
LIMIT 20;