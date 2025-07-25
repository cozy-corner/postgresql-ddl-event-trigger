-- =====================================================
-- SQLアンチパターン検出用イベントトリガー
-- 書籍「SQLアンチパターン」の構造的に検出可能なパターンのみ
-- =====================================================

-- メインのイベントトリガー関数
CREATE OR REPLACE FUNCTION detect_sql_antipatterns()
RETURNS event_trigger AS $$
DECLARE
    obj record;
    v_table_oid oid;
    v_schema_name text;
    v_table_name text;
    v_full_table_name text;
BEGIN
    FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands() 
    WHERE command_tag IN ('CREATE TABLE', 'ALTER TABLE')
    LOOP
        -- テーブル情報を取得
        SELECT n.nspname, c.relname, c.oid
        INTO v_schema_name, v_table_name, v_table_oid
        FROM pg_class c
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE c.oid = obj.objid;
        
        v_full_table_name := v_schema_name || '.' || v_table_name;

        -- 各アンチパターンをチェック（章番号順）
        PERFORM check_chapter_3_id_required(v_table_oid, v_full_table_name);
        PERFORM check_chapter_4_keyless_entry(v_table_oid, v_full_table_name);
        PERFORM check_chapter_6_polymorphic_associations(v_table_oid, v_full_table_name);
        PERFORM check_chapter_7_multicolumn_attributes(v_table_oid, v_full_table_name);
        PERFORM check_chapter_8_metadata_tribbles(v_full_table_name, v_table_name);
        PERFORM check_chapter_9_rounding_errors(v_table_oid, v_full_table_name);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 第3章: IDリクワイアド（主キー欠如）
CREATE OR REPLACE FUNCTION check_chapter_3_id_required(p_table_oid oid, p_table_name text)
RETURNS void AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = p_table_oid AND contype = 'p'
    ) THEN
        RAISE EXCEPTION '[第3章 IDリクワイアド] テーブル % に主キーがありません。すべてのテーブルには主キーが必要です。', p_table_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 第4章: キーレスエントリ（外部キー欠如）
CREATE OR REPLACE FUNCTION check_chapter_4_keyless_entry(p_table_oid oid, p_table_name text)
RETURNS void AS $$
DECLARE
    v_fk_candidate record;
    v_has_fk boolean;
BEGIN
    FOR v_fk_candidate IN 
        SELECT a.attname
        FROM pg_attribute a
        WHERE a.attrelid = p_table_oid
        AND a.attnum > 0
        AND NOT a.attisdropped
        AND a.attname ~ '_id$'
        AND a.attname != 'id'
    LOOP
        SELECT EXISTS (
            SELECT 1 
            FROM pg_constraint c
            WHERE c.conrelid = p_table_oid
            AND c.contype = 'f'
            AND v_fk_candidate.attname = ANY(
                SELECT a2.attname 
                FROM pg_attribute a2 
                WHERE a2.attrelid = p_table_oid 
                AND a2.attnum = ANY(c.conkey)
            )
        ) INTO v_has_fk;

        IF NOT v_has_fk THEN
            RAISE EXCEPTION '[第4章 キーレスエントリ] カラム %.% は外部キー制約がありません。参照整合性を保証するため外部キー制約の追加を検討してください。', 
                p_table_name, v_fk_candidate.attname;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 第6章: ポリモーフィック関連
CREATE OR REPLACE FUNCTION check_chapter_6_polymorphic_associations(p_table_oid oid, p_table_name text)
RETURNS void AS $$
DECLARE
    v_polymorphic record;
BEGIN
    FOR v_polymorphic IN
        WITH column_pairs AS (
            SELECT 
                a1.attname as type_col,
                a2.attname as id_col,
                regexp_replace(a1.attname, '_?type$', '') as prefix
            FROM pg_attribute a1
            JOIN pg_attribute a2 ON a1.attrelid = a2.attrelid
            WHERE a1.attrelid = p_table_oid
            AND a1.attnum > 0 AND a2.attnum > 0
            AND NOT a1.attisdropped AND NOT a2.attisdropped
            AND a1.attname ~ '_?type$'
            AND a2.attname ~ '_?id$'
            AND regexp_replace(a1.attname, '_?type$', '') = regexp_replace(a2.attname, '_?id$', '')
        )
        SELECT * FROM column_pairs
    LOOP
        RAISE EXCEPTION '[第6章 ポリモーフィック関連] テーブル % に %/% のペアがあります。ポリモーフィック関連の代わりに、具体的な関連テーブルの使用を検討してください。', 
            p_table_name, v_polymorphic.type_col, v_polymorphic.id_col;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 第7章: マルチカラムアトリビュート
CREATE OR REPLACE FUNCTION check_chapter_7_multicolumn_attributes(p_table_oid oid, p_table_name text)
RETURNS void AS $$
DECLARE
    v_numbered_group record;
BEGIN
    FOR v_numbered_group IN
        WITH numbered_columns AS (
            SELECT 
                attname,
                regexp_replace(attname, '[0-9]+$', '') as base_name,
                (regexp_match(attname, '([0-9]+)$'))[1]::int as num
            FROM pg_attribute
            WHERE attrelid = p_table_oid
            AND attnum > 0
            AND NOT attisdropped
            AND attname ~ '^[a-z_]+[0-9]+$'
        ),
        grouped AS (
            SELECT 
                base_name,
                array_agg(attname ORDER BY num) as columns,
                array_agg(num ORDER BY num) as numbers,
                COUNT(*) as count,
                MIN(num) as min_num,
                MAX(num) as max_num
            FROM numbered_columns
            GROUP BY base_name
            HAVING COUNT(*) >= 2
        )
        SELECT * FROM grouped
        WHERE max_num - min_num + 1 = count
    LOOP
        RAISE EXCEPTION '[第7章 マルチカラムアトリビュート] テーブル % に番号付きカラムがあります: %。これらは別テーブルに正規化すべきです。', 
            p_table_name, array_to_string(v_numbered_group.columns, ', ');
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 第8章: メタデータトリブル
CREATE OR REPLACE FUNCTION check_chapter_8_metadata_tribbles(p_full_table_name text, p_table_name text)
RETURNS void AS $$
BEGIN
    IF p_table_name ~ '_(20[0-9]{2}|19[0-9]{2}|[0-9]{4})(_?[0-9]{2})?(_?[0-9]{2})?(_?Q[1-4])?$' OR
       p_table_name ~ '_[0-9]{6,8}$' THEN
        RAISE EXCEPTION '[第8章 メタデータトリブル] テーブル % は日付でテーブルを分割しています。パーティショニングまたは日付カラムの使用を検討してください。', 
            p_full_table_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 第9章: 丸め誤差（FLOAT使用）
CREATE OR REPLACE FUNCTION check_chapter_9_rounding_errors(p_table_oid oid, p_table_name text)
RETURNS void AS $$
DECLARE
    v_column record;
BEGIN
    FOR v_column IN 
        SELECT a.attname, t.typname
        FROM pg_attribute a
        JOIN pg_type t ON a.atttypid = t.oid
        WHERE a.attrelid = p_table_oid
        AND a.attnum > 0
        AND NOT a.attisdropped
        AND t.typname IN ('float4', 'float8', 'real', 'double precision')
        AND a.attname ~* '(price|cost|amount|money|fee|balance|total|payment|salary|wage|revenue|profit|tax|discount|charge|rate|commission|percentage|percent|ratio|score|grade|gpa|weight|height|quantity|stock|inventory)'
    LOOP
        RAISE EXCEPTION '[第9章 丸め誤差] カラム %.% で%型が使用されています。精度が重要な数値にはNUMERIC/DECIMAL型を使用してください。', 
            p_table_name, v_column.attname, v_column.typname;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- イベントトリガーの作成
DROP EVENT TRIGGER IF EXISTS detect_sql_antipatterns;
CREATE EVENT TRIGGER detect_sql_antipatterns
ON ddl_command_end
WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE')
EXECUTE FUNCTION detect_sql_antipatterns();

-- =====================================================
-- 使用方法
-- =====================================================
/*
-- イベントトリガーの一時無効化
ALTER EVENT TRIGGER detect_sql_antipatterns DISABLE;

-- イベントトリガーの再有効化  
ALTER EVENT TRIGGER detect_sql_antipatterns ENABLE;
*/

-- =====================================================
-- テストケース
-- =====================================================
/*
-- 第3章: IDリクワイアド（主キーなし）
CREATE TABLE test_no_pk (name varchar(100), email varchar(100));

-- 第4章: キーレスエントリ（外部キー制約なし）
CREATE TABLE test_no_fk (id serial PRIMARY KEY, customer_id integer, product_id integer);

-- 第6章: ポリモーフィック関連
CREATE TABLE test_polymorphic (id serial PRIMARY KEY, content text, commentable_type varchar(50), commentable_id integer);

-- 第7章: マルチカラムアトリビュート
CREATE TABLE test_multicolumn (id serial PRIMARY KEY, name varchar(100), phone1 varchar(20), phone2 varchar(20), phone3 varchar(20));

-- 第8章: メタデータトリブル
CREATE TABLE test_tribbles_202401 (id serial PRIMARY KEY, amount decimal(10,2));

-- 第9章: 丸め誤差
CREATE TABLE test_float_price (id serial PRIMARY KEY, name varchar(100), price float);
*/