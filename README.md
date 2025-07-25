# PostgreSQL SQLアンチパターン検出機能

PostgreSQLのイベントトリガーを使用して、テーブルの作成・変更時にSQLアンチパターンを自動検出するツールです。

## 概要

書籍「SQLアンチパターン」で紹介されているアンチパターンのうち、構造的に検出可能な6つのパターンをCREATE TABLEおよびALTER TABLE実行時に自動的に検出します。

### 検出可能なアンチパターン

1. **第3章: IDリクワイアド** - 主キーが定義されていないテーブル
2. **第4章: キーレスエントリ** - `_id`で終わるカラムに外部キー制約がない
3. **第6章: ポリモーフィック関連** - `*_type`と`*_id`のペアによる多態的な関連
4. **第7章: マルチカラムアトリビュート** - `phone1`, `phone2`のような番号付きカラム
5. **第8章: メタデータトリブル** - 日付でテーブル名を分割（例：`sales_202401`）
6. **第9章: 丸め誤差** - 金額や数量にFLOAT型を使用

## 必要要件

- Docker および Docker Compose
- PostgreSQL 9.3以降（イベントトリガー機能が必要）

## クイックスタート

```bash
# リポジトリのクローン
git clone <repository-url>
cd postgresql-ddl-event-trigger

# Docker環境でテストを実行
./run-tests.sh
```

## ファイル構成

```
.
├── README.md                           # このファイル
├── claude-code-instructions.md         # 詳細な使用方法
├── docker-compose.yml                  # Docker環境定義
├── run-tests.sh                       # テスト実行スクリプト
├── setup.sql                          # 初期セットアップSQL
├── sql-antipatterns-detector.sql      # アンチパターン検出機能本体
└── test/                              # 各アンチパターンのテストSQL
    ├── 01-id-required.sql
    ├── 02-keyless-entry.sql
    ├── 03-polymorphic.sql
    ├── 04-multicolumn.sql
    ├── 05-metadata-tribbles.sql
    ├── 06-rounding-errors.sql
    ├── 07-alter-table.sql             # ALTER TABLEテスト
    ├── 08-alter-float.sql
    └── 09-alter-foreign-key.sql
```

## 使用方法

### 本番環境での導入

1. `sql-antipatterns-detector.sql`をデータベースに適用：
```bash
psql -U postgres -d your_database -f sql-antipatterns-detector.sql
```

2. 以降、CREATE TABLEやALTER TABLEを実行すると自動的にアンチパターンが検出されます

### 一時的に無効化

```sql
-- 無効化
ALTER EVENT TRIGGER detect_sql_antipatterns DISABLE;

-- 再有効化
ALTER EVENT TRIGGER detect_sql_antipatterns ENABLE;
```

## 動作例

### アンチパターンが検出される例

```sql
-- 主キーなし（第3章）
CREATE TABLE users (
    name varchar(100),
    email varchar(100)
);
-- ERROR: [第3章 IDリクワイアド] テーブル public.users に主キーがありません

-- 番号付きカラム（第7章）
CREATE TABLE contacts (
    id serial PRIMARY KEY,
    phone1 varchar(20),
    phone2 varchar(20),
    phone3 varchar(20)
);
-- ERROR: [第7章 マルチカラムアトリビュート] テーブル public.contacts に番号付きカラムがあります

```

### 正常に作成される例

```sql
CREATE TABLE users (
    id serial PRIMARY KEY,
    username varchar(50) NOT NULL UNIQUE,
    email varchar(255) NOT NULL,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP
);
-- 成功

-- 正常なALTER TABLE
ALTER TABLE users ADD COLUMN last_login timestamp;
-- 成功
```

## 注意事項

- アンチパターンが検出されるとテーブルの作成・変更がエラーで中断されます
- 既存のテーブルはチェックされません（CREATE TABLE・ALTER TABLE時のみ動作）
- 本番環境での使用前に十分なテストを実施してください
- イベントトリガーの作成にはスーパーユーザー権限が必要です

## Docker環境の管理

```bash
# 環境の停止
docker-compose down

# データも含めて完全に削除
docker-compose down -v
```

## トラブルシューティング

### permission denied to create event trigger
スーパーユーザー権限でSQLを実行してください：
```bash
psql -U postgres -d your_database -f sql-antipatterns-detector.sql
```

### function pg_event_trigger_ddl_commands() does not exist
PostgreSQL 9.3以降が必要です。バージョンを確認してください：
```sql
SELECT version();
```

## ライセンス

[ライセンスを記載]

## 貢献

[貢献方法を記載]