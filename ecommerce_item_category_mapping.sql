-- Removing the empty item properties table

DROP TABLE public.item_properties;
-- Creating the item properties table

CREATE TABLE item_properties (
    timestamp BIGINT,
    itemid BIGINT,
    property VARCHAR(100),
    value VARCHAR(255)
);
-- Increasing the value column capacity for item properties

ALTER TABLE item_properties
ALTER COLUMN value TYPE TEXT;


SELECT COUNT(*) FROM item_properties;

SELECT COUNT(*) FROM item_properties;


-- Creating the item to category mapping

CREATE TABLE item_category AS
SELECT
    timestamp,
    itemid,
    CAST(value AS BIGINT) AS categoryid
FROM item_properties
WHERE property = 'categoryid';


-- Verifying the item to category mapping

SELECT *
FROM item_category
LIMIT 10;


-- Creating an index to speed up item category lookups

CREATE INDEX idx_item_category_item_timestamp
ON item_category (itemid, timestamp);


-- Checking the number of item-category mappings

SELECT COUNT(*)
FROM item_category;


-- Creating an index to speed up event-category matching

CREATE INDEX idx_events_clean_item_timestamp
ON events_clean (itemid, timestamp);


-- Creating an event table with category information

CREATE TABLE events_category AS
SELECT DISTINCT ON (e.itemid, e.timestamp, e.visitorid, e.event, e.transactionid)
    e.*,
    ic.categoryid
FROM events_clean e
LEFT JOIN item_category ic
    ON e.itemid = ic.itemid
   AND ic.timestamp <= e.timestamp
ORDER BY
    e.itemid,
    e.timestamp,
    e.visitorid,
    e.event,
    e.transactionid,
    ic.timestamp DESC;


-- Verifying category information in event data

SELECT *
FROM events_category
LIMIT 10;


-- Creating the category hierarchy table

CREATE TABLE category_tree (
    categoryid BIGINT,
    parentid BIGINT
);


-- Verifying the category hierarchy data

SELECT COUNT(*)
FROM category_tree;


-- Checking category coverage in event data

SELECT
    COUNT(*) AS total_events,
    COUNT(categoryid) AS mapped_events,
    COUNT(*) - COUNT(categoryid) AS unmapped_events,
    ROUND(
        COUNT(categoryid) * 100.0 / COUNT(*),
        2
    ) AS mapping_coverage
FROM events_category;