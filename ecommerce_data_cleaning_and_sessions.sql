-- Creating a cleaned events table by removing duplicate records

CREATE TABLE events_clean AS
SELECT DISTINCT *
FROM events;


-- Checking the number of records in the cleaned events table

SELECT COUNT(*) 
FROM events_clean;


-- Creating user sessions using a 30-minute inactivity threshold

CREATE TABLE user_sessions AS
WITH session_gaps AS (
    SELECT
        visitorid,
        timestamp,
        event,
        itemid,
        transactionid,
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
    FROM events_clean
),
sessionized AS (
    SELECT
        *,
        SUM(new_session) OVER (
            PARTITION BY visitorid
            ORDER BY timestamp
        ) AS session_number
    FROM session_gaps
)
SELECT
    *,
    visitorid::text || '_' || session_number::text AS session_key
FROM sessionized;


-- Verifying the user sessions table

SELECT *
FROM user_sessions
LIMIT 10;


-- Creating a session-level summary for customer journey analysis

CREATE TABLE session_summary AS
SELECT
    session_key,
    visitorid,
    MIN(timestamp) AS session_start,
    MAX(timestamp) AS session_end,
    COUNT(*) AS event_count,
    COUNT(*) FILTER (WHERE event = 'view') AS views,
    COUNT(*) FILTER (WHERE event = 'addtocart') AS cart_adds,
    COUNT(*) FILTER (WHERE event = 'transaction') AS purchases,
    MAX(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS has_purchase
FROM user_sessions
GROUP BY session_key, visitorid;


-- Classifying sessions as New or Returning users

CREATE TABLE session_user_type AS
WITH first_sessions AS (
    SELECT
        visitorid,
        MIN(session_start) AS first_session_start
    FROM session_summary
    GROUP BY visitorid
)
SELECT
    s.session_key,
    s.visitorid,
    s.session_start,
    s.session_end,
    s.event_count,
    s.views,
    s.cart_adds,
    s.purchases,
    s.has_purchase,
    CASE
        WHEN s.session_start = f.first_session_start
            THEN 'New'
        ELSE 'Returning'
    END AS user_type
FROM session_summary s
JOIN first_sessions f
    ON s.visitorid = f.visitorid;


