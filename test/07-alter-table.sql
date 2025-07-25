-- ALTER TABLEでのアンチパターン検出テスト

-- まず正常なテーブルを作成
DROP TABLE IF EXISTS test_alter_base;
CREATE TABLE test_alter_base (
    id serial PRIMARY KEY,
    name varchar(100),
    email varchar(255)
);

-- 番号付きカラムを追加（第7章: マルチカラムアトリビュート）
-- 期待結果: ERROR: [第7章 マルチカラムアトリビュート] テーブル public.test_alter_base に番号付きカラムがあります
ALTER TABLE test_alter_base 
ADD COLUMN phone1 varchar(20),
ADD COLUMN phone2 varchar(20),
ADD COLUMN phone3 varchar(20);