# Procurement KPI Analysis

A supplier performance analysis project built with SQL, Excel, and Power BI, using a procurement dataset covering supplier orders, pricing, delivery, and quality outcomes.

## Objective

Move beyond judging suppliers on price alone by building a composite scorecard that weighs delivery reliability, negotiation savings, and product quality together, and surfaces which suppliers actually perform best overall.

## Tools & Skills Used

- SQL - conditional aggregation (CASE WHEN inside SUM), CTEs, window functions (RANK), date math, filtering logic tied to business rules
- Excel - pivot tables, calculated helper columns, scenario (what-if) modeling
- Power BI - DAX measures (CALCULATE, SUMX, AVERAGEX, DIVIDE, DATEDIFF), dashboard layout and design

## KPIs Calculated

- Order Completion Rate - % of finished orders (Delivered vs. Delivered + Partially Delivered)
- Cancellation Rate - % of all orders that were cancelled
- Average Lead Time - average days between order date and delivery date
- Negotiation Savings % - % saved per order vs. original quoted (Unit) price
- Defect Rate - % of units received that were defective
- Composite Supplier Rank - a ranked score combining completion rate, defect rate, and savings %

All KPIs involving delivery outcomes are filtered to Delivered and Partially Delivered orders only, since Pending and Cancelled orders never resulted in a completed, inspectable transaction.

## Key Insight

The supplier with the strongest negotiated pricing (highest savings %) ranked near the bottom of the composite scorecard once quality was factored in - a notably high defect rate offset the pricing advantage. This is the core argument for scoring suppliers on a blended set of KPIs rather than price alone.

## Query - Composite Supplier Scorecard

The final SQL deliverable combines three KPIs into a single ranked table using a CTE and a window function. Full queries are in procurement_kpi_queries.sql, including the individual per-KPI breakdowns.

CASE WHEN is used inside each SUM() rather than a shared WHERE clause because on_time_pct's numerator and denominator need different subsets of the data (numerator = Delivered only, denominator = Delivered + Partially Delivered), and a single WHERE clause can't apply a narrower filter to one column than another in the same query. The other two KPIs use the same pattern for consistency.

## Excel Analysis

Two pivot tables and one scenario calculation were built to explore the data before formalizing the logic in SQL and Power BI:

- Order Status by Count - a breakdown of all orders by status (Delivered, Partially Delivered, Pending, Cancelled), out of 777 total orders
- Spend by Supplier - total actual spend (Negotiated Price times Quantity) per supplier, filtered to Delivered and Partially Delivered orders
- What-if scenario - modeled shifting 20% of the lowest-ranked supplier's order volume to the highest-ranked supplier, using the difference in savings % between the two. Estimated impact: about $4,281 in additional savings

## Limitations & Assumptions

- The dataset has no expected or promised delivery date field, so "on-time delivery" was renamed to Order Completion Rate. It measures whether orders reached a fully Delivered status, not whether they arrived by a target date.
- Some Defective_Units values are blank rather than 0. These are treated as zero defects in aggregation, since SQL's SUM ignores nulls, so this doesn't affect the defect rate.
- Savings and spend calculations for Partially Delivered orders use the full ordered Quantity, since the dataset has no separate "quantity received" field. This may slightly overstate savings and spend on those specific rows.
- A small discrepancy (around 0.35% of total spend) was found between Excel and Power BI for two suppliers, Beta_Supplies and Epsilon_Group, while the grand total matched exactly in both. This was traced to a data-model issue in Power BI, where a conflict between two tables sharing a Supplier field caused one order to be attributed to the wrong supplier. Excel and SQL, which were cross-checked directly against the raw source data, are treated as the source of truth for exact per-supplier figures.

## How to Reproduce

1. Download the dataset from Kaggle (link below) and import it into a SQLite or similar database as a table named raw_po_data
2. Run procurement_kpi_queries.sql. Queries are ordered from individual KPIs through the final composite scorecard
3. Load the same CSV into Excel and Power BI for the pivot tables and dashboard

## Files

- procurement_kpi_queries.sql - all SQL queries, with comments explaining filtering logic and design decisions
- Power BI dashboard screenshot - visual summary of the KPIs above
- Excel pivot table screenshots - spend by supplier, order count by status

## Dataset

Procurement KPI Analysis Dataset, from Kaggle: https://www.kaggle.com/datasets/shahriarkabir/procurement-kpi-analysis-dataset
