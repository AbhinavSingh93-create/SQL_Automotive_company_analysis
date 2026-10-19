create database atliq_ev;
use atliq_ev;
show tables;

create table electric_vehicle_sales_by_makers(
date varchar(20),
vehicle_category varchar(20),
maker varchar(20),
electric_vehicles_sold int);

select*from electric_vehicle_sales_by_makers;
/*
SHOW VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;
SHOW VARIABLES LIKE 'local_infile';

LOAD DATA INFILE 'C:/Users/abhin/Downloads/Project_2_supplements/Project_2_supplements/datasets/electric_vehicle_sales_by_makers.csv'
INTO TABLE electric_vehicle_sales_by_makers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@date, vehicle_category, maker, electric_vehicles_sold)
SET date = STR_TO_DATE(@date, '%d-%b-%y');

SELECT VERSION();
SELECT @@local_infile;
SHOW VARIABLES LIKE 'secure_file_priv'; 
*/

describe electric_vehicle_sales_by_makers;

ALTER TABLE electric_vehicle_sales_by_makers
ADD COLUMN date_new DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE electric_vehicle_sales_by_makers
SET date_new = STR_TO_DATE(date, '%d-%b-%y');

SET SQL_SAFE_UPDATES = 1;

SELECT date, date_new
FROM electric_vehicle_sales_by_makers
LIMIT 10;

ALTER TABLE electric_vehicle_sales_by_makers
DROP COLUMN date;

ALTER TABLE electric_vehicle_sales_by_makers
CHANGE COLUMN date_new date DATE;

DESCRIBE electric_vehicle_sales_by_makers;

create table electric_vehicle_sales_by_state(
date varchar(20),
state varchar(20),
vehicle_category varchar(30),
electric_vehicles_sold int,
total_vehicles_sold int);

describe electric_vehicle_sales_by_state;

ALTER TABLE electric_vehicle_sales_by_state
ADD COLUMN date_new DATE;

UPDATE electric_vehicle_sales_by_state
SET date_new = STR_TO_DATE(date, '%d-%b-%y');

SELECT date, date_new
FROM electric_vehicle_sales_by_state
LIMIT 10;

ALTER TABLE electric_vehicle_sales_by_state
DROP COLUMN date;

ALTER TABLE electric_vehicle_sales_by_state
CHANGE COLUMN date_new date DATE;

DESCRIBE electric_vehicle_sales_by_state;

create table dim_date(
date varchar(20),
fiscal_year year,
quarter varchar(10));

describe dim_date;

ALTER TABLE dim_date
ADD COLUMN date_new DATE;

UPDATE dim_date
SET date_new = STR_TO_DATE(date, '%d-%b-%y');

SELECT date, date_new
FROM dim_date
LIMIT 10;

ALTER TABLE dim_date
DROP COLUMN date;

ALTER TABLE dim_date
CHANGE COLUMN date_new date DATE;

DESCRIBE dim_date;

/* 1. List the top 3 and bottom 3 makers for the fiscal years 2023 and 2024 in 
terms of the number of 2-wheelers sold. */

WITH maker_sales AS (
    SELECT
        d.fiscal_year,
        m.maker,
        SUM(m.electric_vehicles_sold) AS total_sales
    FROM electric_vehicle_sales_by_makers m
    JOIN dim_date d
        ON m.date = d.date
    WHERE m.vehicle_category = '2-Wheelers'
      AND d.fiscal_year IN (2023, 2024)
    GROUP BY d.fiscal_year, m.maker
),

ranked AS (
    SELECT
        fiscal_year,
        maker,
        total_sales,
        RANK() OVER (
            PARTITION BY fiscal_year
            ORDER BY total_sales DESC
        ) AS top_rank,
        RANK() OVER (
            PARTITION BY fiscal_year
            ORDER BY total_sales ASC
        ) AS bottom_rank
    FROM maker_sales
)

SELECT
    fiscal_year,
    maker,
    total_sales,
    CASE
        WHEN top_rank <= 3 THEN 'TOP 3'
        WHEN bottom_rank <= 3 THEN 'BOTTOM 3'
    END AS category
FROM ranked
WHERE top_rank <= 3
   OR bottom_rank <= 3
ORDER BY fiscal_year, total_sales DESC;
/* Top 3 makers for fiscal year 2023 in terms of 2 wheelers sold are OLA ELECTRIC, OKINAWA ,HERO ELECTRIC.
Top 3 makers for fiscal year 2024 in terms of 2 wheelers sold are OLA ELECTRIC, TVS, ATHER.
Bottom 3 makers for fiscal year 2023 in terms of 2 wheelers sold are PURE EV, BEING,JITENDRA.
Bottom 3 makers for fiscal year 2024 in terms of 2 wheelers sold are KINETIC GREEN, REVOLT, BATTRE ELECTRIC.*/


/* 2.Identify the top 5 states with the highest penetration rate in 2-wheeler 
and 4-wheeler EV sales in FY 2024.*/
WITH state_sales AS (
    SELECT
        s.state,
        s.vehicle_category,
        SUM(s.electric_vehicles_sold) AS ev_sales,
        SUM(s.total_vehicles_sold) AS total_sales
    FROM electric_vehicle_sales_by_state s
    JOIN dim_date d
        ON s.date = d.date
    WHERE d.fiscal_year = 2024
      AND s.vehicle_category IN ('2-Wheelers', '4-Wheelers')
    GROUP BY s.state, s.vehicle_category
),

ranked AS (
    SELECT
        state,
        vehicle_category,
        ev_sales,
        total_sales,
        ROUND(ev_sales * 100.0 / NULLIF(total_sales, 0), 2)
            AS penetration_rate,
        RANK() OVER (
            PARTITION BY vehicle_category
            ORDER BY ev_sales * 100.0 / NULLIF(total_sales, 0) DESC
        ) AS rnk
    FROM state_sales
)

SELECT
    state,
    vehicle_category,
    ev_sales,
    total_sales,
    penetration_rate
FROM ranked
WHERE rnk <= 5
ORDER BY vehicle_category, penetration_rate DESC;
    
   

/* The top 5 states with the highest penetration rate in 2-wheeler 
and 4-wheeler EV sales in FY 2024 are Goa, Kerala, Karnataka, Maharashtra, Delhi */

/* 3. List the states with negative penetration (decline) in EV sales from 2022 
to 2024? */

WITH yearly AS (
    SELECT 
        d.fiscal_year,
        state,
        SUM(electric_vehicles_sold) AS ev_sales,
        SUM(total_vehicles_sold) AS total_sales,
        (SUM(electric_vehicles_sold) / SUM(total_vehicles_sold)) * 100 AS penetration_rate
    FROM electric_vehicle_sales_by_state s
    JOIN dim_date d 
        ON s.date = d.date
    WHERE d.fiscal_year IN (2022, 2024)
    GROUP BY d.fiscal_year, state
)
SELECT
    state,
    MAX(CASE WHEN fiscal_year = 2022 THEN penetration_rate END) AS penetration_2022,
    MAX(CASE WHEN fiscal_year = 2024 THEN penetration_rate END) AS penetration_2024,
    MAX(CASE WHEN fiscal_year = 2024 THEN penetration_rate END)
      - MAX(CASE WHEN fiscal_year = 2022 THEN penetration_rate END) AS change_in_penetration
FROM yearly
GROUP BY state
HAVING penetration_2024 < penetration_2022
ORDER BY change_in_penetration ASC;
/*No State shows a decline in overall EV penetration between FY2022 and FY2024 in supplied dataset.
*/

/* 4.What are the quarterly trends based on sales volume for the top 5 EV 
makers (4-wheelers) from 2022 to 2024? 
*/
WITH maker_total AS
(
    SELECT
        m.maker,
        SUM(m.electric_vehicles_sold) AS total_sales
    FROM electric_vehicle_sales_by_makers m
    JOIN dim_date d
        ON m.date = d.date
    WHERE d.fiscal_year BETWEEN 2022 AND 2024
      AND m.vehicle_category = '4-Wheelers'
    GROUP BY m.maker
),

top_5_makers AS
(
    SELECT
        maker
    FROM maker_total
    ORDER BY total_sales DESC
    LIMIT 5
)

SELECT
    d.fiscal_year,
    d.quarter,
    m.maker,
    SUM(m.electric_vehicles_sold) AS quarterly_sales
FROM electric_vehicle_sales_by_makers m
JOIN dim_date d
    ON m.date = d.date
JOIN top_5_makers t
    ON m.maker = t.maker
WHERE m.vehicle_category = '4-Wheelers'
  AND d.fiscal_year BETWEEN 2022 AND 2024
GROUP BY
    d.fiscal_year,
    d.quarter,
    m.maker
ORDER BY
    d.fiscal_year,
    d.quarter,
    quarterly_sales DESC;
    
    
    /*Top 5 makers identified
1.Tata Motors
2.Mahindra & Mahindra
3.MG Motor
4.BYD India
5.Hyundai Motor

The query gives the complete quarterly trend.

For example, Tata Motors increased from:

FY2022 Q1: 1,031
FY2022 Q4: 5,834
FY2023 Q4: 9,528
FY2024 Q4: 17,361

This shows a strong upward quarterly trajectory.*/

/* 5.How do the EV sales and penetration rates in Delhi compare to 
Karnataka for 2024? */

SELECT
    s.state,
    s.vehicle_category,

    SUM(s.electric_vehicles_sold) AS ev_sales,

    SUM(s.total_vehicles_sold) AS total_vehicle_sales,

    ROUND(
        SUM(s.electric_vehicles_sold) * 100.0 /
        NULLIF(SUM(s.total_vehicles_sold), 0),
        2
    ) AS penetration_rate

FROM electric_vehicle_sales_by_state s
JOIN dim_date d
    ON s.date = d.date

WHERE d.fiscal_year = 2024
  AND s.state IN ('Delhi', 'Karnataka')

GROUP BY
    s.state,
    s.vehicle_category

ORDER BY
    s.state,
    s.vehicle_category;
    
    /*Interpretation

Karnataka has substantially higher EV sales than Delhi in both categories.

However:

1.Karnataka 2W penetration: 11.57%
2.Delhi 2W penetration: 9.40%
3.Delhi 4W penetration: 4.29%
4.Karnataka 4W penetration: 4.26%

So Karnataka leads Delhi strongly in 2-wheelers, while 4-wheeler penetration is almost identical.
*/

/* 6. List down the compounded annual growth rate (CAGR) in 4-wheeler 
units for the top 5 makers from 2022 to 2024. */

WITH maker_sales AS
(
    SELECT
        m.maker,
        d.fiscal_year,
        SUM(m.electric_vehicles_sold) AS sales
    FROM electric_vehicle_sales_by_makers m
    JOIN dim_date d
        ON m.date = d.date
    WHERE d.fiscal_year IN (2022, 2024)
      AND m.vehicle_category = '4-Wheelers'
    GROUP BY
        m.maker,
        d.fiscal_year
),

maker_pivot AS
(
    SELECT
        maker,

        MAX(CASE
            WHEN fiscal_year = 2022
            THEN sales
        END) AS sales_2022,

        MAX(CASE
            WHEN fiscal_year = 2024
            THEN sales
        END) AS sales_2024

    FROM maker_sales
    GROUP BY maker
),

top_5 AS
(
    SELECT *
    FROM maker_pivot
    ORDER BY sales_2024 DESC
    LIMIT 5
)

SELECT
    maker,
    sales_2022,
    sales_2024,

    CASE
        WHEN sales_2022 > 0 THEN
            ROUND(
                (
                    POWER(
                        sales_2024 * 1.0 / sales_2022,
                        1.0 / 2
                    ) - 1
                ) * 100,
                2
            )
        ELSE NULL
    END AS CAGR_percentage

FROM top_5
ORDER BY CAGR_percentage DESC;

/*PCA Automobiles cannot have a mathematically meaningful CAGR because FY2022 sales were zero.*/

/* 7.List down the top 10 states that had the highest compounded annual 
growth rate (CAGR) from 2022 to 2024 in total vehicles sold. */

WITH state_sales AS
(
    SELECT
        s.state,
        d.fiscal_year,
        SUM(s.total_vehicles_sold) AS total_vehicle_sales
    FROM electric_vehicle_sales_by_state s
    JOIN dim_date d
        ON s.date = d.date
    WHERE d.fiscal_year IN (2022, 2024)
    GROUP BY
        s.state,
        d.fiscal_year
),

state_pivot AS
(
    SELECT
        state,

        MAX(CASE
            WHEN fiscal_year = 2022
            THEN total_vehicle_sales
        END) AS sales_2022,

        MAX(CASE
            WHEN fiscal_year = 2024
            THEN total_vehicle_sales
        END) AS sales_2024

    FROM state_sales
    GROUP BY state
)

SELECT
    state,
    sales_2022,
    sales_2024,

    ROUND(
        (
            POWER(
                sales_2024 * 1.0 / NULLIF(sales_2022, 0),
                1.0 / 2
            ) - 1
        ) * 100,
        2
    ) AS CAGR_percentage

FROM state_pivot

WHERE sales_2022 > 0
  AND sales_2024 > 0

ORDER BY CAGR_percentage DESC
LIMIT 10;

/* 8.What are the peak and low season months for EV sales based on the 
data from 2022 to 2024?*/

SELECT
    MONTH(s.date) AS month_number,
    MONTHNAME(s.date) AS month_name,
    SUM(s.electric_vehicles_sold) AS total_ev_sales
FROM electric_vehicle_sales_by_state s
JOIN dim_date d
    ON s.date = d.date
WHERE d.fiscal_year BETWEEN 2022 AND 2024
GROUP BY
    MONTH(s.date),
    MONTHNAME(s.date)
ORDER BY total_ev_sales DESC;

/*Peak month: March — 291,580 EVs

Lowest month: June — 106,708 EVs */

/*Top 3 recommendations for AtliQ Motors

The PDF asks for the top three recommendations.

This is an analysis/recommendation question rather than a direct SQL question.

Based strictly on the supplied EV-sales data, three defensible recommendations are:

Recommendation 1 — Prioritize high-penetration markets

Focus initial EV expansion on states such as:

Goa
Kerala
Karnataka
Maharashtra
Delhi

These are among the strongest FY2024 EV-penetration markets.

Recommendation 2 — Build a strong 4-wheeler EV portfolio

4-wheeler EV sales increased from:

18,577 in FY2022 → 86,901 in FY2024

That is approximately 367.8% growth.

This indicates a rapidly expanding 4-wheeler EV market in the dataset.

Recommendation 3 — Use Karnataka as a strategic priority

Karnataka stands out because it combines:

High EV penetration
High EV sales volume
Strong overall vehicle-market growth
Top-10 state CAGR

Its FY2024 2-wheeler EV penetration is approximately 11.57%, while 4-wheeler penetration is approximately 4.26%*/