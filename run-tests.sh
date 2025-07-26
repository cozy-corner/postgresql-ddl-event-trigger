#!/bin/bash

# PostgreSQLアンチパターン検出テストスクリプト

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}=== PostgreSQLアンチパターン検出テスト ===${NC}"
echo ""

# Docker環境の起動
echo -e "${YELLOW}1.${NC} Docker環境を起動中..."
docker-compose up -d

# PostgreSQLの起動を待つ
echo -e "${YELLOW}2.${NC} PostgreSQLの起動を待機中..."
until docker-compose exec -T postgres pg_isready -U postgres -d antipattern_test > /dev/null 2>&1; do
  echo -e "   ${CYAN}PostgreSQLの起動を待機中...${NC}"
  sleep 2
done

echo -e "${GREEN}3. PostgreSQLが起動しました${NC}"
echo ""

# 設定の確認
echo -e "${YELLOW}4.${NC} PostgreSQLアンチパターン検出機能が有効であることを確認"
echo ""

# 各テストの実行
echo -e "${YELLOW}5.${NC} 各アンチパターンのテストを実行"
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
  echo -e "\n${BOLD}${CYAN}=== テスト: $description ===${NC}"
  echo -e "ファイル: test/$filename"
  echo -e "実行結果:"
  
  # テスト実行（エラーが出ても続行）
  docker-compose exec -T postgres psql -U postgres -d antipattern_test < test/$filename 2>&1 || true
  
  echo ""
done

echo -e "\n${GREEN}${BOLD}6. テスト完了${NC}"
echo ""
echo -e "${YELLOW}Docker環境を停止するには以下を実行:${NC}"
echo -e "  ${CYAN}docker-compose down${NC}"
echo ""
echo -e "データも含めて完全に削除するには:"
echo -e "  ${CYAN}docker-compose down -v${NC}"