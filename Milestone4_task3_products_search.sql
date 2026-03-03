-- =====================================================================
-- AetherMart: Product Search Setup (v2 - Fixed Errors)
--
-- This script prepares the Products table for high-speed semantic search.
-- 1. Verifies the embeddings are loaded.
-- 2. Fixes syntax error on DROP.
-- 3. Adds NOT NULL constraint (required for index).
-- 4. Creates a VECTOR INDEX for fast searching.
--
-- Run this script ONCE before you run the Python search.
-- =====================================================================

USE aethermart_db;

-- 1. Verification
-- Let's just double-check that your script worked.
-- This number should be 50 (or however many products you have).
SELECT 
    COUNT(*) as products_with_embeddings
FROM Products
WHERE product_embedding IS NOT NULL;

-- 2. Drop Index (FIX 1: Removed 'VECTOR' from DROP command)
-- The syntax is just 'DROP INDEX', not 'DROP VECTOR INDEX'.
DROP INDEX IF EXISTS idx_product_embedding ON Products;

-- 3. Add NOT NULL Constraint (FIX 2: Required by CREATE INDEX)
-- MariaDB requires the column to be defined as NOT NULL
-- before a vector index can be created on it.
-- This will succeed because your log shows all 50 products are populated.
ALTER TABLE Products MODIFY COLUMN product_embedding VECTOR(768) NOT NULL;

-- 4. Create Vector Index (CRITICAL STEP)
-- This will now succeed because the column is NOT NULL.
CREATE VECTOR INDEX idx_product_embedding
    ON Products (product_embedding);

SELECT '✅ Verification and Vector Index created successfully.' as status;

