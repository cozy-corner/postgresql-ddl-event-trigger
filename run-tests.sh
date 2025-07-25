#!/bin/bash

# PostgreSQLアンチパターン検出テストスクリプト

echo "=== PostgreSQLアンチパターン検出テスト ==="
echo ""

# Docker環境の起動
echo "1. Docker環境を起動中..."
docker-compose up -d

# PostgreSQLの起動を待つ
echo "2. PostgreSQLの起動を待機中..."
until docker-compose exec -T postgres pg_isready -U postgres -d antipattern_test > /dev/null 2>&1; do
  echo "   PostgreSQLの起動を待機中..."
  sleep 2
done

echo "3. PostgreSQLが起動しました"
echo ""

# 設定の確認
echo "4. PostgreSQLアンチパターン検出機能が有効であることを確認"
echo ""

# 各テストの実行
echo "5. 各アンチパターンのテストを実行"
echo ""

# テストファイルの配列
tests=(
  "01-id-required.sql:第3章 IDリクワイアド（主キーなし）"
  "02-keyless-entry.sql:第4章 キーレスエントリ（外部キー制約なし）"
  "03-polymorphic.sql:第6章 ポリモーフィック関連"
  "04-multicolumn.sql:第7章 マルチカラムアトリビュート"
  "05-metadata-tribbles.sql:第8章 メタデータトリブル"
  "06-rounding-errors.sql:第9章 丸め誤差"
  "07-alter-table.sql:ALTER TABLE - マルチカラムアトリビュート"
  "08-alter-float.sql:ALTER TABLE - 丸め誤差"
  "09-alter-foreign-key.sql:ALTER TABLE - キーレスエントリ"
)

for test in "${tests[@]}"; do
  IFS=':' read -r filename description <<< "$test"
  echo "=== テスト: $description ==="
  echo "ファイル: test/$filename"
  echo "実行結果:"
  
  # テスト実行（エラーが出ても続行）
  docker-compose exec -T postgres psql -U postgres -d antipattern_test < test/$filename 2>&1 || true
  
  echo ""
done

echo "6. テスト完了"
echo ""
echo "Docker環境を停止するには以下を実行:"
echo "  docker-compose down"
echo ""
echo "データも含めて完全に削除するには:"
echo "  docker-compose down -v"