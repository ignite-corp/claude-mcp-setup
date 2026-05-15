#!/usr/bin/env bash
# =============================================================================
#  Claude Code + HMG Atlassian 설치 부트스트랩
#  https://github.com/ignite-corp/claude-mcp-setup
#
#  사용법:
#  curl -sSL https://raw.githubusercontent.com/ignite-corp/claude-mcp-setup/main/install.sh | bash
# =============================================================================

set -euo pipefail

SETUP_URL="https://raw.githubusercontent.com/ignite-corp/claude-mcp-setup/main/setup.sh"
TMP=$(mktemp /tmp/claude-mcp-setup.XXXXXX.sh)

cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

echo ""
echo "⬇️  설치 파일 다운로드 중..."

curl -sSL "$SETUP_URL" -o "$TMP" 2>/dev/null || {
  echo "❌ 다운로드에 실패했습니다. 인터넷 연결 또는 F5 VPN 상태를 확인해주세요."
  exit 1
}

chmod +x "$TMP"

echo ""
exec "$TMP"
