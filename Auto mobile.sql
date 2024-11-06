-- joining the datasets and creating a table named Joined datasets
CREATE TABLE new_sche.`Joined_dataset` AS
(
    SELECT
        electric_vehicle_sales_by_state.ï»¿date,
        electric_vehicle_sales_by_state.state,
        electric_vehicle_sales_by_state.vehicle_category,
        electric_vehicle_sales_by_state.electric_vehicles_sold,
        electric_vehicle_sales_by_state.total_vehicles_sold,
        electric_vehicle_sales_by_makers.maker,
        electric_vehicle_sales_by_makers.electric_vehicles_sold AS VM,
        dim_date.fiscal_year,
        dim_date.quarter
    FROM
        new_sche.electric_vehicle_sales_by_state
    JOIN
        new_sche.electric_vehicle_sales_by_makers
    ON
        electric_vehicle_sales_by_state.vehicle_category = electric_vehicle_sales_by_makers.vehicle_category
    JOIN
        dim_date 
    ON
        electric_vehicle_sales_by_makers.date = dim_date.ï»¿date
);

CREATE TABLE new_sche.`Top_and_bottom_3_makers` AS
 (
(
    -- Top 3 makers in terms of 2-wheelers sold for fiscal years 2023 and 2024
    SELECT
        maker,
        fiscal_year,
        SUM(VM) AS total_2wheelers_sold
    FROM
        new_sche.`Joined_dataset`
    WHERE
        vehicle_category = '2-Wheelers'
        AND fiscal_year IN (2023, 2024)
    GROUP BY
        maker, fiscal_year
    ORDER BY
        total_2wheelers_sold DESC
    LIMIT 3
)
UNION ALL
(
    -- Bottom 3 makers in terms of 2-wheelers sold for fiscal years 2023 and 2024
    SELECT
        maker,
        fiscal_year,
        SUM(VM) AS total_2wheelers_sold
    FROM
        new_sche.`Joined_dataset`
    WHERE
        vehicle_category = '2-Wheelers'
        AND fiscal_year IN (2023, 2024)
    GROUP BY
        maker, fiscal_year
    ORDER BY
        total_2wheelers_sold ASC
    LIMIT 3
)
);


-- penetration rate is the ratio of the number of electric vehicles sold (both 2-wheelers and 4-wheelers) to the total number of vehicles sold in that state.
-- Identify the top 5 states with the highest penetration rate in 2-wheeler and 4-wheeler EV sales in FY 2024 
CREATE TABLE new_sche.`Top_5_penetration_rate_state` AS
(
WITH EV_Sales AS (
    SELECT
        state,
        vehicle_category,
        SUM(electric_vehicles_sold) AS total_ev_sold,
        SUM(total_vehicles_sold) AS total_vehicles_sold
    FROM
        new_sche.`Joined_dataset`
    WHERE
        fiscal_year = 2024
        AND vehicle_category IN ('2-Wheelers', '4-Wheelers')
    GROUP BY
        state, vehicle_category
),

Penetration_Rate AS (
    SELECT
        state,
        SUM(total_ev_sold) AS total_ev_sold,
        SUM(total_vehicles_sold) AS total_vehicles_sold,
        (SUM(total_ev_sold) / SUM(total_vehicles_sold)) * 100 AS penetration_rate
    FROM
        EV_Sales
    GROUP BY
        state
)

SELECT
    state,
    total_ev_sold,
    total_vehicles_sold,
    penetration_rate
FROM
    Penetration_Rate
ORDER BY
    penetration_rate DESC
LIMIT 5
);


-- states with negative penetration (decline) in EV sales from 2022 to 2024
CREATE TABLE new_sche.`States_with_decline_penetration_in_EV_sales` AS
(
WITH EV_Sales AS (
    SELECT
        state,
        fiscal_year,
        SUM(electric_vehicles_sold) AS total_ev_sold,
        SUM(total_vehicles_sold) AS total_vehicles_sold
    FROM
        new_sche.`Joined_dataset`
    WHERE
        fiscal_year IN (2022, 2024)
        AND vehicle_category IN ('2-Wheelers', '4-Wheelers')
    GROUP BY
        state, fiscal_year
),

Penetration_Rate AS (
    SELECT
        state,
        MAX(CASE WHEN fiscal_year = 2022 THEN (total_ev_sold / total_vehicles_sold) * 100 ELSE NULL END) AS penetration_rate_2022,
        MAX(CASE WHEN fiscal_year = 2024 THEN (total_ev_sold / total_vehicles_sold) * 100 ELSE NULL END) AS penetration_rate_2024
    FROM
        EV_Sales
    GROUP BY
        state
)

SELECT
    state,
    penetration_rate_2022,
    penetration_rate_2024
FROM
    Penetration_Rate
WHERE
    penetration_rate_2024 < penetration_rate_2022
    );

-- quarterly trends based on sales volume for the top 5 EV makers (4-wheelers) from 2022 to 2024
CREATE TABLE new_sche.`Quarterly_trends` AS
(
WITH Quarterly_Sales AS (
    SELECT
        maker,
        fiscal_year,
        quarter,
        SUM(electric_vehicles_sold) AS total_sales
    FROM
        new_sche.`Joined_dataset`
    WHERE
        vehicle_category = '4-Wheelers'
        AND fiscal_year IN (2022, 2024)
    GROUP BY
        maker, fiscal_year, quarter
),

Top_Makers AS (
    SELECT
        maker,
        SUM(total_sales) AS total_sales
    FROM
        Quarterly_Sales
    GROUP BY
        maker
    ORDER BY
        total_sales DESC
    LIMIT 5
)

SELECT
    Quarterly_Sales.maker,
    Quarterly_Sales.fiscal_year,
    Quarterly_Sales.quarter,
    Quarterly_Sales.total_sales
FROM
    Quarterly_Sales 
JOIN
    Top_Makers  ON Quarterly_Sales.maker = Top_Makers.maker
ORDER BY
    Quarterly_Sales.maker, Quarterly_Sales.fiscal_year, Quarterly_Sales.quarter
    );
    
    -- how EV sales and penetration rates in Delhi compare to Karnataka for 2024
    CREATE TABLE new_sche.`Comparison_of_Delhi_and_Karnataka` AS
    (
    WITH EV_Sales AS (
    SELECT
        state,
        SUM(electric_vehicles_sold) AS total_ev_sold,
        SUM(total_vehicles_sold) AS total_vehicles_sold
    FROM
        new_sche.`Joined_dataset`
    WHERE
        fiscal_year = 2024
        AND state IN ('Delhi', 'Karnataka')
    GROUP BY
        state
),

Penetration_Rates AS (
    SELECT
        state,
        total_ev_sold,
        total_vehicles_sold,
        (total_ev_sold / total_vehicles_sold) * 100 AS penetration_rate
    FROM
        EV_Sales
)

SELECT
    state,
    total_ev_sold,
    total_vehicles_sold,
    penetration_rate
FROM
    Penetration_Rates
    );


-- compounded annual growth rate (CAGR) in 4-wheeler units for the top 5 makers from 2022 to 2024
CREATE TABLE new_sche.`Compound_annual_growth` AS
(
WITH SalesData AS (
    -- Aggregate sales for each maker per year
    SELECT
        maker,
        fiscal_year,
        SUM(electric_vehicles_sold) AS total_sales
    FROM
        new_sche.`Joined_dataset`
    WHERE
        vehicle_category = '4-Wheelers'
        AND fiscal_year IN (2022, 2024)
    GROUP BY
        maker, fiscal_year
),

Top_Makers AS (
    -- Identify the top 5 makers based on total sales between 2022 and 2024
    SELECT
        maker,
        SUM(total_sales) AS total_sales
    FROM
        SalesData
    GROUP BY
        maker
    ORDER BY
        total_sales DESC
    LIMIT 5
),

CAGR_Calculation AS (
    -- Retrieve sales for the top 5 makers for 2022 and 2024
    SELECT
        sd.maker,
        sd.fiscal_year,
        sd.total_sales
    FROM
        SalesData sd
    JOIN
        Top_Makers tm ON sd.maker = tm.maker
),

CAGR_Results AS (
    -- Calculate CAGR for each maker
    SELECT
        maker,
        MAX(CASE WHEN fiscal_year = 2024 THEN total_sales END) AS sales_2024,
        MAX(CASE WHEN fiscal_year = 2022 THEN total_sales END) AS sales_2022,
        POWER(MAX(CASE WHEN fiscal_year = 2024 THEN total_sales END) /
              MAX(CASE WHEN fiscal_year = 2022 THEN total_sales END), 1.0/2) - 1 AS CAGR
    FROM
        CAGR_Calculation
    GROUP BY
        maker
)

-- Final selection of results
SELECT
    maker,
    sales_2022,
    sales_2024,
    ROUND(CAGR * 100, 2) AS CAGR_percentage
FROM
    CAGR_Results
);

--  top 10 states that had the highest compounded annual growth rate (CAGR) from 2022 to 2024 in total vehicles sold
CREATE TABLE new_sche.`top_10_states_with_the_highest_CAGR` AS
(
WITH State_Sales AS (
    -- Aggregate total vehicles sold for each state in 2022 and 2024
    SELECT
        state,
        fiscal_year,
        SUM(total_vehicles_sold) AS total_vehicles_sold
    FROM
        new_sche.`Joined_dataset`
    WHERE
        fiscal_year IN (2022, 2024)
    GROUP BY
        state, fiscal_year
),

CAGR_Calculation AS (
    -- Calculate the CAGR for each state
    SELECT
        state,
        MAX(CASE WHEN fiscal_year = 2024 THEN total_vehicles_sold END) AS sales_2024,
        MAX(CASE WHEN fiscal_year = 2022 THEN total_vehicles_sold END) AS sales_2022,
        POWER(MAX(CASE WHEN fiscal_year = 2024 THEN total_vehicles_sold END) /
              MAX(CASE WHEN fiscal_year = 2022 THEN total_vehicles_sold END), 1.0/2) - 1 AS CAGR
    FROM
        State_Sales
    GROUP BY
        state
),

Top_States AS (
    -- Rank states based on CAGR
    SELECT
        state,
        sales_2022,
        sales_2024,
        ROUND(CAGR * 100, 2) AS CAGR_percentage
    FROM
        CAGR_Calculation
    ORDER BY
        CAGR DESC
    LIMIT 10
)

-- Final selection of top 10 states
SELECT
    state,
    sales_2022,
    sales_2024,
    CAGR_percentage
FROM
    Top_States
    );


-- peak and low season months for EV sales based on the data from 2022 to 2024?
CREATE TABLE new_sche.`Peak_and_low_season_months_for_EV` AS
(
(
    -- Peak season months for EV sales
    SELECT
        DATE_FORMAT(STR_TO_DATE(ï»¿date, '%d-%b-%y'), '%m') AS sales_month,
        SUM(electric_vehicles_sold) AS total_ev_sales
    FROM
        new_sche.joined_dataset
    WHERE
        fiscal_year BETWEEN 2022 AND 2024
    GROUP BY
        sales_month
    ORDER BY
        total_ev_sales DESC
    LIMIT 3
) 
UNION ALL
(
    -- Low season months for EV sales
    SELECT
        DATE_FORMAT(STR_TO_DATE(ï»¿date, '%d-%b-%y'), '%m') AS sales_month,
        SUM(electric_vehicles_sold) AS total_ev_sales
    FROM
        new_sche.joined_dataset
    WHERE
        fiscal_year BETWEEN 2022 AND 2024
    GROUP BY
        sales_month
    ORDER BY
        total_ev_sales ASC
    LIMIT 3
)
);


-- the projected number of EV sales (including 2-wheelers and 4-wheelers) for the top 10 states by penetration rate in 2030, based on the compounded annual growth rate (CAGR) from previous years
CREATE TABLE new_sche.`Projected_number_of_EV` AS
(
WITH SalesData AS (
    SELECT 
        state,
        SUM(CASE WHEN fiscal_year = 2024 THEN electric_vehicles_sold END) AS sales_2024,
        SUM(CASE WHEN fiscal_year = 2022 THEN electric_vehicles_sold END) AS sales_2022
    FROM 
        new_sche.joined_dataset
    WHERE 
        fiscal_year IN (2022, 2024)
    GROUP BY 
        state
),
CAGR_Calculation AS (
    SELECT 
        state,
        sales_2022,
        sales_2024,
        (POWER(sales_2024 / NULLIF(sales_2022, 0), 1.0/2) - 1) AS CAGR
    FROM 
        SalesData
),
ProjectedSales AS (
    SELECT 
        state,
        sales_2024,
        CAGR,
        sales_2024* POWER((1 + CAGR), 6) AS projected_sales_2030
    FROM 
        CAGR_Calculation
)

SELECT 
    state, 
    projected_sales_2030
FROM 
    ProjectedSales
ORDER BY 
    projected_sales_2030 DESC
LIMIT 10
);



-- the revenue growth rate of 4-wheeler and 2-wheelers in India for 2022 vs 2024 and 2023 vs 2024, assuming an average unit price
CREATE TABLE new_sche.`revenue_growth_rate` AS
(
WITH Revenue AS (
    SELECT 
        vehicle_category,
        fiscal_year,
        SUM(electric_vehicles_sold) AS total_units_sold,
        CASE 
            WHEN vehicle_category = '2-Wheelers' THEN 85000
            WHEN vehicle_category = '4-Wheelers' THEN 1500000
        END AS average_price,
        SUM(electric_vehicles_sold) * 
        CASE 
            WHEN vehicle_category = '2-Wheelers' THEN 85000
            WHEN vehicle_category = '4-Wheelers' THEN 1500000
        END AS total_revenue
    FROM 
        new_sche.joined_dataset
    WHERE 
        vehicle_category IN ('2-Wheelers', '4-Wheelers') AND 
        fiscal_year IN (2022, 2023, 2024)
    GROUP BY 
        vehicle_category, fiscal_year
),

GrowthRates AS (
    SELECT 
        vehicle_category,
        MAX(CASE WHEN fiscal_year = 2024 THEN total_revenue END) AS revenue_2024,
        MAX(CASE WHEN fiscal_year = 2022 THEN total_revenue END) AS revenue_2022,
        MAX(CASE WHEN fiscal_year = 2023 THEN total_revenue END) AS revenue_2023
    FROM 
        Revenue
    GROUP BY 
        vehicle_category
)

SELECT 
    vehicle_category,
    ((revenue_2024 - revenue_2022) / NULLIF(revenue_2022, 0)) * 100 AS growth_rate_2022_to_2024,
    ((revenue_2024 - revenue_2023) / NULLIF(revenue_2023, 0)) * 100 AS growth_rate_2023_to_2024
FROM 
    GrowthRates
    );
    
