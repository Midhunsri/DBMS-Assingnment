-- CSA05 CO4 Assignment 4: Bank Transaction Log
-- MySQL 8.x / InnoDB submission script

CREATE DATABASE IF NOT EXISTS bank_txn_db;
USE bank_txn_db;

-- Main transaction table
CREATE TABLE IF NOT EXISTS TXN (
    TxnID       BIGINT NOT NULL,
    AccountNo   VARCHAR(12) NOT NULL,
    TxnTime     DATETIME(3) NOT NULL,
    Type        TINYINT NOT NULL,
    Amount      DECIMAL(15,2) NOT NULL,
    Branch      VARCHAR(20) NOT NULL,
    Channel     VARCHAR(10) NOT NULL,
    Narration   VARCHAR(80),
    Balance     DECIMAL(15,2) NOT NULL,
    OtherData   VARCHAR(45),
    PRIMARY KEY (TxnID),
    INDEX idx_account_time (AccountNo, TxnTime),
    INDEX idx_branch_time (Branch, TxnTime)
) ENGINE=InnoDB;

-- Sample row (run once; change TxnID if it already exists)
INSERT INTO TXN
(TxnID, AccountNo, TxnTime, Type, Amount, Branch, Channel,
 Narration, Balance, OtherData)
VALUES
(100001, 'ACCT00001234', NOW(3), 1, 2500.00, 'CHENNAI01',
 'UPI', 'UPI transfer', 12500.00, 'sample');

-- 1. Exact transaction lookup (dispute desk)
SELECT *
FROM TXN
WHERE TxnID = 100001;

-- 2. Account statement
SELECT TxnID, TxnTime, Type, Amount, Balance
FROM TXN
WHERE AccountNo = 'ACCT00001234'
  AND TxnTime >= '2026-11-01 00:00:00'
  AND TxnTime <  '2026-12-01 00:00:00'
ORDER BY TxnTime;

-- 3. Branch audit
SELECT TxnID, TxnTime, AccountNo, Amount
FROM TXN
WHERE Branch = 'CHENNAI01'
  AND TxnTime >= '2026-11-11 00:00:00'
  AND TxnTime <  '2026-11-12 00:00:00'
ORDER BY TxnTime;

-- 4. TxnID range reconciliation
SELECT *
FROM TXN
WHERE TxnID BETWEEN 500000 AND 501999
ORDER BY TxnID;

-- 5. Query-plan checks
EXPLAIN ANALYZE
SELECT * FROM TXN WHERE TxnID = 100001;

EXPLAIN ANALYZE
SELECT TxnID, TxnTime, Amount
FROM TXN
WHERE AccountNo = 'ACCT00001234'
ORDER BY TxnTime;

-- 6. Index and storage inspection
SHOW INDEX FROM TXN;
ANALYZE TABLE TXN;

SELECT table_name, table_rows, data_length, index_length
FROM information_schema.tables
WHERE table_schema = 'bank_txn_db'
  AND table_name = 'TXN';

-- UPI gateway table: random external ID plus time-based reconciliation index
CREATE TABLE IF NOT EXISTS UPI_TXN (
    GatewayTxnID BIGINT NOT NULL,
    BankTxnID    BIGINT NOT NULL,
    ReceivedAt   DATETIME(3) NOT NULL,
    PRIMARY KEY (GatewayTxnID),
    INDEX idx_received_gateway (ReceivedAt, GatewayTxnID),
    INDEX idx_bank_txn (BankTxnID)
) ENGINE=InnoDB;

-- Hourly UPI reconciliation: use ingestion time, not random ID order
SELECT GatewayTxnID, BankTxnID, ReceivedAt
FROM UPI_TXN
WHERE ReceivedAt >= '2026-11-11 14:00:00'
  AND ReceivedAt <  '2026-11-11 15:00:00'
ORDER BY ReceivedAt, GatewayTxnID;
