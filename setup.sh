#!/usr/bin/env bash
# =============================================================================
#  Claude Code + HMG Atlassian 설치 마법사
#  https://github.com/ignite-corp/claude-mcp-setup
# =============================================================================

set -euo pipefail

# ─── 색상 ────────────────────────────────────────────────────────────────────
R='\033[0;31m'   # Red
G='\033[0;32m'   # Green
Y='\033[1;33m'   # Yellow
B='\033[0;34m'   # Blue
C='\033[0;36m'   # Cyan
W='\033[1m'      # Bold
D='\033[2m'      # Dim
N='\033[0m'      # Reset

# ─── 스피너 ──────────────────────────────────────────────────────────────────
SPINNER_PID=""

start_spinner() {
  local msg="$1"
  (
    local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while true; do
      printf "\r  ${C}%s${N} %s" "${frames:$i:1}" "$msg"
      i=$(( (i+1) % 10 ))
      sleep 0.1
    done
  ) &
  SPINNER_PID=$!
  disown
}

stop_spinner() {
  if [[ -n "${SPINNER_PID:-}" ]]; then
    kill "$SPINNER_PID" 2>/dev/null || true
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
    printf "\r\033[K"
  fi
}

trap 'stop_spinner' EXIT INT TERM

# ─── 출력 함수 ───────────────────────────────────────────────────────────────
banner() {
  clear
  echo ""
  echo -e "${C}${W}"
  echo "  ╔═════════════════════════════════════════════════╗"
  echo "  ║    Claude Code + HMG Atlassian 설치 마법사      ║"
  echo "  ╚═════════════════════════════════════════════════╝"
  echo -e "${N}"
  echo -e "  ${D}이 도구는 Claude Code와 HMG Atlassian(Jira/Confluence)${N}"
  echo -e "  ${D}연동에 필요한 모든 것을 자동으로 설치합니다.${N}"
  echo ""
}

step() { echo ""; echo -e "${B}${W}▶ $*${N}"; }
ok()   { echo -e "  ${G}✔${N}  $*"; }
info() { echo -e "  ${D}→  $*${N}"; }
warn() { echo -e "  ${Y}⚠${N}  $*"; }
die()  { stop_spinner; echo -e "\n  ${R}✖  $*${N}\n"; exit 1; }

# ─── 1. 환경 확인 ─────────────────────────────────────────────────────────────
check_env() {
  step "[1/6] 환경 확인"

  [[ "$OSTYPE" == darwin* ]] || die "이 설치 도구는 macOS 전용입니다."
  ok "macOS 확인됨"

  ARCH=$(uname -m)
  [[ "$ARCH" == arm64 ]] \
    && ok "Apple Silicon (M1/M2/M3/M4) 감지됨" \
    || ok "Intel Mac 감지됨"
}

# ─── 2. Homebrew ──────────────────────────────────────────────────────────────
install_homebrew() {
  step "[2/6] Homebrew (패키지 관리자)"

  if command -v brew &>/dev/null; then
    ok "Homebrew 설치됨 — 스킵"
    return
  fi

  warn "Homebrew가 없습니다. 설치를 시작합니다."
  info "관리자 암호(Mac 로그인 암호)를 물어볼 수 있습니다."
  echo ""

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "Homebrew 설치 실패. 인터넷 연결을 확인해주세요."

  # Apple Silicon PATH 설정
  if [[ "$ARCH" == arm64 ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    grep -qF 'brew shellenv' ~/.zshrc 2>/dev/null \
      || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
  fi

  ok "Homebrew 설치 완료"
}

# ─── 3. NVM + Node.js 22 ─────────────────────────────────────────────────────
install_node() {
  step "[3/6] NVM + Node.js 22"

  export NVM_DIR="$HOME/.nvm"

  # ── NVM 설치 ────────────────────────────────────────────────────────────────
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    start_spinner "NVM 설치 중..."
    # PROFILE=/dev/null: NVM 인스톨러가 .bashrc/.bash_profile 수정하지 않도록 억제
    # zshrc는 아래서 직접 처리
    PROFILE=/dev/null bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh)" \
      &>/dev/null \
      || die "NVM 설치 실패"
    stop_spinner
    ok "NVM 설치 완료"
  else
    ok "NVM 설치됨 — 스킵"
  fi

  # ── 현재 스크립트 세션에서 NVM 로드 ─────────────────────────────────────────
  # set -u 가 NVM 내부 미선언 변수와 충돌하므로 일시적으로 해제
  set +u
  \. "$NVM_DIR/nvm.sh"
  set -u

  # ── ~/.zshrc에 NVM 초기화 추가 ───────────────────────────────────────────────
  if ! grep -q 'NVM_DIR' ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc <<'ZSHEOF'

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
ZSHEOF
    ok "~/.zshrc에 NVM 초기화 추가됨"
  fi

  # ── Node.js 22 설치 및 고정 ──────────────────────────────────────────────────
  local current_ver
  current_ver=$(node --version 2>/dev/null || echo "none")

  if [[ "$current_ver" == v22* ]]; then
    ok "Node.js $current_ver 설치됨 — 스킵"
  else
    start_spinner "Node.js 22 설치 중..."
    nvm install 22 &>/dev/null || die "Node.js 22 설치 실패"
    stop_spinner
    ok "Node.js $(node --version) 설치 완료"
  fi

  # 기본 버전으로 고정
  set +u
  nvm alias default 22 &>/dev/null
  nvm use 22 &>/dev/null
  local node_bin_path="$NVM_DIR/versions/node/$(nvm version)/bin"
  set -u

  # 현재 세션 PATH 즉시 반영
  export PATH="$node_bin_path:$PATH"

  ok "Node.js 22 기본 버전으로 고정됨"
}

# ─── 5. Claude Code ───────────────────────────────────────────────────────────
CLAUDE_VERSION="2.1.123"

install_claude() {
  step "[4/6] Claude Code v${CLAUDE_VERSION}"

  if command -v claude &>/dev/null; then
    local installed_ver
    installed_ver=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    if [[ "$installed_ver" == "$CLAUDE_VERSION" ]]; then
      ok "Claude Code v${CLAUDE_VERSION} 설치됨 — 스킵"
    else
      warn "다른 버전 감지됨 (현재: $installed_ver → 대상: $CLAUDE_VERSION)"
      start_spinner "Claude Code v${CLAUDE_VERSION} 재설치 중..."
      npm install -g "@anthropic-ai/claude-code@${CLAUDE_VERSION}" &>/dev/null \
        || die "Claude Code 설치 실패"
      stop_spinner
      ok "Claude Code v${CLAUDE_VERSION} 설치 완료"
    fi
  else
    start_spinner "Claude Code v${CLAUDE_VERSION} 설치 중..."
    npm install -g "@anthropic-ai/claude-code@${CLAUDE_VERSION}" &>/dev/null \
      || die "Claude Code 설치 실패"
    stop_spinner
    ok "Claude Code v${CLAUDE_VERSION} 설치 완료"
  fi

  # ── ~/.claude/settings.json 설정 ────────────────────────────────────────────
  mkdir -p "$HOME/.claude"

  local has_config
  has_config=$(python3 - <<'PYEOF'
import json, os
p = os.path.expanduser('~/.claude/settings.json')
try:
    d = json.load(open(p))
    env = d.get('env', {})
    has = bool(env.get('ANTHROPIC_AUTH_TOKEN') and env.get('ANTHROPIC_BASE_URL'))
    print('yes' if has else 'no')
except:
    print('no')
PYEOF
)

  if [[ "$has_config" == "yes" ]]; then
    local existing_endpoint
    existing_endpoint=$(python3 - <<'PYEOF'
import json, os
p = os.path.expanduser('~/.claude/settings.json')
try:
    d = json.load(open(p))
    print(d.get('env', {}).get('ANTHROPIC_BASE_URL', ''))
except:
    print('')
PYEOF
)
    info "현재 설정된 Endpoint: $existing_endpoint"
    printf "  다시 설정할까요? [y/N]: "
    read -r ANSWER </dev/tty
    [[ "$ANSWER" =~ ^[Yy]$ ]] || { ok "기존 설정 유지"; return; }
    echo ""
  fi

  echo ""
  echo -e "  ${Y}Claude Code 설정 정보를 입력하세요.${N}"
  info "(담당자에게 발급받으세요)"
  echo ""

  printf "  🌐 API Endpoint URL: "
  read -r CLAUDE_ENDPOINT </dev/tty
  [[ -n "$CLAUDE_ENDPOINT" ]] || die "Endpoint URL이 입력되지 않았습니다."

  printf "  🔑 인증 토큰 (입력 내용이 보이지 않는 것이 정상입니다): "
  read -rs CLAUDE_TOKEN </dev/tty
  echo ""
  [[ -n "$CLAUDE_TOKEN" ]] || die "토큰이 입력되지 않았습니다."

  CLAUDE_TOKEN="$CLAUDE_TOKEN" CLAUDE_ENDPOINT="$CLAUDE_ENDPOINT" python3 - <<'PYEOF'
import json, os
p = os.path.expanduser('~/.claude/settings.json')
config = {}
if os.path.exists(p):
    with open(p) as f:
        config = json.load(f)

config.setdefault('env', {}).update({
    'ANTHROPIC_AUTH_TOKEN': os.environ['CLAUDE_TOKEN'],
    'ANTHROPIC_BASE_URL': os.environ['CLAUDE_ENDPOINT'],
    'DISABLE_AUTOUPDATER': '1',
    'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS': '1'
})
config.setdefault('model', 'sonnet[1m]')
config.setdefault('includeCoAuthoredBy', False)

with open(p, 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
PYEOF

  ok "Claude Code 인증 및 설정 완료"
}

# ─── 5. mcp-atlassian (uv) ───────────────────────────────────────────────────
install_mcp() {
  step "[5/6] MCP Atlassian 서버 설치"

  if command -v uvx &>/dev/null; then
    ok "uv 설치됨 — 스킵"
    return
  fi

  start_spinner "uv 설치 중..."
  brew install uv &>/dev/null \
    || die "uv 설치 실패"
  stop_spinner

  ok "uv 설치 완료"
  info "mcp-atlassian은 실행 시 uvx가 자동으로 다운로드합니다."
}

# ─── 6. Atlassian 연동 설정 ───────────────────────────────────────────────────
configure_hmg() {
  step "[6/6] Atlassian 연동 설정"

  # 기존 설정 확인
  local existing_user existing_url
  existing_user=$(python3 - <<'PYEOF'
import json, os
p = os.path.expanduser('~/.claude.json')
try:
    d = json.load(open(p))
    print(d.get('mcpServers', {}).get('mcp-atlassian-hmg', {}).get('env', {}).get('JIRA_USERNAME', ''))
except:
    print('')
PYEOF
)
  existing_url=$(python3 - <<'PYEOF'
import json, os
p = os.path.expanduser('~/.claude.json')
try:
    d = json.load(open(p))
    print(d.get('mcpServers', {}).get('mcp-atlassian-hmg', {}).get('env', {}).get('JIRA_URL', ''))
except:
    print('')
PYEOF
)

  if [[ -n "$existing_user" ]]; then
    info "현재 설정: $existing_user ($existing_url)"
    printf "  다시 설정할까요? [y/N]: "
    read -r ANSWER </dev/tty
    [[ "$ANSWER" =~ ^[Yy]$ ]] || { ok "기존 설정 유지"; return; }
    echo ""
  fi

  echo -e "  ${Y}Atlassian 연동 정보를 입력하세요.${N}"
  echo ""

  printf "  🌐 Atlassian URL (예: https://company.atlassian.net): "
  read -r JIRA_URL_INPUT </dev/tty
  [[ -n "$JIRA_URL_INPUT" ]] || die "URL이 입력되지 않았습니다."
  # 끝 슬래시 제거
  JIRA_URL_INPUT="${JIRA_URL_INPUT%/}"
  CONFLUENCE_URL_INPUT="${JIRA_URL_INPUT}/wiki"

  printf "  📧 이메일 주소: "
  read -r HMG_EMAIL </dev/tty
  [[ -n "$HMG_EMAIL" ]] || die "이메일 주소가 입력되지 않았습니다."

  echo ""
  echo -e "  ${D}──────────────────────────────────────────────${N}"
  echo -e "  ${W}API 토큰 발급 방법:${N}"
  info "1. ${JIRA_URL_INPUT} 접속 후 로그인"
  info "2. 우측 상단 프로필 클릭 → Manage account"
  info "3. Security 탭 → API tokens → Create API token"
  info "4. 이름 입력 후 생성 → 토큰 복사 (한 번만 표시됨)"
  echo -e "  ${D}──────────────────────────────────────────────${N}"
  echo ""

  printf "  🔑 API 토큰 (입력 내용이 보이지 않는 것이 정상입니다): "
  read -rs HMG_TOKEN </dev/tty
  echo ""
  [[ -n "$HMG_TOKEN" ]] || die "API 토큰이 입력되지 않았습니다."

  HMG_USER="$HMG_EMAIL" \
  HMG_TOKEN="$HMG_TOKEN" \
  HMG_JIRA_URL="$JIRA_URL_INPUT" \
  HMG_CONFLUENCE_URL="$CONFLUENCE_URL_INPUT" \
  python3 - <<'PYEOF'
import json, os

p = os.path.expanduser('~/.claude.json')
config = {}
if os.path.exists(p):
    with open(p) as f:
        config = json.load(f)

config.setdefault('mcpServers', {})['mcp-atlassian-hmg'] = {
    'type': 'stdio',
    'command': 'uvx',
    'args': ['mcp-atlassian'],
    'env': {
        'JIRA_URL': os.environ['HMG_JIRA_URL'],
        'JIRA_USERNAME': os.environ['HMG_USER'],
        'JIRA_API_TOKEN': os.environ['HMG_TOKEN'],
        'CONFLUENCE_URL': os.environ['HMG_CONFLUENCE_URL'],
        'CONFLUENCE_USERNAME': os.environ['HMG_USER'],
        'CONFLUENCE_API_TOKEN': os.environ['HMG_TOKEN']
    }
}

with open(p, 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
PYEOF

  ok "Atlassian 연동 설정 완료"
  info "Jira URL:      $JIRA_URL_INPUT"
  info "Confluence URL: $CONFLUENCE_URL_INPUT"
}

# ─── 완료 ────────────────────────────────────────────────────────────────────
done_msg() {
  echo ""
  echo -e "${G}${W}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
  echo -e "${G}${W}     🎉 모든 설치가 완료되었습니다!${N}"
  echo -e "${G}${W}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
  echo ""
  echo -e "  ${W}시작하기:${N}  터미널에서 ${C}claude${N} 를 실행하세요."
  echo -e "  ${W}연동 확인:${N}  Claude Code 실행 후 ${C}/mcp${N} 를 입력하세요."
  echo ""
  echo -e "  ${D}※ 모든 환경설정은 ~/.zshrc에 저장되었습니다.${N}"
  echo ""
}

# ─── 메인 ────────────────────────────────────────────────────────────────────
main() {
  banner
  check_env
  install_homebrew
  install_node
  install_claude
  install_mcp
  configure_hmg
  done_msg
}

main "$@"
