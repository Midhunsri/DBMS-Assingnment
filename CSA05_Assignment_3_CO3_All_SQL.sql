-- CSA05 DBMS Assignment 3 (CO3) - MySQL 8.0
-- Execute in MySQL Workbench. Run sections in order.
CREATE DATABASE IF NOT EXISTS shopnest;
USE shopnest;

-- 1. Original unnormalised-style table (lists are represented as comma-separated text).
DROP TABLE IF EXISTS order_line_flat;
CREATE TABLE order_line_flat (
  OrderID INT NOT NULL,
  OrderDate DATE NOT NULL,
  CustomerID INT NOT NULL,
  CustomerName VARCHAR(100) NOT NULL,
  CustomerEmail VARCHAR(150) NOT NULL,
  ShipStreet VARCHAR(150) NOT NULL,
  ShipCity VARCHAR(80) NOT NULL,
  ShipPIN CHAR(6) NOT NULL,
  ShipState VARCHAR(80) NOT NULL,
  ProductID INT NOT NULL,
  ProductName VARCHAR(120) NOT NULL,
  UnitPrice DECIMAL(10,2) NOT NULL,
  CategoryID INT NOT NULL,
  CategoryName VARCHAR(100) NOT NULL,
  SupplierID INT NOT NULL,
  SupplierName VARCHAR(120) NOT NULL,
  SupplierPhone VARCHAR(20) NOT NULL,
  Quantity INT NOT NULL CHECK (Quantity > 0),
  WarehouseID INT NOT NULL,
  WarehouseCity VARCHAR(80) NOT NULL,
  TagList VARCHAR(500),
  ColourList VARCHAR(300),
  PRIMARY KEY (OrderID, ProductID)
);

INSERT INTO order_line_flat VALUES
(1001,'2026-10-01',1,'Arun','arun@mail.com','12 Lake Rd','Chennai','600001','Tamil Nadu',501,'Keyboard',899.00,10,'Accessories',301,'TechSupply','9000000001',2,701,'Chennai','wireless,computer','Black,White'),
(1001,'2026-10-01',1,'Arun','arun@mail.com','12 Lake Rd','Chennai','600001','Tamil Nadu',502,'Mouse',499.00,10,'Accessories',301,'TechSupply','9000000001',1,701,'Chennai','computer,wireless','Black,Blue'),
(1002,'2026-10-02',2,'Bala','bala@mail.com','8 Park St','Chennai','600002','Tamil Nadu',501,'Keyboard',899.00,10,'Accessories',301,'TechSupply','9000000001',1,702,'Coimbatore','wireless,computer','Black,White'),
(1003,'2026-10-03',3,'Charu','charu@mail.com','4 Hill Rd','Madurai','625001','Tamil Nadu',503,'Bottle',299.00,20,'Lifestyle',302,'HomeKart','9000000002',3,703,'Madurai','reusable,travel','Red,Blue'),
(1004,'2026-10-04',1,'Arun','arun@mail.com','12 Lake Rd','Chennai','600001','Tamil Nadu',503,'Bottle',299.00,20,'Lifestyle',302,'HomeKart','9000000002',1,701,'Chennai','reusable,travel','Red,Blue'),
(1005,'2026-10-05',4,'Divya','divya@mail.com','7 Main Rd','Salem','636001','Tamil Nadu',504,'Lamp',1299.00,30,'Lighting',303,'BrightCo','9000000003',1,704,'Salem','led,home','White,Warm'),
(1006,'2026-10-06',5,'Eshan','eshan@mail.com','9 Cross St','Bengaluru','560001','Karnataka',502,'Mouse',499.00,10,'Accessories',301,'TechSupply','9000000001',2,705,'Bengaluru','computer,wireless','Black,Blue'),
(1007,'2026-10-07',2,'Bala','bala@mail.com','8 Park St','Chennai','600002','Tamil Nadu',504,'Lamp',1299.00,30,'Lighting',303,'BrightCo','9000000003',1,702,'Coimbatore','led,home','White,Warm');

-- 2. Normalised core schema: 3NF/BCNF order and product relations.
DROP TABLE IF EXISTS order_item;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS supplier;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS customer;
DROP TABLE IF EXISTS warehouse;
DROP TABLE IF EXISTS pin_code;
CREATE TABLE customer (
  CustomerID INT PRIMARY KEY,
  CustomerName VARCHAR(100) NOT NULL,
  CustomerEmail VARCHAR(150) NOT NULL UNIQUE
);
CREATE TABLE pin_code (
  ShipPIN CHAR(6) PRIMARY KEY,
  ShipCity VARCHAR(80) NOT NULL,
  ShipState VARCHAR(80) NOT NULL
);
CREATE TABLE supplier (
  SupplierID INT PRIMARY KEY,
  SupplierName VARCHAR(120) NOT NULL,
  SupplierPhone VARCHAR(20) NOT NULL
);
CREATE TABLE category (
  CategoryID INT PRIMARY KEY,
  CategoryName VARCHAR(100) NOT NULL UNIQUE
);
CREATE TABLE warehouse (
  WarehouseID INT PRIMARY KEY,
  WarehouseCity VARCHAR(80) NOT NULL
);
CREATE TABLE product (
  ProductID INT PRIMARY KEY,
  ProductName VARCHAR(120) NOT NULL,
  CurrentPrice DECIMAL(10,2) NOT NULL CHECK (CurrentPrice >= 0),
  CategoryID INT NOT NULL,
  SupplierID INT NOT NULL,
  FOREIGN KEY (CategoryID) REFERENCES category(CategoryID),
  FOREIGN KEY (SupplierID) REFERENCES supplier(SupplierID)
);
CREATE TABLE orders (
  OrderID INT PRIMARY KEY,
  OrderDate DATE NOT NULL,
  CustomerID INT NOT NULL,
  ShipStreet VARCHAR(150) NOT NULL,
  ShipPIN CHAR(6) NOT NULL,
  FOREIGN KEY (CustomerID) REFERENCES customer(CustomerID),
  FOREIGN KEY (ShipPIN) REFERENCES pin_code(ShipPIN)
);
CREATE TABLE order_item (
  OrderID INT NOT NULL,
  ProductID INT NOT NULL,
  Quantity INT NOT NULL CHECK (Quantity > 0),
  WarehouseID INT NOT NULL,
  PRIMARY KEY (OrderID, ProductID),
  FOREIGN KEY (OrderID) REFERENCES orders(OrderID),
  FOREIGN KEY (ProductID) REFERENCES product(ProductID),
  FOREIGN KEY (WarehouseID) REFERENCES warehouse(WarehouseID)
);

INSERT INTO customer VALUES
(1,'Arun','arun@mail.com'),(2,'Bala','bala@mail.com'),(3,'Charu','charu@mail.com'),
(4,'Divya','divya@mail.com'),(5,'Eshan','eshan@mail.com');
INSERT INTO pin_code VALUES
('600001','Chennai','Tamil Nadu'),('600002','Chennai','Tamil Nadu'),
('625001','Madurai','Tamil Nadu'),('636001','Salem','Tamil Nadu'),
('560001','Bengaluru','Karnataka');
INSERT INTO supplier VALUES
(301,'TechSupply','9000000001'),(302,'HomeKart','9000000002'),(303,'BrightCo','9000000003');
INSERT INTO category VALUES (10,'Accessories'),(20,'Lifestyle'),(30,'Lighting');
INSERT INTO warehouse VALUES
(701,'Chennai'),(702,'Coimbatore'),(703,'Madurai'),(704,'Salem'),(705,'Bengaluru');
INSERT INTO product VALUES
(501,'Keyboard',899.00,10,301),(502,'Mouse',499.00,10,301),
(503,'Bottle',299.00,20,302),(504,'Lamp',1299.00,30,303);
INSERT INTO orders VALUES
(1001,'2026-10-01',1,'12 Lake Rd','600001'),
(1002,'2026-10-02',2,'8 Park St','600002'),
(1003,'2026-10-03',3,'4 Hill Rd','625001'),
(1004,'2026-10-04',1,'12 Lake Rd','600001'),
(1005,'2026-10-05',4,'7 Main Rd','636001'),
(1006,'2026-10-06',5,'9 Cross St','560001'),
(1007,'2026-10-07',2,'8 Park St','600002');
INSERT INTO order_item VALUES
(1001,501,2,701),(1001,502,1,701),(1002,501,1,702),(1003,503,3,703),
(1004,503,1,701),(1005,504,1,704),(1006,502,2,705),(1007,504,1,702);

-- 3. Independent multi-valued facts (4NF).
DROP TABLE IF EXISTS product_tag;
DROP TABLE IF EXISTS product_colour;
CREATE TABLE product_tag (
  ProductID INT NOT NULL,
  Tag VARCHAR(50) NOT NULL,
  PRIMARY KEY (ProductID, Tag),
  FOREIGN KEY (ProductID) REFERENCES product(ProductID)
);
CREATE TABLE product_colour (
  ProductID INT NOT NULL,
  Colour VARCHAR(40) NOT NULL,
  PRIMARY KEY (ProductID, Colour),
  FOREIGN KEY (ProductID) REFERENCES product(ProductID)
);
INSERT INTO product_tag VALUES
(501,'wireless'),(501,'computer'),(502,'computer'),(502,'wireless'),
(503,'reusable'),(503,'travel'),(504,'led'),(504,'home');
INSERT INTO product_colour VALUES
(501,'Black'),(501,'White'),(502,'Black'),(502,'Blue'),
(503,'Red'),(503,'Blue'),(504,'White'),(504,'Warm');

-- 4. Price-history extension: preserves the exact transaction price.
DROP TABLE IF EXISTS product_price_history;
CREATE TABLE product_price_history (
  ProductID INT NOT NULL,
  EffectiveFrom DATE NOT NULL,
  EffectiveTo DATE NULL,
  Price DECIMAL(10,2) NOT NULL CHECK (Price >= 0),
  PRIMARY KEY (ProductID, EffectiveFrom),
  FOREIGN KEY (ProductID) REFERENCES product(ProductID),
  CHECK (EffectiveTo IS NULL OR EffectiveTo > EffectiveFrom)
);
INSERT INTO product_price_history VALUES
(501,'2026-09-01',NULL,899.00),(502,'2026-09-01',NULL,499.00),
(503,'2026-09-01',NULL,299.00),(504,'2026-09-01',NULL,1299.00);

-- Modify transaction table to store price actually paid (snapshot).
ALTER TABLE order_item
  ADD COLUMN UnitPricePaid DECIMAL(10,2) NOT NULL DEFAULT 0.00;
UPDATE order_item oi
JOIN product p ON p.ProductID = oi.ProductID
SET oi.UnitPricePaid = p.CurrentPrice;
-- In production, remove DEFAULT after backfill if desired and require explicit value.

-- 5. Common queries.
-- Order history for one customer:
SELECT o.OrderID, o.OrderDate, p.ProductName, oi.Quantity,
       oi.UnitPricePaid, oi.Quantity * oi.UnitPricePaid AS LineTotal
FROM orders o
JOIN order_item oi ON oi.OrderID = o.OrderID
JOIN product p ON p.ProductID = oi.ProductID
WHERE o.CustomerID = 1
ORDER BY o.OrderDate DESC, o.OrderID;

-- Full details for one order:
SELECT o.OrderID, o.OrderDate, c.CustomerName, p.ProductName,
       oi.Quantity, oi.UnitPricePaid, w.WarehouseCity
FROM orders o
JOIN customer c ON c.CustomerID = o.CustomerID
JOIN order_item oi ON oi.OrderID = o.OrderID
JOIN product p ON p.ProductID = oi.ProductID
JOIN warehouse w ON w.WarehouseID = oi.WarehouseID
WHERE o.OrderID = 1001;

-- Update supplier phone once:
UPDATE supplier SET SupplierPhone = '9111111111' WHERE SupplierID = 301;

-- Change current product price:
UPDATE product SET CurrentPrice = 949.00 WHERE ProductID = 501;

-- Insert a new order and item (sample transaction):
INSERT INTO orders VALUES (1008,'2026-11-01',1,'12 Lake Rd','600001');
INSERT INTO order_item (OrderID,ProductID,Quantity,WarehouseID,UnitPricePaid)
VALUES (1008,501,1,701,949.00);

-- Test FK / CHECK / UNIQUE constraints (uncomment individually; expected to fail):
-- INSERT INTO order_item VALUES (9999,501,1,701,949.00); -- missing order FK
-- INSERT INTO order_item VALUES (1001,501,0,701,899.00); -- duplicate PK and quantity CHECK
-- INSERT INTO customer VALUES (6,'Test','arun@mail.com'); -- UNIQUE email
-- UPDATE product SET CurrentPrice=-10 WHERE ProductID=501; -- CHECK

-- Demonstrate anomaly in flat table: repeated customer and supplier facts.
SELECT CustomerID, COUNT(*) AS copies_of_customer_name
FROM order_line_flat GROUP BY CustomerID;
SELECT SupplierID, COUNT(*) AS copies_of_supplier_name
FROM order_line_flat GROUP BY SupplierID;

-- Demonstrate update anomaly in flat table: must update every matching row.
UPDATE order_line_flat SET SupplierPhone='9111111111' WHERE SupplierID=301;

-- MVD combination count for one product:
SELECT ProductID,
       (SELECT COUNT(*) FROM product_tag t WHERE t.ProductID=p.ProductID) *
       (SELECT COUNT(*) FROM product_colour c WHERE c.ProductID=p.ProductID) AS combinations
FROM product p;

-- Verify independent tag and colour sets:
SELECT t.ProductID, t.Tag, c.Colour
FROM product_tag t JOIN product_colour c USING (ProductID)
WHERE t.ProductID=501;

-- 5NF relations for the ternary SUPPLY rule.
DROP TABLE IF EXISTS supplier_warehouse;
DROP TABLE IF EXISTS category_warehouse;
DROP TABLE IF EXISTS supplier_category;
CREATE TABLE supplier_category (
  SupplierID INT NOT NULL,
  CategoryID INT NOT NULL,
  PRIMARY KEY (SupplierID, CategoryID)
);
CREATE TABLE category_warehouse (
  CategoryID INT NOT NULL,
  WarehouseID INT NOT NULL,
  PRIMARY KEY (CategoryID, WarehouseID)
);
CREATE TABLE supplier_warehouse (
  SupplierID INT NOT NULL,
  WarehouseID INT NOT NULL,
  PRIMARY KEY (SupplierID, WarehouseID)
);
INSERT INTO supplier_category VALUES (301,10),(301,20),(302,20);
INSERT INTO category_warehouse VALUES (10,701),(10,702),(20,702),(20,703);
INSERT INTO supplier_warehouse VALUES (301,701),(301,702),(301,703),(302,702),(302,703);

-- Reconstruct ternary SUPPLY tuples using the natural join.
SELECT sc.SupplierID, sc.CategoryID, cw.WarehouseID
FROM supplier_category sc
JOIN category_warehouse cw ON cw.CategoryID=sc.CategoryID
JOIN supplier_warehouse sw
  ON sw.SupplierID=sc.SupplierID AND sw.WarehouseID=cw.WarehouseID
ORDER BY sc.SupplierID, sc.CategoryID, cw.WarehouseID;

-- Benchmark: run the same query repeatedly and record elapsed time in Workbench.
EXPLAIN ANALYZE
SELECT o.OrderID, o.OrderDate, p.ProductName, oi.Quantity, oi.UnitPricePaid
FROM orders o
JOIN order_item oi ON oi.OrderID=o.OrderID
JOIN product p ON p.ProductID=oi.ProductID
WHERE o.CustomerID=1
ORDER BY o.OrderDate DESC;

-- Suggested indexes for high-volume order-history reads.
CREATE INDEX idx_orders_customer_date ON orders(CustomerID, OrderDate, OrderID);
CREATE INDEX idx_order_item_product ON order_item(ProductID);
CREATE INDEX idx_order_item_warehouse ON order_item(WarehouseID);

-- Storage measurements (approximate table data/index size in bytes).
SELECT table_name, table_rows,
       (data_length + index_length) AS total_bytes
FROM information_schema.tables
WHERE table_schema = DATABASE()
ORDER BY table_name;

-- Row counts by relation:
SELECT 'orders' AS relation_name, COUNT(*) AS row_count FROM orders
UNION ALL SELECT 'order_item', COUNT(*) FROM order_item
UNION ALL SELECT 'product', COUNT(*) FROM product
UNION ALL SELECT 'customer', COUNT(*) FROM customer
UNION ALL SELECT 'supplier', COUNT(*) FROM supplier
UNION ALL SELECT 'product_tag', COUNT(*) FROM product_tag
UNION ALL SELECT 'product_colour', COUNT(*) FROM product_colour;
