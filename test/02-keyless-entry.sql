-- 第4章: キーレスエントリ（外部キー制約なし）のテスト  
-- 期待結果: WARNING: [第4章 キーレスエントリ] カラム public.test_no_fk.customer_id は外部キー制約がありません

CREATE TABLE test_no_fk (
    id serial PRIMARY KEY,
    customer_id integer,  -- 外部キー制約なし
    product_id integer    -- 外部キー制約なし
);