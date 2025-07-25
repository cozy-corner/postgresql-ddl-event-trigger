-- 第9章: 丸め誤差のテスト
-- 期待結果: WARNING: [第9章 丸め誤差] カラム public.test_prices.price でfloat8型が使用されています

CREATE TABLE test_prices (
    id serial PRIMARY KEY,
    product_name varchar(100),
    price float,
    discount_rate real
);