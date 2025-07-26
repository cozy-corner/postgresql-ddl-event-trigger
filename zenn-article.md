# PostgreSQLのイベントトリガーでSQLアンチパターンを自動検出する仕組み

## はじめに

データベース設計においてアンチパターンを避けることは重要だが、規約に書いても読んでもらえなかったり、新しいメンバーが知らずに使ってしまうことがある。

そこで、PostgreSQLのイベントトリガー機能を使って、テーブル作成・変更時に自動的にSQLアンチパターンを検出する仕組みを作った。

書籍「SQLアンチパターン」で紹介されているパターンのうち、構造的に検出可能な6つを実装した。

```sql
-- アンチパターンの例：主キーがない
CREATE TABLE users (
    name varchar(100),
    email varchar(100)
);
-- ERROR: [第3章 IDリクワイアド] テーブル public.users に主キーがない
```

## PostgreSQLイベントトリガーとは

イベントトリガーは、DDL（Data Definition Language）コマンドの実行時に自動的に呼び出される特殊なトリガー。

通常のトリガーとの違い：
- **通常のトリガー**: INSERT/UPDATE/DELETEなどのDML操作で発火
- **イベントトリガー**: CREATE/ALTER/DROPなどのDDL操作で発火

### 基本的な仕組み

イベントトリガーは、トリガー関数とトリガー定義の2つの要素で構成される。トリガー関数でDDL操作の情報を取得し、トリガー定義で監視するDDLコマンドを指定する。

```sql
-- イベントトリガー関数の定義
CREATE OR REPLACE FUNCTION my_event_trigger_function()
RETURNS event_trigger AS $$
BEGIN
    -- DDLコマンドの情報を取得
    FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands()
    LOOP
        -- 処理を記述
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- イベントトリガーの作成
CREATE EVENT TRIGGER my_event_trigger
ON ddl_command_end  -- DDLコマンド実行後に発火
WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE')
EXECUTE FUNCTION my_event_trigger_function();
```

`pg_event_trigger_ddl_commands()`関数は、実行されたDDLコマンドの詳細情報を返す。これにより、作成・変更されたオブジェクトのOIDや種類を取得できる。

## 検出する6つのSQLアンチパターン

### 1. 第3章: IDリクワイアド（主キーなし）

**問題**: 主キーがないテーブルは、行の一意性が保証されず、パフォーマンスも悪化する。

**エラーになる例**:
```sql
CREATE TABLE users (
    name varchar(100),
    email varchar(100)
);
-- ERROR: [第3章 IDリクワイアド] テーブル public.users に主キーがない
```

**検出ロジック**:
```sql
IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = p_table_oid AND contype = 'p'
) THEN
    RAISE EXCEPTION '[第3章 IDリクワイアド] テーブル % に主キーがない';
END IF;
```

### 2. 第4章: キーレスエントリ（外部キー制約なし）

**問題**: `_id`で終わるカラムは通常、他のテーブルへの参照を示すが、外部キー制約がないと参照整合性が保証されない。

**エラーになる例**:
```sql
CREATE TABLE posts (
    id serial PRIMARY KEY,
    user_id integer,
    title varchar(200)
);
-- ERROR: [第4章 キーレスエントリ] カラム public.posts.user_id は外部キー制約がない
```

**検出ロジック**:
```sql
-- _idで終わるカラムを探す
FOR v_fk_candidate IN 
    SELECT attname FROM pg_attribute
    WHERE attrelid = p_table_oid
    AND attname ~ '_id$'
    AND attname != 'id'
LOOP
    -- 外部キー制約があるかチェック
    IF NOT EXISTS (外部キー制約の確認) THEN
        RAISE EXCEPTION '[第4章 キーレスエントリ] カラム % は外部キー制約がない';
    END IF;
END LOOP;
```

### 3. 第6章: ポリモーフィック関連

**問題**: `commentable_type`と`commentable_id`のようなペアで、複数のテーブルを参照する設計は、参照整合性を保証できない。

**エラーになる例**:
```sql
CREATE TABLE comments (
    id serial PRIMARY KEY,
    content text,
    commentable_type varchar(50),
    commentable_id integer
);
-- ERROR: [第6章 ポリモーフィック関連] テーブル public.comments に commentable_type/commentable_id のペアがあります
```

**検出ロジック**:
```sql
-- *_typeと*_idのペアを検出
WITH column_pairs AS (
    SELECT 
        a1.attname as type_col,
        a2.attname as id_col
    FROM pg_attribute a1
    JOIN pg_attribute a2 ON a1.attrelid = a2.attrelid
    WHERE a1.attname ~ '_?type$'
    AND a2.attname ~ '_?id$'
    AND regexp_replace(a1.attname, '_?type$', '') = 
        regexp_replace(a2.attname, '_?id$', '')
)
SELECT * FROM column_pairs;
```

### 4. 第7章: マルチカラムアトリビュート

**問題**: `phone1`, `phone2`, `phone3`のような番号付きカラムは、正規化されていない。

**エラーになる例**:
```sql
CREATE TABLE contacts (
    id serial PRIMARY KEY,
    name varchar(100),
    phone1 varchar(20),
    phone2 varchar(20),
    phone3 varchar(20)
);
-- ERROR: [第7章 マルチカラムアトリビュート] テーブル public.contacts に番号付きカラムがあります: phone1, phone2, phone3
```

**検出ロジック**:
```sql
-- 番号付きカラムをグループ化
WITH numbered_columns AS (
    SELECT 
        attname,
        regexp_replace(attname, '[0-9]+$', '') as base_name,
        (regexp_match(attname, '([0-9]+)$'))[1]::int as num
    FROM pg_attribute
    WHERE attname ~ '^[a-z_]+[0-9]+$'
)
-- 連続した番号のグループを検出
SELECT base_name, array_agg(attname)
FROM numbered_columns
GROUP BY base_name
HAVING COUNT(*) >= 2;
```

### 5. 第8章: メタデータトリブル

**問題**: `sales_202401`のような日付でテーブルを分割すると、クエリが複雑になる。

**エラーになる例**:
```sql
CREATE TABLE sales_202401 (
    id serial PRIMARY KEY,
    product_id integer,
    amount decimal(10,2)
);
-- ERROR: [第8章 メタデータトリブル] テーブル public.sales_202401 は日付で分割されている
```

**検出ロジック**:
```sql
IF p_table_name ~ '_(20[0-9]{2}|19[0-9]{2}|[0-9]{4})(_?[0-9]{2})?(_?[0-9]{2})?$' 
THEN
    RAISE EXCEPTION '[第8章 メタデータトリブル] テーブル % は日付で分割されている';
END IF;
```

### 6. 第9章: 丸め誤差

**問題**: 金額や数量にFLOAT型を使用すると、計算誤差が発生する。

**エラーになる例**:
```sql
CREATE TABLE products (
    id serial PRIMARY KEY,
    name varchar(100),
    price float
);
-- ERROR: [第9章 丸め誤差] カラム public.products.price でfloat8型が使用されている
```

**検出ロジック**:
```sql
-- FLOAT型で金額関連の名前を持つカラムを検出
FOR v_column IN 
    SELECT a.attname, t.typname
    FROM pg_attribute a
    JOIN pg_type t ON a.atttypid = t.oid
    WHERE t.typname IN ('float4', 'float8', 'real', 'double precision')
    AND a.attname ~* '(price|cost|amount|money|balance|total|salary)'
LOOP
    RAISE EXCEPTION '[第9章 丸め誤差] カラム % で%型が使用されている';
END LOOP;
```

## 実装のポイント

### イベントトリガー関数の基本構造

実際のアンチパターン検出では、DDLコマンドから対象テーブルの情報を取得し、各検出関数を呼び出す構造になっている。

```sql
CREATE OR REPLACE FUNCTION detect_sql_antipatterns()
RETURNS event_trigger AS $$
DECLARE
    obj record;
    v_table_oid oid;
    v_schema_name text;
    v_table_name text;
BEGIN
    -- DDLコマンドの情報を取得
    FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands() 
    WHERE command_tag IN ('CREATE TABLE', 'ALTER TABLE')
    LOOP
        -- テーブル情報を取得
        SELECT n.nspname, c.relname, c.oid
        INTO v_schema_name, v_table_name, v_table_oid
        FROM pg_class c
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE c.oid = obj.objid;
        
        -- 各アンチパターンをチェック
        PERFORM check_chapter_3_id_required(v_table_oid, v_table_name);
        PERFORM check_chapter_4_keyless_entry(v_table_oid, v_table_name);
        -- ... 他のチェック関数
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```

### システムカタログの活用

PostgreSQLのシステムカタログを活用して、テーブル構造を分析する：

- `pg_class`: テーブル情報
- `pg_attribute`: カラム情報
- `pg_constraint`: 制約情報
- `pg_type`: データ型情報
- `pg_index`: インデックス情報

### ALTER TABLEへの対応

CREATE TABLEだけでなく、ALTER TABLEも監視することで、後から追加されるカラムのアンチパターンも検出できる。

```sql
CREATE EVENT TRIGGER detect_sql_antipatterns
ON ddl_command_end
WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE')  -- 両方を監視
EXECUTE FUNCTION detect_sql_antipatterns();
```

## 実装を見送った機能

### 外部キーへのインデックス強制

外部キーカラムにインデックスがないとJOINのパフォーマンスが悪化するため、検出機能の実装を試みたが断念した。PostgreSQLではインデックスは別途CREATE INDEX文で作成する必要があり、イベントトリガーの発火時点ではまだインデックスが存在しないため、適切な検出が困難だった。

## まとめ

PostgreSQLのイベントトリガーを活用することで、SQLアンチパターンの自動検出が実現できた。

検出の仕組みを実装する過程で、各アンチパターンがなぜ問題なのか、どのようなパターンで現れるのかを深く理解できた。

この仕組みにより：
- コードレビューの負担軽減
- アンチパターンの学習機会の提供
- データベース品質の向上

が期待できる。

実際のところ、私の業務経験で遭遇したアンチパターンは今回実装した6つのうちメタデータトリブル（日付でテーブルを分割）だけであり、この仕組みが現場で直接的に役立つ機会は限定的かもしれない。

コード：https://github.com/cozy-corner/postgresql-ddl-event-trigger

## 参考文献

- [SQLアンチパターン](https://www.oreilly.co.jp/books/9784873115894/) - Bill Karwin著（第1版）
- [PostgreSQL公式ドキュメント - イベントトリガー](https://www.postgresql.org/docs/current/event-triggers.html)
