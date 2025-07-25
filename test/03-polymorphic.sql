-- 第6章: ポリモーフィック関連のテスト
-- 期待結果: WARNING: [第6章 ポリモーフィック関連] テーブル public.test_polymorphic に commentable_type/commentable_id のペアがあります

CREATE TABLE test_polymorphic (
    id serial PRIMARY KEY,
    content text,
    commentable_type varchar(50),
    commentable_id integer
);