USE ecomm;
-- Select the database and check missing values
SELECT COUNT(*) AS TotalCustomers
FROM customer_churn;

SELECT
    SUM(WarehouseToHome IS NULL) AS Missing_WarehouseToHome,
    SUM(HourSpendOnApp IS NULL) AS Missing_HourSpendOnApp,
    SUM(OrderAmountHikeFromlastYear IS NULL) AS Missing_OrderAmountHike,
    SUM(DaySinceLastOrder IS NULL) AS Missing_DaySinceLastOrder,
    SUM(Tenure IS NULL) AS Missing_Tenure,
    SUM(CouponUsed IS NULL) AS Missing_CouponUsed,
    SUM(OrderCount IS NULL) AS Missing_OrderCount
FROM customer_churn;

-- Impute missing values using the mean
SET SQL_SAFE_UPDATES = 0;
UPDATE customer_churn
SET WarehouseToHome = (
    SELECT mean_value
    FROM (
        SELECT ROUND(AVG(WarehouseToHome)) AS mean_value
        FROM customer_churn
    ) AS temp
)
WHERE WarehouseToHome IS NULL;


UPDATE customer_churn
SET HourSpendOnApp = (
    SELECT mean_value
    FROM (
        SELECT ROUND(AVG(HourSpendOnApp)) AS mean_value
        FROM customer_churn
    ) AS temp
)
WHERE HourSpendOnApp IS NULL;

UPDATE customer_churn
SET OrderAmountHikeFromlastYear = (
    SELECT mean_value
    FROM (
        SELECT ROUND(AVG(OrderAmountHikeFromlastYear)) AS mean_value
        FROM customer_churn
    ) AS temp
)
WHERE OrderAmountHikeFromlastYear IS NULL;

UPDATE customer_churn
SET DaySinceLastOrder = (
    SELECT mean_value
    FROM (
        SELECT ROUND(AVG(DaySinceLastOrder)) AS mean_value
        FROM customer_churn
    ) AS temp
)
WHERE DaySinceLastOrder IS NULL;

-- Impute missing values using the mode

UPDATE customer_churn
SET Tenure = (
    SELECT mode_value
    FROM (
        SELECT Tenure AS mode_value
        FROM customer_churn
        WHERE Tenure IS NOT NULL
        GROUP BY Tenure
        ORDER BY COUNT(*) DESC, Tenure ASC
        LIMIT 1
    ) AS temp
)
WHERE Tenure IS NULL;

-- For CouponUsed

UPDATE customer_churn
SET CouponUsed = (
    SELECT mode_value
    FROM (
        SELECT CouponUsed AS mode_value
        FROM customer_churn
        WHERE CouponUsed IS NOT NULL
        GROUP BY CouponUsed
        ORDER BY COUNT(*) DESC, CouponUsed ASC
        LIMIT 1
    ) AS temp
)
WHERE CouponUsed IS NULL;

-- For OrderCount:

UPDATE customer_churn
SET OrderCount = (
    SELECT mode_value
    FROM (
        SELECT OrderCount AS mode_value
        FROM customer_churn
        WHERE OrderCount IS NOT NULL
        GROUP BY OrderCount
        ORDER BY COUNT(*) DESC, OrderCount ASC
        LIMIT 1
    ) AS temp
)
WHERE OrderCount IS NULL;

-- Delete warehouse-distance outliers

SELECT *
FROM customer_churn
WHERE WarehouseToHome > 100;

DELETE FROM customer_churn
WHERE WarehouseToHome > 100;

-- Dealing with Inconsistencies:
-- Replace Phone with Mobile Phone:
UPDATE customer_churn
SET PreferredLoginDevice = 'Mobile Phone'
WHERE PreferredLoginDevice = 'Phone';

-- Replace Mobile with Mobile Phone:
UPDATE customer_churn
SET PreferedOrderCat = 'Mobile Phone'
WHERE PreferedOrderCat = 'Mobile';

-- Replace COD with Cash on Delivery and CC with Credit Card:

UPDATE customer_churn
SET PreferredPaymentMode =
    CASE
        WHEN PreferredPaymentMode = 'COD'
            THEN 'Cash on Delivery'
        WHEN PreferredPaymentMode = 'CC'
            THEN 'Credit Card'
        ELSE PreferredPaymentMode
    END
WHERE PreferredPaymentMode IN ('COD', 'CC');

SELECT
    SUM(WarehouseToHome IS NULL) AS Missing_Warehouse,
    SUM(HourSpendOnApp IS NULL) AS Missing_AppHours,
    SUM(OrderAmountHikeFromlastYear IS NULL) AS Missing_OrderHike,
    SUM(DaySinceLastOrder IS NULL) AS Missing_LastOrderDays,
    SUM(Tenure IS NULL) AS Missing_Tenure,
    SUM(CouponUsed IS NULL) AS Missing_Coupons,
    SUM(OrderCount IS NULL) AS Missing_OrderCount
FROM customer_churn;

-- Data Transformation:
-- Column Renaming:
ALTER TABLE customer_churn
RENAME COLUMN PreferedOrderCat TO PreferredOrderCat;

ALTER TABLE customer_churn
RENAME COLUMN HourSpendOnApp TO HoursSpentOnApp;

-- Creating New Columns:

ALTER TABLE customer_churn
ADD COLUMN ComplaintReceived VARCHAR(3);

UPDATE customer_churn
SET ComplaintReceived =
    CASE
        WHEN Complain = 1 THEN 'Yes'
        ELSE 'No'
    END;

-- Create the ChurnStatus column
ALTER TABLE customer_churn
ADD COLUMN ChurnStatus VARCHAR(10);

UPDATE customer_churn
SET ChurnStatus =
    CASE
        WHEN Churn = 1 THEN 'Churned'
        ELSE 'Active'
    END;
SELECT Complain, ComplaintReceived, Churn, ChurnStatus
FROM customer_churn
LIMIT 10;

-- Column Dropping:

ALTER TABLE customer_churn
DROP COLUMN Churn,
DROP COLUMN Complain;

DESCRIBE customer_churn;

-- Data Exploration and Analysis:

-- Count churned and active customers
SELECT ChurnStatus, COUNT(*) AS TotalCustomers
FROM customer_churn
GROUP BY ChurnStatus;

-- Average tenure and total cashback of churned customers

SELECT
    AVG(Tenure) AS AverageTenure,
    SUM(CashbackAmount) AS TotalCashback
FROM customer_churn
WHERE ChurnStatus = 'Churned';

-- Percentage of churned customers who complained

SELECT
    ROUND(
        SUM(CASE WHEN ComplaintReceived = 'Yes' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS ComplaintPercentage
FROM customer_churn
WHERE ChurnStatus = 'Churned';

-- City tier with the most churned customers who prefer Laptop & Accessory

SELECT CityTier, COUNT(*) AS ChurnedCustomers
FROM customer_churn
WHERE ChurnStatus = 'Churned'
  AND PreferredOrderCat = 'Laptop & Accessory'
GROUP BY CityTier
ORDER BY ChurnedCustomers DESC
LIMIT 1;

-- Most preferred payment mode among active customers
SELECT PreferredPaymentMode, COUNT(*) AS TotalCustomers
FROM customer_churn
WHERE ChurnStatus = 'Active'
GROUP BY PreferredPaymentMode
ORDER BY TotalCustomers DESC
LIMIT 1;

-- Total order amount hike for single customers who prefer mobile phones

SELECT SUM(OrderAmountHikeFromlastYear) AS TotalOrderAmountHike
FROM customer_churn
WHERE MaritalStatus = 'Single'
  AND PreferredOrderCat = 'Mobile Phone';
  
  -- Average number of registered devices among customers using UPI
  SELECT AVG(NumberOfDeviceRegistered) AS AverageRegisteredDevices
FROM customer_churn
WHERE PreferredPaymentMode = 'UPI';

-- City tier with the highest number of customers
SELECT CityTier, COUNT(*) AS TotalCustomers
FROM customer_churn
GROUP BY CityTier
ORDER BY TotalCustomers DESC
LIMIT 1;

-- Gender that used the highest number of coupons
SELECT Gender, SUM(CouponUsed) AS TotalCouponsUsed
FROM customer_churn
GROUP BY Gender
ORDER BY TotalCouponsUsed DESC
LIMIT 1;

-- Customer count and maximum app hours for each order category
SELECT
    PreferredOrderCat,
    COUNT(*) AS TotalCustomers,
    MAX(HoursSpentOnApp) AS MaximumHoursSpent
FROM customer_churn
GROUP BY PreferredOrderCat;

-- Total order count for credit-card customers with the maximum satisfaction score
SELECT SUM(OrderCount) AS TotalOrderCount
FROM customer_churn
WHERE PreferredPaymentMode = 'Credit Card'
  AND SatisfactionScore = (
      SELECT MAX(SatisfactionScore)
      FROM customer_churn
  );
  
  -- Average satisfaction score of customers who complained
  
  SELECT AVG(SatisfactionScore) AS AverageSatisfactionScore
FROM customer_churn
WHERE ComplaintReceived = 'Yes';

-- Preferred order categories among customers who used more than 5 coupons

SELECT DISTINCT PreferredOrderCat
FROM customer_churn
WHERE CouponUsed > 5;

-- Top 3 order categories with the highest average cashback

SELECT
    PreferredOrderCat,
    ROUND(AVG(CashbackAmount), 2) AS AverageCashback
FROM customer_churn
GROUP BY PreferredOrderCat
ORDER BY AverageCashback DESC
LIMIT 3;

-- Preferred payment modes for customers with average tenure of 10 months and more than 500 orders

SELECT
    PreferredPaymentMode,
    ROUND(AVG(Tenure), 2) AS AverageTenure,
    SUM(OrderCount) AS TotalOrders
FROM customer_churn
GROUP BY PreferredPaymentMode
HAVING ROUND(AVG(Tenure), 0) = 10
   AND SUM(OrderCount) > 500;
   
   -- Churn status breakdown by warehouse-to-home distance
   
   SELECT
    CASE
        WHEN WarehouseToHome <= 5 THEN 'Very Close Distance'
        WHEN WarehouseToHome <= 10 THEN 'Close Distance'
        WHEN WarehouseToHome <= 15 THEN 'Moderate Distance'
        ELSE 'Far Distance'
    END AS DistanceCategory,
    ChurnStatus,
    COUNT(*) AS TotalCustomers
FROM customer_churn
GROUP BY DistanceCategory, ChurnStatus
ORDER BY
    CASE DistanceCategory
        WHEN 'Very Close Distance' THEN 1
        WHEN 'Close Distance' THEN 2
        WHEN 'Moderate Distance' THEN 3
        WHEN 'Far Distance' THEN 4
    END,
    ChurnStatus;
    
    -- Married customers in City Tier 1 whose order count is above average
    
    SELECT *
FROM customer_churn
WHERE MaritalStatus = 'Married'
  AND CityTier = 1
  AND OrderCount > (
      SELECT AVG(OrderCount)
      FROM customer_churn
  );
  
  -- Create the customer_returns table and insert the data
CREATE TABLE customer_returns (
    ReturnID INT PRIMARY KEY,
    CustomerID INT,
    ReturnDate DATE,
    RefundAmount DECIMAL(10, 2)
);

-- Insert the eight return records

INSERT INTO customer_returns
    (ReturnID, CustomerID, ReturnDate, RefundAmount)
VALUES
    (1001, 50022, '2023-01-01', 2130),
    (1002, 50316, '2023-01-23', 2000),
    (1003, 51099, '2023-02-14', 2290),
    (1004, 52321, '2023-03-08', 2510),
    (1005, 52928, '2023-03-20', 3000),
    (1006, 53749, '2023-04-17', 1740),
    (1007, 54206, '2023-04-21', 3250),
    (1008, 54838, '2023-04-30', 1990);
    
    -- Display return details and customer details for customers who churned and complained
  DESCRIBE customer_churn;
    

SELECT
    r.ReturnID,
    r.CustomerID,
    r.ReturnDate,
    r.RefundAmount,
    c.Tenure,
    c.Gender,
    c.CityTier,
    c.MaritalStatus,
    c.PreferredOrderCat,
    c.PreferredPaymentMode,
    c.SatisfactionScore,
    c.ComplaintReceived,
    c.ChurnStatus
FROM customer_returns AS r
INNER JOIN customer_churn AS c
    ON r.CustomerID = c.CustomerID
WHERE c.ChurnStatus = 'Churned'
  AND c.ComplaintReceived = 'Yes';
    
    



