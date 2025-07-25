-- =====================================================
-- SQLアンチパターン検出機能の初期設定確認
-- =====================================================

-- アンチパターン検出機能が有効であることを確認
\echo '=== アンチパターン検出機能の確認 ==='

-- 正常なテーブル作成（エラーが出ないことを確認）
\echo '=== 正常なテーブル作成テスト ==='
CREATE TABLE good_users (
    id serial PRIMARY KEY,
    username varchar(50) NOT NULL UNIQUE,
    email varchar(255) NOT NULL,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE good_posts (
    id serial PRIMARY KEY,
    user_id integer REFERENCES good_users(id),
    title varchar(200) NOT NULL,
    content text,
    published_at timestamp
);

\echo '=== セットアップ完了 ==='
\echo '各アンチパターンのテストは test/ ディレクトリ内の個別ファイルを参照してください'