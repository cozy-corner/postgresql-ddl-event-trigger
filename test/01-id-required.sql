-- 第3章: IDリクワイアド（主キーなし）のテスト
-- 期待結果: ERROR: [第3章 IDリクワイアド] テーブル public.test_no_pk に主キーがありません

CREATE TABLE test_no_pk (
    name varchar(100),
    email varchar(100)
);