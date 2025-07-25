-- ALTER TABLEで外部キー候補カラムを追加（第4章: キーレスエントリ）

-- まず正常なテーブルを作成
DROP TABLE IF EXISTS test_alter_orders;
CREATE TABLE test_alter_orders (
    id serial PRIMARY KEY,
    order_date timestamp DEFAULT CURRENT_TIMESTAMP
);

-- 外部キー制約なしで_idカラムを追加
-- 期待結果: ERROR: [第4章 キーレスエントリ] カラム public.test_alter_orders.customer_id は外部キー制約がありません
ALTER TABLE test_alter_orders 
ADD COLUMN customer_id integer;