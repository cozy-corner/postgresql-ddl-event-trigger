-- ALTER TABLEでFLOAT型カラムを追加（第9章: 丸め誤差）

-- まず正常なテーブルを作成
DROP TABLE IF EXISTS test_alter_prices;
CREATE TABLE test_alter_prices (
    id serial PRIMARY KEY,
    product_name varchar(100)
);

-- FLOAT型の価格カラムを追加
-- 期待結果: ERROR: [第9章 丸め誤差] カラム public.test_alter_prices.price でfloat8型が使用されています
ALTER TABLE test_alter_prices 
ADD COLUMN price float;