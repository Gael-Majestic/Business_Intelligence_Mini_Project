-- ============================================================
-- DMS580S Mini Project 2026
-- Domain: Online Electronics Retail
-- OLTP System: MySQL
-- ============================================================

CREATE DATABASE IF NOT EXISTS electronics_retail;
USE electronics_retail;

-- ------------------------------------------------------------
-- TABLE: customers
-- ------------------------------------------------------------
CREATE TABLE customers (
    customer_id   INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    city          VARCHAR(50),
    country       VARCHAR(50)
);

-- ------------------------------------------------------------
-- TABLE: products
-- ------------------------------------------------------------
CREATE TABLE products (
    product_id   INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category     VARCHAR(50),
    brand        VARCHAR(50),
    unit_price   DECIMAL(10,2)
);

-- ------------------------------------------------------------
-- TABLE: orders
-- ------------------------------------------------------------
CREATE TABLE orders (
    order_id    INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    product_id  INT NOT NULL,
    quantity    INT          NOT NULL DEFAULT 1,
    amount      DECIMAL(10,2) NOT NULL,
    order_date  DATE          NOT NULL,
    status      VARCHAR(20)   NOT NULL DEFAULT 'Completed',
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (product_id)  REFERENCES products(product_id)
);

-- ============================================================
-- SEED DATA
-- ============================================================

-- --- Customers (15 records) ---
INSERT INTO customers (customer_name, email, city, country) VALUES
('Alice Dlamini',     'alice.dlamini@mail.com',      'Johannesburg',  'South Africa'),
('Bob Sithole',       'bob.sithole@mail.com',         'Cape Town',     'South Africa'),
('Claire Nkosi',      'claire.nkosi@mail.com',        'Durban',        'South Africa'),
('David Molefe',      'david.molefe@mail.com',        'Pretoria',      'South Africa'),
('Emma Kamau',        'emma.kamau@mail.com',          'Cape Town',     'South Africa'),
('Frank Osei',        'frank.osei@mail.com',          'Durban',        'South Africa'),
('Grace Mbeki',       'grace.mbeki@mail.com',         'Pretoria',      'South Africa'),
('Henri van Wyk',     'henri.vanwyk@mail.com',        'Johannesburg',  'South Africa'),
('Isabelle Botha',    'isabelle.botha@mail.com',      'Port Elizabeth','South Africa'),
('James Khumalo',     'james.khumalo@mail.com',       'Johannesburg',  'South Africa'),
('Karen Pietersen',   'karen.pietersen@mail.com',     'Cape Town',     'South Africa'),
('Louis Ferreira',    'louis.ferreira@mail.com',      'Bloemfontein',  'South Africa'),
('Marie van der Berg','marie.vanderberg@mail.com',    'Pretoria',      'South Africa'),
('Nathan Sithole',    'nathan.sithole@mail.com',      'Durban',        'South Africa'),
('Olivia Nkosi',      'olivia.nkosi@mail.com',        'Cape Town',     'South Africa');

-- --- Products (12 records) ---
INSERT INTO products (product_name, category, brand, unit_price) VALUES
('MacBook Pro 14"',      'Laptop',      'Apple',    1299.99),
('Dell XPS 15',          'Laptop',      'Dell',     1099.99),
('HP Spectre x360',      'Laptop',      'HP',        899.99),
('iPhone 15 Pro',        'Smartphone',  'Apple',     999.99),
('Samsung Galaxy S24',   'Smartphone',  'Samsung',   799.99),
('Google Pixel 8 Pro',   'Smartphone',  'Google',    699.99),
('AirPods Pro',          'Audio',       'Apple',     249.99),
('Sony WH-1000XM5',      'Audio',       'Sony',      349.99),
('Samsung 4K Monitor',   'Monitor',     'Samsung',   499.99),
('LG UltraWide Monitor', 'Monitor',     'LG',        599.99),
('Logitech MX Master 3', 'Accessory',   'Logitech',   99.99),
('Apple Magic Keyboard', 'Accessory',   'Apple',     129.99);

-- --- Orders (35 records) ---
-- customer_id refs: Alice Dlamini=1  Bob Sithole=2   Claire Nkosi=3  David Molefe=4  Emma Kamau=5
--                   Frank Osei=6     Grace Mbeki=7   Henri van Wyk=8 Isabelle Botha=9 James Khumalo=10
--                   Karen Pietersen=11 Louis Ferreira=12 Marie van der Berg=13 Nathan Sithole=14 Olivia Nkosi=15
-- product_id refs:  MacBook=1 Dell=2 HP=3 iPhone=4 Galaxy=5
--                   Pixel=6 AirPods=7 Sony=8 Samsung4K=9 LG=10
--                   Logitech=11 MagicKB=12
INSERT INTO orders (customer_id, product_id, quantity, amount, order_date, status) VALUES
(1,  4,  1,  999.99,  '2026-01-05', 'Completed'),   -- Alice Dlamini    / iPhone 15 Pro
(2,  5,  1,  799.99,  '2026-01-08', 'Completed'),   -- Bob Sithole      / Samsung Galaxy S24
(3,  1,  1, 1299.99,  '2026-01-10', 'Completed'),   -- Claire Nkosi     / MacBook Pro 14"
(4,  7,  2,  499.98,  '2026-01-12', 'Completed'),   -- David Molefe     / AirPods Pro x2
(5,  2,  1, 1099.99,  '2026-01-15', 'Completed'),   -- Emma Kamau       / Dell XPS 15
(6,  8,  1,  349.99,  '2026-01-18', 'Completed'),   -- Frank Osei       / Sony WH-1000XM5
(7,  9,  1,  499.99,  '2026-01-20', 'Completed'),   -- Grace Mbeki      / Samsung 4K Monitor
(8,  4,  1,  999.99,  '2026-01-22', 'Completed'),   -- Henri van Wyk    / iPhone 15 Pro
(9,  6,  1,  699.99,  '2026-01-25', 'Completed'),   -- Isabelle Botha   / Google Pixel 8 Pro
(10, 11, 2,  199.98,  '2026-01-28', 'Completed'),   -- James Khumalo    / Logitech MX Master 3 x2
(11, 10, 1,  599.99,  '2026-02-01', 'Completed'),   -- Karen Pietersen  / LG UltraWide Monitor
(12, 3,  1,  899.99,  '2026-02-03', 'Completed'),   -- Louis Ferreira   / HP Spectre x360
(13, 12, 3,  389.97,  '2026-02-05', 'Completed'),   -- Marie van der Berg / Apple Magic Keyboard x3
(14, 5,  1,  799.99,  '2026-02-08', 'Completed'),   -- Nathan Sithole   / Samsung Galaxy S24
(15, 1,  1, 1299.99,  '2026-02-10', 'Completed'),   -- Olivia Nkosi     / MacBook Pro 14"
(1,  7,  1,  249.99,  '2026-02-12', 'Completed'),   -- Alice Dlamini    / AirPods Pro
(2,  2,  1, 1099.99,  '2026-02-15', 'Completed'),   -- Bob Sithole      / Dell XPS 15
(3,  6,  1,  699.99,  '2026-02-18', 'Completed'),   -- Claire Nkosi     / Google Pixel 8 Pro
(4,  9,  2,  999.98,  '2026-02-20', 'Completed'),   -- David Molefe     / Samsung 4K Monitor x2
(5,  8,  1,  349.99,  '2026-02-22', 'Completed'),   -- Emma Kamau       / Sony WH-1000XM5
(6,  4,  1,  999.99,  '2026-03-01', 'Completed'),   -- Frank Osei       / iPhone 15 Pro
(7,  11, 1,   99.99,  '2026-03-03', 'Completed'),   -- Grace Mbeki      / Logitech MX Master 3
(8,  1,  1, 1299.99,  '2026-03-05', 'Completed'),   -- Henri van Wyk    / MacBook Pro 14"
(9,  12, 2,  259.98,  '2026-03-08', 'Completed'),   -- Isabelle Botha   / Apple Magic Keyboard x2
(10, 3,  1,  899.99,  '2026-03-10', 'Completed'),   -- James Khumalo    / HP Spectre x360
(11, 7,  1,  249.99,  '2026-03-12', 'Completed'),   -- Karen Pietersen  / AirPods Pro
(12, 4,  1,  999.99,  '2026-03-15', 'Completed'),   -- Louis Ferreira   / iPhone 15 Pro
(13, 5,  1,  799.99,  '2026-03-18', 'Completed'),   -- Marie van der Berg / Samsung Galaxy S24
(14, 10, 1,  599.99,  '2026-03-20', 'Completed'),   -- Nathan Sithole   / LG UltraWide Monitor
(15, 2,  1, 1099.99,  '2026-03-22', 'Completed'),   -- Olivia Nkosi     / Dell XPS 15
(1,  1,  1, 1299.99,  '2026-04-01', 'Completed'),   -- Alice Dlamini    / MacBook Pro 14"
(2,  8,  1,  349.99,  '2026-04-03', 'Completed'),   -- Bob Sithole      / Sony WH-1000XM5
(3,  9,  1,  499.99,  '2026-04-05', 'Completed'),   -- Claire Nkosi     / Samsung 4K Monitor
(4,  6,  1,  699.99,  '2026-04-08', 'Completed'),   -- David Molefe     / Google Pixel 8 Pro
(5,  12, 2,  259.98,  '2026-04-10', 'Completed');   -- Emma Kamau       / Apple Magic Keyboard x2

-- ============================================================
-- Verification
-- ============================================================
SELECT COUNT(*) AS total_orders FROM orders;

-- Denormalized view used by ETL to export orders_raw.csv
CREATE OR REPLACE VIEW v_orders_export AS
SELECT
    o.order_id,
    c.customer_name,
    p.product_name   AS product,
    p.category,
    p.brand,
    o.quantity,
    o.amount,
    o.order_date,
    o.status,
    c.city,
    c.country
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN products  p ON o.product_id  = p.product_id;
