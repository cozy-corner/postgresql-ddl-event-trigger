-- 第7章: マルチカラムアトリビュートのテスト
-- 期待結果: ERROR: [第7章 マルチカラムアトリビュート] テーブル public.test_multicolumn に番号付きカラムがあります: phone1, phone2, phone3

CREATE TABLE test_multicolumn (
    id serial PRIMARY KEY,
    name varchar(100),
    phone1 varchar(20),
    phone2 varchar(20),
    phone3 varchar(20)
);