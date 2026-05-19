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

# ─── 로그 파일 ───────────────────────────────────────────────────────────────
LOG_FILE="/tmp/claude-setup-$(date +%s).log"
echo "Setup started at $(date)" > "$LOG_FILE"

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

step()  { echo ""; echo -e "${B}${W}▶ $*${N}"; }
ok()    { echo -e "  ${G}✔${N}  $*"; }
info()  { echo -e "  ${D}→  $*${N}"; }
warn()  { echo -e "  ${Y}⚠${N}  $*"; }
debug() { echo -e "  ${D}[DBG] $*${N}"; echo "[DBG] $*" >> "$LOG_FILE"; }
die()   {
  stop_spinner
  echo -e "\n  ${R}✖  $*${N}"
  echo -e "  ${Y}상세 로그: ${LOG_FILE}${N}\n"
  echo "[FAIL] $*" >> "$LOG_FILE"
  exit 1
}

run_log() {
  # 명령을 실행하고 로그 파일에 출력 기록. 실패 시 exit code 반환
  echo "[RUN] $*" >> "$LOG_FILE"
  "$@" >>"$LOG_FILE" 2>&1
}

# ─── 1. 환경 확인 ─────────────────────────────────────────────────────────────
check_env() {
  step "[1/6] 환경 확인"

  debug "OSTYPE=$OSTYPE"
  [[ "$OSTYPE" == darwin* ]] || die "이 설치 도구는 macOS 전용입니다."
  ok "macOS 확인됨"

  ARCH=$(uname -m)
  debug "ARCH=$ARCH"
  [[ "$ARCH" == arm64 ]] \
    && ok "Apple Silicon (M1/M2/M3/M4) 감지됨" \
    || ok "Intel Mac 감지됨"
}

# ─── 2. Homebrew ──────────────────────────────────────────────────────────────
install_homebrew() {
  step "[2/6] Homebrew (패키지 관리자)"

  if command -v brew &>/dev/null; then
    debug "brew 경로: $(command -v brew)"
    ok "Homebrew 설치됨 — 스킵"
    return
  fi

  warn "Homebrew가 없습니다. 설치를 시작합니다."
  info "관리자 암호(Mac 로그인 암호)를 물어볼 수 있습니다."
  echo ""

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty \
    || die "Homebrew 설치 실패. Mac 로그인 암호를 올바르게 입력했는지 확인해주세요."

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
  debug "NVM_DIR=$NVM_DIR"

  # ── NVM 설치 ────────────────────────────────────────────────────────────────
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    debug "nvm.sh 없음 → NVM 설치 시작"
    start_spinner "NVM 설치 중..."
    PROFILE=/dev/null bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh)" \
      >>"$LOG_FILE" 2>&1 \
      || die "NVM 설치 실패"
    stop_spinner
    ok "NVM 설치 완료"
  else
    debug "nvm.sh 존재함 → 스킵"
    ok "NVM 설치됨 — 스킵"
  fi

  debug "nvm.sh 로드 시작: $NVM_DIR/nvm.sh"
  # ── 현재 스크립트 세션에서 NVM 로드 ─────────────────────────────────────────
  # nvm.sh 내부에서 non-zero exit 또는 미선언 변수가 있어 -e/-u 일시 해제
  # curl | bash 실행 시 stdin이 파이프(EOF)이므로 /dev/tty로 명시 연결
  set +euo pipefail
  \. "$NVM_DIR/nvm.sh" < /dev/tty
  set -euo pipefail
  debug "nvm.sh 로드 완료"

  # nvm 명령어 확인
  if ! command -v nvm &>/dev/null && ! type nvm &>/dev/null 2>&1; then
    debug "nvm 함수 로드 실패 — type nvm: $(type nvm 2>&1 || echo 'not found')"
  else
    debug "nvm 로드 확인됨"
  fi

  # ── ~/.zshrc에 NVM 초기화 추가 ───────────────────────────────────────────────
  if ! grep -q 'NVM_DIR' ~/.zshrc 2>/dev/null; then
    debug "~/.zshrc에 NVM_DIR 없음 → 추가"
    cat >> ~/.zshrc <<'ZSHEOF'

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
ZSHEOF
    ok "~/.zshrc에 NVM 초기화 추가됨"
  else
    debug "~/.zshrc에 NVM_DIR 이미 있음"
  fi

  # ── Node.js 22 설치 및 고정 ──────────────────────────────────────────────────
  local current_ver
  current_ver=$(node --version 2>/dev/null || echo "none")
  debug "현재 Node.js 버전: $current_ver"

  if [[ "$current_ver" == v22* ]]; then
    ok "Node.js $current_ver 설치됨 — 스킵"
  else
    debug "Node.js 22 설치 시작 (nvm install 22)"
    start_spinner "Node.js 22 설치 중..."
    set +euo pipefail
    nvm install 22 >>"$LOG_FILE" 2>&1
    local nvm_install_rc=$?
    set -euo pipefail
    stop_spinner
    debug "nvm install 22 exit code: $nvm_install_rc"
    [[ $nvm_install_rc -eq 0 ]] || die "Node.js 22 설치 실패 (exit $nvm_install_rc) — 로그: $LOG_FILE"
    ok "Node.js $(node --version) 설치 완료"
  fi

  debug "nvm alias default 22 실행"
  set +euo pipefail
  nvm alias default 22 >>"$LOG_FILE" 2>&1
  debug "nvm alias exit code: $?"
  nvm use 22 >>"$LOG_FILE" 2>&1
  debug "nvm use 22 exit code: $?"
  set -euo pipefail

  # nvm use 가 PATH를 업데이트하지만, curl | bash 환경에서 누락될 수 있으므로 명시적으로 추가
  local node_ver_raw
  node_ver_raw=$(node --version | tr -d 'v')
  debug "node --version 결과: $node_ver_raw"
  export PATH="$NVM_DIR/versions/node/v${node_ver_raw}/bin:$PATH"
  hash -r 2>/dev/null || true
  debug "PATH에 node bin 추가됨: $NVM_DIR/versions/node/v${node_ver_raw}/bin"
  debug "npm 경로: $(command -v npm 2>/dev/null || echo 'npm not found')"

  # nvm alias default=system 대비: ~/.zshrc에 node bin PATH 직접 명시
  if ! grep -qF 'nvm/versions/node' ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc <<ZSHEOF

# Node.js bin PATH (nvm default alias 무관하게 보장)
export PATH="\$NVM_DIR/versions/node/v${node_ver_raw}/bin:\$PATH"
ZSHEOF
    debug "~/.zshrc에 node bin PATH 직접 추가됨 (v${node_ver_raw})"
  else
    debug "~/.zshrc에 nvm node PATH 이미 있음 — 스킵"
  fi

  ok "Node.js 22 기본 버전으로 고정됨"
}

# ─── 4. Claude Code ───────────────────────────────────────────────────────────
CLAUDE_VERSION="2.1.123"

install_claude() {
  step "[4/6] Claude Code v${CLAUDE_VERSION}"

  # ── NVM npm 절대 경로 확보 (시스템 npm 사용 방지) ──────────────────────────
  local NPM="$NVM_DIR/versions/node/v$(node --version | tr -d 'v')/bin/npm"
  if [[ ! -x "$NPM" ]]; then
    NPM=$(command -v npm)
  fi
  debug "사용할 npm: $NPM"

  # ── ~/.npmrc 정리 (prefix 제거 + 레지스트리 설정) ───────────────────────
  debug "~/.npmrc 정리 시작"
  # prefix 설정이 있으면 제거 (NVM과 충돌 방지)
  sed -i '' '/^prefix/d' "$HOME/.npmrc" 2>/dev/null || true
  # 레지스트리 설정
  grep -qF 'registry=https://nexus.auto-hmg.io' "$HOME/.npmrc" 2>/dev/null \
    || echo "registry=https://nexus.auto-hmg.io/repository/npm-group/" >> "$HOME/.npmrc"
  debug "~/.npmrc 내용: $(cat "$HOME/.npmrc")"
  debug "npm prefix: $("$NPM" prefix -g 2>/dev/null)"

  debug "npm 레지스트리 확인: $("$NPM" config get registry 2>/dev/null || echo 'npm 없음')"

  # ── Nexus 레지스트리 접근 가능 여부 사전 체크 ─────────────────────────────────
  if ! curl -sSf --max-time 10 "https://nexus.auto-hmg.io/repository/npm-group/" >/dev/null 2>&1; then
    die "Nexus 레지스트리(nexus.auto-hmg.io)에 연결할 수 없습니다. VPN 연결 상태를 확인해주세요."
  fi
  debug "Nexus 레지스트리 연결 확인됨"

  if command -v claude &>/dev/null; then
    local installed_ver
    installed_ver=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    debug "claude 경로: $(command -v claude), 버전: $installed_ver"
    if [[ "$installed_ver" == "$CLAUDE_VERSION" ]]; then
      ok "Claude Code v${CLAUDE_VERSION} 설치됨 — 스킵"
    else
      warn "다른 버전 감지됨 (현재: $installed_ver → 대상: $CLAUDE_VERSION)"
      debug "npm install -g @anthropic-ai/claude-code@${CLAUDE_VERSION} 시작"
      start_spinner "Claude Code v${CLAUDE_VERSION} 재설치 중..."
      "$NPM" install -g "@anthropic-ai/claude-code@${CLAUDE_VERSION}" --fetch-timeout=60000 >>"$LOG_FILE" 2>&1
      local npm_rc=$?
      stop_spinner
      debug "npm install exit code: $npm_rc"
      [[ $npm_rc -eq 0 ]] || die "Claude Code 설치 실패 (exit $npm_rc) — 로그: $LOG_FILE"
      ok "Claude Code v${CLAUDE_VERSION} 설치 완료"
    fi
  else
    debug "claude 명령 없음 → 신규 설치"
    debug "npm install -g @anthropic-ai/claude-code@${CLAUDE_VERSION} 시작"
    start_spinner "Claude Code v${CLAUDE_VERSION} 설치 중..."
    "$NPM" install -g "@anthropic-ai/claude-code@${CLAUDE_VERSION}" --fetch-timeout=60000 >>"$LOG_FILE" 2>&1
    local npm_rc=$?
    stop_spinner
    debug "npm install exit code: $npm_rc"
    [[ $npm_rc -eq 0 ]] || die "Claude Code 설치 실패 (exit $npm_rc) — 로그: $LOG_FILE"
    ok "Claude Code v${CLAUDE_VERSION} 설치 완료"
  fi

  # ── claude 바이너리 검증 ──────────────────────────────────────────────
  if ! command -v claude &>/dev/null; then
    debug "claude 바이너리 없음 — npm rebuild 시도"
    "$NPM" install -g "@anthropic-ai/claude-code@${CLAUDE_VERSION}" --force --fetch-timeout=60000 >>"$LOG_FILE" 2>&1
    if ! command -v claude &>/dev/null; then
      # 수동 심링크 생성
      local nvm_bin="$NVM_DIR/versions/node/v$(node --version | tr -d 'v')/bin"
      local cli_js="$NVM_DIR/versions/node/v$(node --version | tr -d 'v')/lib/node_modules/@anthropic-ai/claude-code/cli.js"
      if [[ -f "$cli_js" ]]; then
        ln -sf "$cli_js" "$nvm_bin/claude"
        chmod +x "$nvm_bin/claude"
        debug "수동 심링크 생성: $nvm_bin/claude -> $cli_js"
        ok "claude 심링크 수동 생성 완료"
      else
        die "Claude Code 설치는 성공했으나 실행 파일을 찾을 수 없습니다. 로그: $LOG_FILE"
      fi
    fi
  fi
  debug "claude 경로 확인: $(command -v claude 2>/dev/null)"

  # ── ~/.claude/settings.json 설정 ────────────────────────────────────────────
  mkdir -p "$HOME/.claude"
  debug "~/.claude 디렉토리 확인"

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
  debug "기존 Claude 설정 존재: $has_config"

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

  debug "settings.json 업데이트 시작"
  CLAUDE_TOKEN="$CLAUDE_TOKEN" CLAUDE_ENDPOINT="$CLAUDE_ENDPOINT" python3 - <<'PYEOF'
import json, os
p = os.path.expanduser('~/.claude/settings.json')
config = {}
if os.path.exists(p):
    with open(p) as f:
        try:
            config = json.load(f)
        except json.JSONDecodeError:
            config = {}

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
  debug "settings.json 업데이트 완료"

  ok "Claude Code 인증 및 설정 완료"
}

# ─── 5. mcp-atlassian (uv) ───────────────────────────────────────────────────
install_mcp() {
  step "[5/6] MCP Atlassian 서버 설치"

  if command -v uvx &>/dev/null; then
    debug "uvx 경로: $(command -v uvx)"
    ok "uv 설치됨 — 스킵"
    debug "Python 3.12 설치 여부 확인"
    start_spinner "Python 3.12 확인 중..."
    uv python install 3.12 >>"$LOG_FILE" 2>&1
    stop_spinner
    ok "Python 3.12 준비됨"
    return
  fi

  debug "uvx 없음 → brew install uv 시작"
  start_spinner "uv 설치 중..."
  brew install uv >>"$LOG_FILE" 2>&1
  local brew_rc=$?
  stop_spinner
  debug "brew install uv exit code: $brew_rc"
  [[ $brew_rc -eq 0 ]] || die "uv 설치 실패 (exit $brew_rc) — 로그: $LOG_FILE"

  ok "uv 설치 완료"

  debug "mcp-atlassian 요구 Python 3.12 설치 시작"
  start_spinner "Python 3.12 설치 중 (uv)..."
  uv python install 3.12 >>"$LOG_FILE" 2>&1
  local py_rc=$?
  stop_spinner
  debug "uv python install 3.12 exit code: $py_rc"
  [[ $py_rc -eq 0 ]] || die "Python 3.12 설치 실패 (exit $py_rc) — 로그: $LOG_FILE"

  ok "Python 3.12 설치 완료"
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
  debug "기존 Atlassian 설정 — user: '$existing_user', url: '$existing_url'"

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

  debug "~/.claude.json mcp-atlassian-hmg 설정 업데이트"
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
        try:
            config = json.load(f)
        except json.JSONDecodeError:
            config = {}

config.setdefault('mcpServers', {})['mcp-atlassian-hmg'] = {
    'type': 'stdio',
    'command': 'uvx',
    'args': ['--python', '3.12', 'mcp-atlassian'],
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
  echo -e "  ${Y}⚡ 중요:${N} 새 터미널을 열거나 아래 명령을 실행하세요:"
  echo -e "     ${C}source ~/.zshrc${N}"
  echo ""
  echo -e "  ${W}시작하기:${N}  터미널에서 ${C}claude${N} 를 실행하세요."
  echo -e "  ${W}연동 확인:${N}  Claude Code 실행 후 ${C}/mcp${N} 를 입력하세요."
  echo ""
  echo -e "  ${D}※ 모든 환경설정은 ~/.zshrc에 저장되었습니다.${N}"
  echo -e "  ${D}※ 설치 로그: ${LOG_FILE}${N}"
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
