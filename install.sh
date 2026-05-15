#!/usr/bin/env bash
# =============================================================================
#  Claude Code + HMG Atlassian 설치 부트스트랩
#  https://github.com/ignite-corp/claude-mcp-setup
#
#  사용법:
#  curl -sSL https://raw.githubusercontent.com/ignite-corp/claude-mcp-setup/main/install.sh | bash
# =============================================================================

set -euo pipefail

REPO="ignite-corp/claude-mcp-setup"
TMP=$(mktemp /tmp/claude-mcp-setup.XXXXXX.sh)

cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

echo ""
echo "🔍 최신 버전 확인 중..."

API_RESPONSE=$(curl -sf "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null) || {
  echo "❌ GitHub에 연결할 수 없습니다. 인터넷 연결을 확인해주세요."
  exit 1
}

DOWNLOAD_URL=$(echo "$API_RESPONSE" \
  | grep '"browser_download_url"' \
  | grep 'setup\.sh"' \
  | cut -d'"' -f4)

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "❌ 설치 파일을 찾을 수 없습니다. 잠시 후 다시 시도해주세요."
  exit 1
fi

VERSION=$(echo "$API_RESPONSE" | grep '"tag_name"' | cut -d'"' -f4)
echo "📦 버전: $VERSION"
echo "⬇️  다운로드 중..."

curl -sSL "$DOWNLOAD_URL" -o "$TMP"
chmod +x "$TMP"

echo ""
exec "$TMP"
