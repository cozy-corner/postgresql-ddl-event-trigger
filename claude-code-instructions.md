# Claude Code実行指示書 - SQLアンチパターン検出テスト

## 目的
PostgreSQLのイベントトリガーを使用したSQLアンチパターン検出機能をテストする。

## 前提条件
- PostgreSQL 9.3以降（イベントトリガー機能が必要）
- スーパーユーザー権限またはイベントトリガー作成権限

## 実行手順

### 1. テスト用データベースの作成
```bash
# 新しいデータベースを作成（既存DBを汚染しないため）
createdb antipattern_test
```

### 2. SQLアンチパターン検出機能のインストール
```bash
# アーティファクトのSQLを実行
psql -d antipattern_test -f sql-antipatterns-detector.sql
```

### 3. 検出機能の動作確認

#### 3.1 各アンチパターンのテスト

##### テスト1: 第3章 IDリクワイアド（主キーなし）
```sql
-- エラーになるはず
CREATE TABLE test_no_pk (
    name varchar(100),
    email varchar(100)
);
```
期待結果: `ERROR: [第3章 IDリクワイアド] テーブル public.test_no_pk に主キーがありません`

##### テスト2: 第4章 キーレスエントリ（外部キーなし）
```sql
-- エラーになるはず
CREATE TABLE test_no_fk (
    id serial PRIMARY KEY,
    customer_id integer,  -- 外部キー制約なし
    product_id integer    -- 外部キー制約なし
);
```
期待結果: `ERROR: [第4章 キーレスエントリ] カラム public.test_no_fk.customer_id は外部キー制約がありません`

##### テスト3: 第6章 ポリモーフィック関連
```sql
-- エラーになるはず
CREATE TABLE test_polymorphic (
    id serial PRIMARY KEY,
    content text,
    commentable_type varchar(50),
    commentable_id integer
);
```
期待結果: `ERROR: [第6章 ポリモーフィック関連] テーブル public.test_polymorphic に commentable_type/commentable_id のペアがあります`

##### テスト4: 第7章 マルチカラムアトリビュート
```sql
-- エラーになるはず
CREATE TABLE test_multicolumn (
    id serial PRIMARY KEY,
    name varchar(100),
    phone1 varchar(20),
    phone2 varchar(20),
    phone3 varchar(20)
);
```
期待結果: `ERROR: [第7章 マルチカラムアトリビュート] テーブル public.test_multicolumn に番号付きカラムがあります: phone1, phone2, phone3`

##### テスト5: 第8章 メタデータトリブル
```sql
-- エラーになるはず
CREATE TABLE sales_202401 (
    id serial PRIMARY KEY,
    amount decimal(10,2)
);
```
期待結果: `ERROR: [第8章 メタデータトリブル] テーブル public.sales_202401 は日付でテーブルを分割しています`

##### テスト6: 第9章 丸め誤差
```sql
-- エラーになるはず
CREATE TABLE test_prices (
    id serial PRIMARY KEY,
    product_name varchar(100),
    price float,
    discount_rate real
);
```
期待結果: `ERROR: [第9章 丸め誤差] カラム public.test_prices.price でfloat8型が使用されています`

### 4. イベントトリガーの制御

#### 4.1 イベントトリガーの一時無効化
```sql
-- 一時的に全検出を無効化
ALTER EVENT TRIGGER detect_sql_antipatterns DISABLE;

-- アンチパターンを含むテーブルが作成できるはず
CREATE TABLE test_all_bad (
    data text  -- 主キーなし、すべてのアンチパターン
);

-- 再有効化
ALTER EVENT TRIGGER detect_sql_antipatterns ENABLE;
```

### 5. 正常なテーブル作成の確認
```sql
-- アンチパターンを含まないテーブル（エラーなく作成されるはず）
CREATE TABLE good_users (
    id serial PRIMARY KEY,
    username varchar(50) NOT NULL UNIQUE,
    email varchar(255) NOT NULL,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE good_posts (
    id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES good_users(id),
    title varchar(200) NOT NULL,
    content text,
    published_at timestamp
);
```

### 6. クリーンアップ
```bash
# テストが終わったらデータベースを削除
dropdb antipattern_test
```

## トラブルシューティング

### エラー: permission denied to create event trigger
イベントトリガーの作成にはスーパーユーザー権限が必要です：
```bash
psql -U postgres -d antipattern_test -f sql-antipatterns-detector.sql
```

### エラー: function pg_event_trigger_ddl_commands() does not exist
PostgreSQL 9.3以降が必要です。バージョンを確認：
```sql
SELECT version();
```

## 注意事項
- 本番環境での使用前に、十分なテストを実施してください
- アンチパターンが検出されるとテーブル作成がエラーで中断されます
- 既存のテーブルはチェックされません（CREATE TABLE時のみ動作）