-- ============================================================
-- CSA05 DBMS CO5 ASSIGNMENT
-- RiverGate Cooperative: Irrigation Water Quota Allocation
-- MySQL 8.0+ | InnoDB
-- Student: MIDHUN SRI D | Register No: 1924260014
--
-- Run this entire file in MySQL Workbench or phpMyAdmin.
-- It creates the database, tables, sample data, a safe transfer
-- procedure, reports, indexes and transaction demonstrations.
-- ============================================================

CREATE DATABASE IF NOT EXISTS RiverGate;
USE RiverGate;

-- ------------------------------------------------------------
-- 1. TABLE CREATION
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS Canal_Pool (
    pool_id VARCHAR(20) PRIMARY KEY,
    balance BIGINT NOT NULL,
    version_no BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_pool_balance CHECK (balance >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Farm (
    farm_id VARCHAR(20) PRIMARY KEY,
    farm_name VARCHAR(100) NOT NULL,
    daily_limit BIGINT NOT NULL,
    CONSTRAINT chk_farm_limit CHECK (daily_limit >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Daily_Usage (
    farm_id VARCHAR(20) NOT NULL,
    usage_day DATE NOT NULL,
    allocated_qty BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (farm_id, usage_day),
    CONSTRAINT chk_allocated_qty CHECK (allocated_qty >= 0),
    CONSTRAINT fk_usage_farm
        FOREIGN KEY (farm_id) REFERENCES Farm(farm_id)
) ENGINE=InnoDB;

-- Each request_key can be processed only once.
CREATE TABLE IF NOT EXISTS Allocation (
    allocation_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    request_key VARCHAR(60) NOT NULL UNIQUE,
    farm_id VARCHAR(20) NOT NULL,
    source_pool VARCHAR(20) NOT NULL,
    destination_pool VARCHAR(20) NOT NULL,
    qty BIGINT NOT NULL,
    allocation_day DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_allocation_qty CHECK (qty > 0),
    CONSTRAINT fk_allocation_farm
        FOREIGN KEY (farm_id) REFERENCES Farm(farm_id),
    CONSTRAINT fk_allocation_source
        FOREIGN KEY (source_pool) REFERENCES Canal_Pool(pool_id),
    CONSTRAINT fk_allocation_destination
        FOREIGN KEY (destination_pool) REFERENCES Canal_Pool(pool_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Transfer_Log (
    transfer_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    request_key VARCHAR(60) NOT NULL UNIQUE,
    source_pool VARCHAR(20) NOT NULL,
    destination_pool VARCHAR(20) NOT NULL,
    qty BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    log_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transfer_qty CHECK (qty > 0)
) ENGINE=InnoDB;

-- Helpful indexes for reports and daily lookups.
CREATE INDEX idx_allocation_farm_day
    ON Allocation(farm_id, allocation_day);
CREATE INDEX idx_allocation_pool_day
    ON Allocation(destination_pool, allocation_day);

-- ------------------------------------------------------------
-- 2. INSERT SAMPLE DATA
-- Re-running the script will not duplicate the sample rows.
-- ------------------------------------------------------------

INSERT INTO Canal_Pool(pool_id, balance, version_no)
VALUES
('CANAL-01', 500, 0),
('CANAL-02', 200, 0),
('CANAL-03', 300, 0)
ON DUPLICATE KEY UPDATE pool_id = VALUES(pool_id);

INSERT INTO Farm(farm_id, farm_name, daily_limit)
VALUES
('FARM-01', 'Green Valley Farm', 100),
('FARM-02', 'River Side Farm', 150)
ON DUPLICATE KEY UPDATE farm_id = VALUES(farm_id);

-- ------------------------------------------------------------
-- 3. VIEW CURRENT TABLE DATA
-- ------------------------------------------------------------

SELECT * FROM Canal_Pool ORDER BY pool_id;
SELECT * FROM Farm ORDER BY farm_id;
SELECT * FROM Daily_Usage ORDER BY farm_id, usage_day;
SELECT * FROM Allocation ORDER BY allocation_id;
SELECT * FROM Transfer_Log ORDER BY transfer_id;

-- ------------------------------------------------------------
-- 4. STORED PROCEDURE: SAFE WATER TOKEN MOVEMENT
--
-- Rules:
--   a) one request_key can be committed only once
--   b) farm daily limit is checked in the same transaction
--   c) source balance is checked before debit
--   d) both pool rows are locked in sorted order
--   e) debit, credit, daily usage and audit rows commit together
--   f) any SQL error rolls back the complete transaction
--
-- Call example:
-- CALL Move_Water_Tokens('REQ-1001','FARM-01',
--                        'CANAL-01','CANAL-02',40);
-- ------------------------------------------------------------

DROP PROCEDURE IF EXISTS Move_Water_Tokens;

DELIMITER $$

CREATE PROCEDURE Move_Water_Tokens(
    IN p_request_key VARCHAR(60),
    IN p_farm_id VARCHAR(20),
    IN p_source_pool VARCHAR(20),
    IN p_destination_pool VARCHAR(20),
    IN p_qty BIGINT
)
main_block: BEGIN
    DECLARE v_daily_limit BIGINT DEFAULT 0;
    DECLARE v_used_qty BIGINT DEFAULT 0;
    DECLARE v_source_balance BIGINT DEFAULT 0;
    DECLARE v_first_pool VARCHAR(20);
    DECLARE v_second_pool VARCHAR(20);
    DECLARE v_existing INT DEFAULT 0;
    DECLARE v_rows INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_qty IS NULL OR p_qty <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Quantity must be greater than zero';
    END IF;

    IF p_source_pool = p_destination_pool THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Source and destination pools must be different';
    END IF;

    IF p_request_key IS NULL OR p_request_key = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Request key is required';
    END IF;

    START TRANSACTION;

    -- Fast duplicate check. The UNIQUE constraint remains the final
    -- protection against two concurrent copies of the same request.
    SELECT COUNT(*)
      INTO v_existing
      FROM Allocation
     WHERE request_key = p_request_key;

    IF v_existing > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Duplicate request: this request key was already processed';
    END IF;

    -- Lock farm row first, then its usage row.
    SELECT daily_limit
      INTO v_daily_limit
      FROM Farm
     WHERE farm_id = p_farm_id
     FOR UPDATE;

    INSERT INTO Daily_Usage(farm_id, usage_day, allocated_qty)
    VALUES (p_farm_id, CURRENT_DATE, 0)
    ON DUPLICATE KEY UPDATE farm_id = p_farm_id;

    SELECT allocated_qty
      INTO v_used_qty
      FROM Daily_Usage
     WHERE farm_id = p_farm_id
       AND usage_day = CURRENT_DATE
     FOR UPDATE;

    IF v_used_qty + p_qty > v_daily_limit THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Daily farm allocation limit exceeded';
    END IF;

    -- Lock the two canal rows in a consistent order to reduce
    -- opposite-direction deadlocks.
    SET v_first_pool = LEAST(p_source_pool, p_destination_pool);
    SET v_second_pool = GREATEST(p_source_pool, p_destination_pool);

    SELECT balance INTO @first_pool_balance
      FROM Canal_Pool
     WHERE pool_id = v_first_pool
     FOR UPDATE;

    SELECT balance INTO @second_pool_balance
      FROM Canal_Pool
     WHERE pool_id = v_second_pool
     FOR UPDATE;

    SELECT balance
      INTO v_source_balance
      FROM Canal_Pool
     WHERE pool_id = p_source_pool;

    IF v_source_balance < p_qty THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient water tokens in source canal';
    END IF;

    -- Update the farm's daily allocation under the held row lock.
    UPDATE Daily_Usage
       SET allocated_qty = allocated_qty + p_qty
     WHERE farm_id = p_farm_id
       AND usage_day = CURRENT_DATE
       AND allocated_qty + p_qty <= v_daily_limit;

    SET v_rows = ROW_COUNT();

    IF v_rows <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Farm daily limit validation failed';
    END IF;

    -- Debit source. Conditional predicate is an additional safeguard.
    UPDATE Canal_Pool
       SET balance = balance - p_qty,
           version_no = version_no + 1
     WHERE pool_id = p_source_pool
       AND balance >= p_qty;

    SET v_rows = ROW_COUNT();

    IF v_rows <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Source debit failed';
    END IF;

    -- Credit destination.
    UPDATE Canal_Pool
       SET balance = balance + p_qty,
           version_no = version_no + 1
     WHERE pool_id = p_destination_pool;

    SET v_rows = ROW_COUNT();

    IF v_rows <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Destination canal does not exist';
    END IF;

    -- Store the request and audit record in the same transaction.
    INSERT INTO Allocation(
        request_key, farm_id, source_pool, destination_pool,
        qty, allocation_day
    )
    VALUES (
        p_request_key, p_farm_id, p_source_pool, p_destination_pool,
        p_qty, CURRENT_DATE
    );

    INSERT INTO Transfer_Log(
        request_key, source_pool, destination_pool, qty, status
    )
    VALUES (
        p_request_key, p_source_pool, p_destination_pool,
        p_qty, 'COMPLETED'
    );

    COMMIT;

    SELECT 'SUCCESS' AS result,
           p_request_key AS request_key,
           p_qty AS transferred_tokens;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- 5. EXECUTE A SAMPLE TRANSFER
-- Expected: CANAL-01 decreases by 40; CANAL-02 increases by 40.
-- FARM-01 daily usage increases by 40.
-- ------------------------------------------------------------

CALL Move_Water_Tokens(
    'REQ-1001',
    'FARM-01',
    'CANAL-01',
    'CANAL-02',
    40
);

-- ------------------------------------------------------------
-- 6. CHECK TRANSFER RESULTS
-- ------------------------------------------------------------

SELECT * FROM Canal_Pool ORDER BY pool_id;
SELECT * FROM Daily_Usage ORDER BY farm_id, usage_day;
SELECT * FROM Allocation ORDER BY allocation_id;
SELECT * FROM Transfer_Log ORDER BY transfer_id;

-- Total water tokens must remain constant (initial total = 1000).
SELECT SUM(balance) AS total_water_tokens
FROM Canal_Pool;

-- ------------------------------------------------------------
-- 7. TEST DAILY FARM LIMIT
-- FARM-01 limit is 100. After a 40-token transfer, only 60
-- more tokens can be allocated today.
-- This call should succeed if run once:
-- ------------------------------------------------------------

-- CALL Move_Water_Tokens(
--     'REQ-1002','FARM-01','CANAL-01','CANAL-03',60
-- );

-- This call should fail if the previous 60-token call succeeded:
-- CALL Move_Water_Tokens(
--     'REQ-1003','FARM-01','CANAL-01','CANAL-03',1
-- );

-- ------------------------------------------------------------
-- 8. TEST INSUFFICIENT SOURCE BALANCE
-- Uncomment to test. The procedure should raise an error and
-- roll back every change.
-- ------------------------------------------------------------

-- CALL Move_Water_Tokens(
--     'REQ-1004','FARM-02','CANAL-01','CANAL-03',999999
-- );

-- ------------------------------------------------------------
-- 9. TEST DUPLICATE REQUEST PROTECTION
-- Repeating REQ-1001 should be rejected. It must not transfer
-- the tokens a second time.
-- ------------------------------------------------------------

-- CALL Move_Water_Tokens(
--     'REQ-1001','FARM-01','CANAL-01','CANAL-02',40
-- );

-- ------------------------------------------------------------
-- 10. REPORT QUERIES
-- ------------------------------------------------------------

-- A. Current canal balances
SELECT pool_id, balance, version_no
FROM Canal_Pool
ORDER BY pool_id;

-- B. Total tokens in the system
SELECT SUM(balance) AS total_tokens
FROM Canal_Pool;

-- C. Total transfers by farm
SELECT farm_id, SUM(qty) AS total_transferred
FROM Allocation
GROUP BY farm_id;

-- D. Total transfers by destination canal
SELECT destination_pool, SUM(qty) AS total_received
FROM Allocation
GROUP BY destination_pool;

-- E. Daily usage compared with farm limit
SELECT
    F.farm_id,
    F.farm_name,
    F.daily_limit,
    COALESCE(D.allocated_qty, 0) AS allocated_today,
    F.daily_limit - COALESCE(D.allocated_qty, 0) AS remaining_limit
FROM Farm AS F
LEFT JOIN Daily_Usage AS D
       ON D.farm_id = F.farm_id
      AND D.usage_day = CURRENT_DATE
ORDER BY F.farm_id;

-- F. Complete transfer history
SELECT
    transfer_id, request_key, source_pool,
    destination_pool, qty, status, log_time
FROM Transfer_Log
ORDER BY transfer_id;

-- G. Allocation history with farm names
SELECT
    A.allocation_id, A.request_key, F.farm_name,
    A.source_pool, A.destination_pool, A.qty,
    A.allocation_day, A.created_at
FROM Allocation AS A
JOIN Farm AS F ON F.farm_id = A.farm_id
ORDER BY A.allocation_id;

-- ------------------------------------------------------------
-- 11. TRANSACTION COMMIT DEMONSTRATION
-- ------------------------------------------------------------

START TRANSACTION;

UPDATE Canal_Pool
   SET balance = balance + 10,
       version_no = version_no + 1
 WHERE pool_id = 'CANAL-03';

COMMIT;

SELECT * FROM Canal_Pool WHERE pool_id = 'CANAL-03';

-- ------------------------------------------------------------
-- 12. TRANSACTION ROLLBACK DEMONSTRATION
-- The balance change below is cancelled.
-- ------------------------------------------------------------

START TRANSACTION;

UPDATE Canal_Pool
   SET balance = balance - 10,
       version_no = version_no + 1
 WHERE pool_id = 'CANAL-03';

ROLLBACK;

SELECT * FROM Canal_Pool WHERE pool_id = 'CANAL-03';

-- ------------------------------------------------------------
-- 13. ISOLATION LEVEL DEMONSTRATION
-- Run this before starting a transaction.
-- ------------------------------------------------------------

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

START TRANSACTION READ ONLY;

SELECT pool_id, balance
FROM Canal_Pool
ORDER BY pool_id;

SELECT SUM(balance) AS consistent_total
FROM Canal_Pool;

COMMIT;

-- ------------------------------------------------------------
-- 14. EXPLAIN QUERY PLAN / INDEX CHECK
-- ------------------------------------------------------------

EXPLAIN
SELECT *
FROM Allocation
WHERE farm_id = 'FARM-01'
  AND allocation_day = CURRENT_DATE;

-- ------------------------------------------------------------
-- 15. DEADLOCK / LOCKING DEMONSTRATION
-- Open TWO MySQL Workbench sessions.
--
-- Session A:
-- START TRANSACTION;
-- SELECT * FROM Canal_Pool
-- WHERE pool_id='CANAL-01' FOR UPDATE;
--
-- Session B:
-- START TRANSACTION;
-- SELECT * FROM Canal_Pool
-- WHERE pool_id='CANAL-02' FOR UPDATE;
--
-- Session A:
-- SELECT * FROM Canal_Pool
-- WHERE pool_id='CANAL-02' FOR UPDATE;
--
-- Session B:
-- SELECT * FROM Canal_Pool
-- WHERE pool_id='CANAL-01' FOR UPDATE;
--
-- One session may be selected as a deadlock victim.
-- Finish the surviving transaction with COMMIT or ROLLBACK.
-- This is a demonstration only; do not run during the sample
-- stored-procedure test.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 16. FINAL VERIFICATION
-- ------------------------------------------------------------

SELECT 'CANAL POOLS' AS section_name;
SELECT * FROM Canal_Pool ORDER BY pool_id;

SELECT 'FARM DAILY USAGE' AS section_name;
SELECT * FROM Daily_Usage ORDER BY farm_id, usage_day;

SELECT 'ALLOCATIONS' AS section_name;
SELECT * FROM Allocation ORDER BY allocation_id;

SELECT 'TRANSFER LOG' AS section_name;
SELECT * FROM Transfer_Log ORDER BY transfer_id;

SELECT
    SUM(balance) AS final_total_tokens,
    CASE
        WHEN SUM(balance) = 1000 THEN 'TOKEN TOTAL CONSERVED'
        ELSE 'CHECK TOKEN TOTAL'
    END AS verification
FROM Canal_Pool;

-- END OF RIVERGATE CO5 MYSQL SCRIPT
