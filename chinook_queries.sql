

-- Q1a: Business overview KPIs
SELECT
    ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS total_revenue,
    COUNT(DISTINCT il.InvoiceId)              AS invoices,
    COUNT(DISTINCT i.CustomerId)              AS customers,
    ROUND(SUM(il.UnitPrice * il.Quantity) / COUNT(DISTINCT il.InvoiceId), 2) AS avg_order_value
FROM InvoiceLine il
JOIN Invoice i ON i.InvoiceId = il.InvoiceId;

-- Q1b: Trust check — invoice.Total vs sum of line items
SELECT COUNT(*) AS mismatches
FROM Invoice i
JOIN (SELECT InvoiceId, SUM(UnitPrice * Quantity) AS line_total
      FROM InvoiceLine GROUP BY InvoiceId) l ON l.InvoiceId = i.InvoiceId
WHERE ROUND(l.line_total - i.Total, 2) <> 0;

-- Q2: Top 10 artists by revenue (4-table JOIN)
SELECT
    ar.Name                                   AS artist,
    SUM(il.Quantity)                          AS units_sold,
    ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS revenue
FROM InvoiceLine il
JOIN Track  t  ON t.TrackId  = il.TrackId
JOIN Album  al ON al.AlbumId = t.AlbumId
JOIN Artist ar ON ar.ArtistId = al.ArtistId
GROUP BY ar.ArtistId, ar.Name
ORDER BY revenue DESC
LIMIT 10;

-- Q3: Revenue by continent (CASE mapping)
SELECT
    CASE
        WHEN BillingCountry IN ('USA', 'Canada')                THEN 'North America'
        WHEN BillingCountry IN ('Brazil', 'Argentina', 'Chile') THEN 'South America'
        WHEN BillingCountry = 'India'                           THEN 'Asia'
        WHEN BillingCountry = 'Australia'                       THEN 'Oceania'
        ELSE 'Europe'
    END AS region,
    COUNT(*)             AS invoices,
    ROUND(SUM(Total), 2) AS revenue
FROM Invoice
GROUP BY region
ORDER BY revenue DESC;

-- Q4: Monthly revenue + MoM change + running total (window functions)
WITH monthly AS (
    SELECT strftime('%Y-%m', InvoiceDate) AS month,
           ROUND(SUM(Total), 2)           AS revenue
    FROM Invoice
    GROUP BY 1
)
SELECT
    month,
    revenue,
    ROUND(revenue - LAG(revenue) OVER (ORDER BY month), 2) AS mom_change,
    ROUND(SUM(revenue) OVER (ORDER BY month), 2)           AS running_total
FROM monthly
ORDER BY month;

-- Q5 (Bonus): RANK vs DENSE_RANK on artist revenue
WITH artist_rev AS (
    SELECT ar.Name AS artist, SUM(il.UnitPrice * il.Quantity) AS revenue
    FROM InvoiceLine il
    JOIN Track  t  ON t.TrackId  = il.TrackId
    JOIN Album  al ON al.AlbumId = t.AlbumId
    JOIN Artist ar ON ar.ArtistId = al.ArtistId
    GROUP BY ar.ArtistId, ar.Name
)
SELECT artist,
       ROUND(revenue, 2) AS revenue,
       RANK()       OVER (ORDER BY revenue DESC) AS rank_,
       DENSE_RANK() OVER (ORDER BY revenue DESC) AS dense_rank_
FROM artist_rev
ORDER BY rank_
LIMIT 10;