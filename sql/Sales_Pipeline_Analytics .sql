--------------------------------------------------------------
-- CRM ANALYSIS --
--------------------------------------------------------------

--1. Pipeline Health 

---1.1. Active Pipeline
SELECT 
	COUNT(*) AS total_leads,
	COUNT(CASE WHEN status NOT IN ('Churned Customer','Customer','Disqualified') 
		THEN 1 END) AS mid_journey_customer,
	COUNT(CASE WHEN actual_close_date IS NOT NULL THEN 1 END) AS terminal_outcomes
FROM sales_pipeline;

---1.2. Won Revenue
SELECT 
	COUNT(*) AS total_lead,
	COUNT(CASE WHEN status = 'Customer' THEN 1 END) AS official_customer,
	ROUND(
		100.0 * COUNT(CASE WHEN status = 'Customer' THEN 1 END) /
		COUNT(*),1
	) AS conv_rate,
	SUM(CASE WHEN status = 'Customer' THEN deal_value_usd END) AS total_rev
FROM sales_pipeline;

---1.3. AVG Days to Close
SELECT
	ROUND(
		AVG(actual_close_date - lead_acquisition_date),0) AS avg_close_days
FROM sales_pipeline
WHERE actual_close_date IS NOT NULL;

---1.4. Current Stage Distribution
SELECT
	status_sequence,
	status,
	COUNT(*)
FROM sales_pipeline
GROUP BY status_sequence, status
ORDER BY status_sequence;

---1.5. Funnel Analyis
WITH status_counts AS (
    SELECT
        SUM(CASE WHEN status = 'New' THEN 1 ELSE 0 END) AS new_cnt,
        SUM(CASE WHEN status = 'Qualified' THEN 1 ELSE 0 END) AS qualified_cnt,
        SUM(CASE WHEN status = 'Disqualified' THEN 1 ELSE 0 END) AS disqualified_cnt,
        SUM(CASE WHEN status = 'Sales Accepted' THEN 1 ELSE 0 END) AS sales_accepted_cnt,
        SUM(CASE WHEN status = 'Opportunity' THEN 1 ELSE 0 END) AS opportunity_cnt,
        SUM(CASE WHEN status = 'Customer' THEN 1 ELSE 0 END) AS customer_cnt,
        SUM(CASE WHEN status = 'Churned Customer' THEN 1 ELSE 0 END) AS churned_customer_cnt,
        COUNT(*) AS total_leads
    FROM sales_pipeline
),

funnel AS (
SELECT
    total_leads AS new_leads,
    total_leads - new_cnt - disqualified_cnt AS qualified,
    disqualified_cnt AS disqualified,
    sales_accepted_cnt + opportunity_cnt + customer_cnt + churned_customer_cnt AS sales_accepted,
    opportunity_cnt + customer_cnt + churned_customer_cnt AS opportunity,
    customer_cnt + churned_customer_cnt AS won,
    churned_customer_cnt AS churn
FROM status_counts
)

SELECT *
FROM funnel;

---1.6. Resolved vs Open Case Rate by Acquisition Month
WITH cohort_summary AS (
	SELECT 
		DATE_TRUNC('month',lead_acquisition_date) AS month,
		COUNT(*) AS total_case,
		SUM(CASE WHEN status IN ('Customer','Churned Customer','Disqualified') 
			THEN 1 ELSE 0 END) AS resolved_case,
		SUM(CASE WHEN status NOT IN ('Customer','Churned Customer','Disqualified') 
			THEN 1 ELSE 0 END) AS open_case
	FROM sales_pipeline
	GROUP BY month
	ORDER BY month
)
SELECT 
	month,
	total_case,
	resolved_case,
	open_case,
	ROUND(100.0 * resolved_case / total_case,2) AS pct_resolved,
	ROUND(100.0 * open_case / total_case,2) As pct_open
FROM cohort_summary; 

---1.7 Leads Current Status by Acquisition Month
SELECT
    TO_CHAR(date_trunc('month',lead_acquisition_date), 'Mon-YYYY') AS month,
	status_sequence AS seq,
    status,
    COUNT(*) AS num_customer,
    SUM(COUNT(*)) OVER (PARTITION BY date_trunc('month',lead_acquisition_date)) AS total_customer,
FROM sales_pipeline
GROUP BY date_trunc('month',lead_acquisition_date), seq, status
ORDER BY date_trunc('month',lead_acquisition_date), seq;


--2. Opportunity Sub-satge Breakdown

SELECT
	stage_sequence,
	stage,
	COUNT(*) As num_customer,
	SUM(deal_value_usd) AS potential_value,
FROM sales_pipeline
WHERE stage_sequence IN (1,2,3,4,5,6)
GROUP BY stage_sequence , stage
ORDER BY stage_sequence;

--3. Geo Distribution & Won Customer by Industry

---3.1. Won customer by Country
SELECT 
    country,
	COUNT(*) AS total_customer,
	COUNT(CASE WHEN status = 'Customer' THEN 1 END) AS won_customer,
	ROUND(
		 100.0 * COUNT(CASE WHEN status = 'Customer' THEN 1 END)/
		 COUNT(*)
	,2) AS conv_rate,
	SUM(CASE WHEN status = 'Customer' THEN deal_value_usd END) AS total_revenue
FROM sales_pipeline
GROUP BY country
ORDER BY total_revenue DESC;

---3.2. Won Customer by Industry
SELECT 
    industry,
	COUNT(*) AS total_customer,
	COUNT(CASE WHEN status = 'Customer' THEN 1 END) AS num_customer,
	ROUND(
		 100.0 * COUNT(CASE WHEN status = 'Customer' THEN 1 END)/
		 COUNT(*)
	,2) AS conv_rate,
	SUM(CASE WHEN status = 'Customer' THEN deal_value_usd END) AS total_revenue
FROM sales_pipeline
GROUP BY industry
ORDER BY total_revenue DESC;

--4. Rep Performance Analysis
---4.1. Overview of Closed Deal Analysis
SELECT
	COUNT(*) AS total_closed_deal,
	COUNT(CASE WHEN status = 'Customer' THEN 1 END) AS won_customer,
	ROUND(100.0 * COUNT(CASE WHEN status = 'Customer' THEN 1 END) / COUNT(*),2) AS win_rate,
	COUNT(CASE WHEN status = 'Churned Customer' THEN 1 END) AS churn_customer,
	ROUND(100.0 * COUNT(CASE WHEN status = 'Churned Customer' THEN 1 END) / COUNT(*),2) AS churn_rate
FROM sales_pipeline
WHERE actual_close_date IS NOT NULL;

---4.2. Closed Deal Analysis by Rep
SELECT
	owner,
	COUNT(*) AS total_closed_deal,
	COUNT(CASE WHEN status = 'Customer' THEN 1 END) AS won_customer,
	ROUND(100.0 * COUNT(CASE WHEN status = 'Customer' THEN 1 END) / COUNT(*),1) AS win_rate,
	SUM(CASE WHEN status = 'Customer' THEN deal_value_usd END) AS won_revenue,
	COUNT(CASE WHEN status = 'Churned Customer' THEN 1 END) AS churn_customer,
	ROUND(100.0 * COUNT(CASE WHEN status = 'Churned Customer' THEN 1 END) / COUNT(*),1) AS churn_rate,
	SUM(CASE WHEN status = 'Churned Customer' THEN deal_value_usd END) AS revenue_loss
FROM sales_pipeline
WHERE actual_close_date IS NOT NULL
GROUP BY owner
ORDER BY win_rate DESC;

---4.3. Average Close Days by Rep
SELECT
	owner,
	ROUND(AVG(actual_close_date - lead_acquisition_date),1) AS avg_close_days
FROM sales_pipeline
WHERE actual_close_date IS NOT NULL
GROUP BY owner
ORDER BY avg_close_days DESC;

---4.5 Case Distribution
SELECT 
	owner,
	COUNT(CASE WHEN status = 'Disqualified' THEN 1 END) AS disqualified_case,
	COUNT(CASE WHEN status IN ('Customer','Churned Customer') THEN 1 END) AS closed_case,
	COUNT(CASE WHEN status NOT IN ('Customer','Churned Customer') THEN 1 END) AS open_case
FROM sales_pipeline
GROUP BY owner;

---4.6 Opportunity Sub-stage Breakdown by Rep
SELECT
	owner,
    COUNT(CASE WHEN stage = 'Won' THEN 1 END ) AS oppo_won,
	COUNT(CASE WHEN stage = 'Lost' THEN 1 END) AS oppo_lost,
	COUNT(CASE WHEN stage NOT IN ('Won','Lost') THEN 1 END) oppo_processing,
	SUM(COUNT(*)) OVER (PARTITION BY owner) AS total_customer
FROM sales_pipeline
WHERE stage_sequence IN (1,2,3,4,5,6)
GROUP BY owner
ORDER BY owner;
 
--5. Lost Opportunities

---5.1 Loss Value (Churned Customer, Disqualified and Opportunity Lost)
SELECT
	SUM(deal_value_usd) AS expected_loss
FROM sales_pipeline
WHERE status IN ('Disqualified','Churned Customer') 
	OR status = 'Opportunity' AND stage = 'Lost';

---5.2 Industry Loss Rate
SELECT 
    industry,
	SUM(deal_value_usd) AS deal_value_loss
FROM sales_pipeline
WHERE status IN ('Disqualified','Churned Customer') 
	OR status = 'Opportunity' AND stage = 'Lost'
GROUP BY industry
ORDER BY deal_value_loss DESC;

--6. Accuracy Check Between Actual Close Date and Expected Close Date
SELECT 
    COUNT(CASE WHEN actual_close_date > expected_close_date THEN 1 END) AS longer_case_close,
	COUNT(CASE WHEN actual_close_date < expected_close_date THEN 1 END) AS fast_case_close,
	COUNT(CASE WHEN actual_close_date = expected_close_date THEN 1 END) AS expected_case_close
FROM sales_pipeline
WHERE actual_close_date IS NOT NULL;




	