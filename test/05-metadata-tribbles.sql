-- 第8章: メタデータトリブルのテスト
-- 期待結果: ERROR: [第8章 メタデータトリブル] テーブル public.sales_202401 は日付でテーブルを分割しています

CREATE TABLE sales_202401 (
    id serial PRIMARY KEY,
    amount decimal(10,2)
);