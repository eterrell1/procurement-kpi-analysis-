
- PROCUREMENT KPI ANALYSIS
- Dataset: Procurement_KPI_Analysis_Dataset.csv
- Table name: raw_po_data
- Order Status values confirmed in this dataset: Delivered, Partially Delivered, Pending, Cancelled



  1. COMPLETION RATE 
 ------------------------------------------------------------
- Logic: Only orders that reached a final delivery outcome (Delivered or Partially Delivered) count toward this KPI.
- Pending orders are excluded (not finished yet).
- Cancelled orders are excluded (never delivered, tracked separately).
- Numerator = fully Delivered orders only.
- Denominator = Delivered + Partially Delivered.
------------------------------------
SELECT
    Supplier,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN Order_Status = 'Delivered' THEN 1 ELSE 0 END) AS completed_orders,
    ROUND(100.0 * SUM(CASE WHEN Order_Status = 'Delivered' THEN 1 ELSE 0 END) / COUNT(*), 2) AS on_time_pct
FROM raw_po_data
WHERE Order_Status IN ('Delivered', 'Partially Delivered')
GROUP BY Supplier
ORDER BY on_time_pct DESC;


 2. CANCELLATION RATE BY SUPPLIER
-------------------------------------------------------------
- Logic: Denominator here is ALL orders (no WHERE filter), because I'm asking "of everything given to this supplier, what fraction fell apart entirely" (Pending/Cancelled/Delivered all belong in this denominator.)
------------------------------------------------------
SELECT
    Supplier,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND(100.0 * SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancellation_pct
FROM raw_po_data
GROUP BY Supplier
ORDER BY cancellation_pct DESC;


3. AVERAGE LEAD TIME BY SUPPLIER (in days)
--------------------------------------------------------------
- Logic: Only makes sense for orders that actually shipped, so I applied the same Delivered/Partially Delivered filter.
- JULIANDAY() converts a date into a plain number (days since a fixed reference point) so I can subtract two dates and get a clean day count.
-------------------------------------------------------------
SELECT 
    Supplier,
    ROUND(AVG(JULIANDAY(Delivery_Date) - JULIANDAY(Order_Date)), 1) AS avg_lead_time_days
FROM raw_po_data
WHERE Order_Status IN ('Delivered', 'Partially Delivered')
GROUP BY Supplier
ORDER BY avg_lead_time_days ASC;



 4. PRICE VARIANCE / NEGOTIATION SAVINGS BY SUPPLIER
--------------------------------------------------------------
- Logic: Compares Unit_Price (original quoted price) against Negotiated_Price (what was actually paid) to measure how muchprocurement saved through negotiation. Expressed both in raw dollars and as a % of original spend (more comparable across suppliers of different order sizes).
------------------------------------------------------------------
SELECT
    Supplier,
    ROUND(SUM((Unit_Price - Negotiated_Price) * Quantity), 2) AS total_savings,
    ROUND(SUM(Unit_Price * Quantity), 2) AS total_original_spend,
    ROUND(100.0 * SUM((Unit_Price - Negotiated_Price) * Quantity) / SUM(Unit_Price * Quantity), 2) AS savings_pct
FROM raw_po_data
WHERE order_status IN ('Delivered', 'Partially Delivered')
GROUP BY Supplier
ORDER BY savings_pct DESC;



5. DEFECT RATE BY SUPPLIER
--------------------------------------------------------------
- Logic: Defective_Units / Quantity, grouped by supplier.
- Same rate-calculation pattern as every KPI above
----------------------------------------------------------
SELECT
    Supplier,
    SUM(Defective_Units) AS total_defective_units,
    SUM(Quantity) AS total_units_ordered,
    ROUND(100.0 * SUM(Defective_Units) / SUM(Quantity), 2) AS defect_rate_pct
FROM raw_po_data
GROUP BY Supplier
ORDER BY defect_rate_pct DESC;



6. COMPOSITE SUPPLIER SCORECARD (final deliverable)
--------------------------------------------------------------
- Combines on-time %, savings %, and defect rate into one ranked table using a window function (RANK).

- Note: on_time_pct uses CASE WHEN inside the SUM()s instead of a WHERE clause because the numerator and denominator need different slices of the data. Mumerator is just Delivered, denominator is Delivered + Partially Delivered. A WHERE clause applies to the whole query the same way, so it can't give one column a narrower filter than another. CASE WHEN fixes that by letting each SUM decide for itself what counts.

I filtered savings_pct and defect_rate_pct the same way just to keep it consistent, so all three KPIs in the scorecard are using the same filtering logic instead of mixing approaches.
-------------------------------------------------------------------------------------------------------
SELECT
    Supplier,
    on_time_pct,
    savings_pct,
    defect_rate_pct,
    RANK() OVER (
        ORDER BY on_time_pct DESC, defect_rate_pct ASC, savings_pct DESC
    ) AS supplier_rank
FROM (
    SELECT
        Supplier,
        ROUND(100.0 * SUM(CASE WHEN Order_Status = 'Delivered' THEN 1 ELSE 0 END) 
            / SUM(CASE WHEN Order_Status IN ('Delivered', 'Partially Delivered') THEN 1 ELSE 0 END), 2) AS on_time_pct,

        ROUND(100.0 * SUM(CASE WHEN Order_Status IN ('Delivered', 'Partially Delivered') 
                THEN (Unit_Price - Negotiated_Price) * Quantity ELSE 0 END) 
            / SUM(CASE WHEN Order_Status IN ('Delivered', 'Partially Delivered') 
                THEN Unit_Price * Quantity ELSE 0 END), 2) AS savings_pct,

        ROUND(100.0 * SUM(CASE WHEN Order_Status IN ('Delivered', 'Partially Delivered') 
                THEN Defective_Units ELSE 0 END) 
            / SUM(CASE WHEN Order_Status IN ('Delivered', 'Partially Delivered') 
                THEN Quantity ELSE 0 END), 2) AS defect_rate_pct

    FROM raw_po_data
    GROUP BY Supplier
) AS supplier_kpis
ORDER BY supplier_rank;

**** RESULTS ****(confirmed working):

              on time %    savings %    defective rate %          rank
 Alpha Inc        91.45       8.08           1.81                  1
 Epsilon Group    89.55       7.90           2.60                  2
 Beta Supplies    89.43       8.28           7.67                  3
 Delta Logistics  86.96       7.81           10.83                 4
 Gamma Co         85.12       7.79           4.45                  5

 Key insight: Delta Logistics has the BEST savings percentage (10.83%) but ranks 4th overall due to a high defect rate and lower on-time percentage. This is why a composite scorecard matters more thanjudging suppliers on price alone.
