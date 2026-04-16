-- 1 ЗАДАНИЕ - 
-- 1 PART

-- Считаем сколько месяцев transactions делали клиенты
-- Calculate customer activity consistency by counting distinct active months
SELECT id_client, COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) AS active_months
FROM transactions
WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
GROUP BY id_client
ORDER BY active_months desc;

-- Выбираем только тех, у кого были transactions каждый месяц, я создаю временную таблицу:
-- Create a temporary table of customers with continuous monthly activity
-- (customers who made transactions in all 12 months within the selected period) 

CREATE TEMPORARY TABLE continuous_monthly_transactions AS 
SELECT id_client
FROM transactions
WHERE  date_new >= '2015-06-01' AND date_new < '2016-06-01'
GROUP BY id_client
HAVING COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m'))=12;

SELECT*
FROM continuous_monthly_transactions;

-- Средний чек клиента который проводил непрерывные транзакции каждый месяц
-- Calculate the average transaction value (average check) 
-- for customers with continuous monthly activity

SELECT id_client, ROUND(AVG(sum_payment),2) AS average_transaction_value
FROM transactions
WHERE id_client IN (SELECT id_client FROM continuous_monthly_transactions)
GROUP BY id_client;

-- проверка через JOIN
-- Validate the average transaction value calculation using JOIN
-- (alternative approach to filtering customers with continuous activity)

SELECT t.id_client, ROUND(AVG(t.sum_payment), 2) AS average_transaction_value
FROM transactions t
JOIN continuous_monthly_transactions  c ON t.id_client = c.id_client
GROUP BY t.id_client;

-- Средняя сумма покупок за каждый месяц по клиентам которые непрерывно делали транзакции
-- Calculate the average monthly transaction value for customers 
-- with continuous activity (monthly breakdown per customer)

SELECT t.id_client, DATE_FORMAT(t.date_new, '%Y-%m') AS transaction_month, ROUND(AVG(t.sum_payment),2) AS avg_monthly_transaction_value
FROM transactions t
JOIN continuous_monthly_transactions c ON t.id_client = c.id_client
WHERE t.date_new >= '2015-06-01' AND date_new < '2016-06-01'
GROUP BY t.id_client, transaction_month
ORDER BY t.id_client, transaction_month; 

-- Количество всех операции по клиенту
-- Count total number of transactions per customer per month
-- for customers with continuous monthly activity

SELECT t.id_client, DATE_FORMAT(t.date_new, '%Y-%m') AS transaction_month, COUNT(t.id_check) AS total_transactions
FROM transactions t 
JOIN continuous_monthly_transactions c ON t.id_client = c.id_client
WHERE t.date_new >= '2015-06-01' AND date_new < '2016-06-01'
GROUP BY t.id_client, transaction_month
ORDER BY t.id_client, transaction_month; 

-- 2 ЗАДАНИЕ
-- 2 PART

-- Средняя сумма чека в месяц 
-- Calculate average transaction value per month (average check)
SELECT DATE_FORMAT(date_new, '%Y-%m') AS transaction_month, ROUND(AVG(sum_payment),2) AS avg_transaction_value
FROM transactions
GROUP BY transaction_month;

-- Среднее количество операций в месяц
-- Calculate average number of transactions per month

SELECT AVG(month_operations) AS avg_transactions_per_month
FROM (
SELECT DATE_FORMAT(date_new, '%Y-%m') AS transaction_month, COUNT(id_check) AS month_operations
FROM transactions
GROUP BY transaction_month
) t;

-- Доля от общего количества операций за год и долю в месяц от общей суммы операций;
-- Calculate monthly share of total number of transactions

SELECT DATE_FORMAT(date_new, '%Y-%m') AS month, COUNT(*) AS month_operations,
COUNT(*) * 100.0 / (SELECT COUNT(*) 
FROM transactions) AS operations_share
FROM transactions
GROUP BY month;

-- Вывести % соотношение M/F/NA в каждом месяце с их долей затрат;
-- Gender-based monthly revenue contribution and customer activity distribution

SELECT DATE_FORMAT(t.date_new, '%Y-%m') AS month, c.gender,
COUNT(DISTINCT t.id_client) AS total_clients,
COUNT(*) AS client_operations,
SUM(t.sum_payment) AS total_spend,
SUM(t.sum_payment) * 100.0 /
SUM(SUM(t.sum_payment)) OVER (PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m')) AS spend_share_percent
FROM transactions t
JOIN customers c ON t.id_client = c.id_client
GROUP BY month, c.gender;

-- 3 Задание

-- проверяю мин и макс возраст
-- min, max age checking
SELECT 	
MIN(age), MAX(age)
FROM customers;

-- создаю временную таблицу для группировки по возрасту
-- Create a temporary table for customer age segmentation
-- (grouping customers into 10-year age buckets + missing values)

CREATE TEMPORARY TABLE age_table AS
SELECT id_client,
CASE
WHEN age IS NULL THEN 'No age'
WHEN age < 10 THEN '0-9'
WHEN age < 20 THEN '10-19'
WHEN age < 30 THEN '20-29'
WHEN age < 40 THEN '30-39'
WHEN age < 50 THEN '40-49'
WHEN age < 60 THEN '50-59'
ELSE '60+'
END AS age_group
FROM customers;

-- Создаю временную таблицу для расчета по годам и кварталам
-- Create an analytical base table for quarterly and yearly analysis
-- joining transaction data with customer age segmentation

DROP TEMPORARY TABLE base;
CREATE TEMPORARY TABLE base AS
SELECT a.id_client, a.age_group,t.id_check, t.sum_payment, QUARTER(t.date_new) AS quarter,
YEAR(t.date_new) AS year
FROM transactions t
LEFT JOIN age_table a
ON t.id_client = a.id_client;
    
-- Вывожу данные в разрезе группировки по возрасту (общее кол-во операции и общая сумма)
-- Aggregate total number of transactions and total revenue by age group

SELECT age_group, COUNT(id_check) AS operations_total, SUM(sum_payment) AS total_sum
FROM base
GROUP BY age_group
ORDER BY age_group;

-- Вывожу данные по году, кварталу и возрастной группе 
-- в разрезе квартала и % от кол-во заказов и % от коли-во транзакции

-- Quarterly analysis by year and age group
-- including transaction volume, revenue, average check,
-- and percentage contribution to yearly totals

SELECT year, quarter, age_group,
COUNT(id_check) AS operations_total,
SUM(sum_payment) AS total_sum,
AVG(sum_payment) AS avg_check,
COUNT(id_check) * 100.0 / SUM(COUNT(id_check)) OVER (PARTITION BY year) AS ops_share_percent,
SUM(sum_payment) * 100.0 / SUM(SUM(sum_payment)) OVER (PARTITION BY year) AS sum_share_percent
FROM base
GROUP BY year, quarter, age_group;