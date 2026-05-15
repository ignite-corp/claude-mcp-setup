# Claude Code + HMG Atlassian 설치 마법사

HMG Atlassian(Jira, Confluence)을 Claude Code와 연동하는 인터랙티브 설치 도구입니다.

## 사전 준비 — 토큰 발급

설치 스크립트 실행 전에 아래 두 가지 토큰을 미리 발급받아 두세요.

### 1. Claude Code 인증 토큰

👉 **[https://h-chat-platform.autoever.com/personal-key-lists](https://h-chat-platform.autoever.com/personal-key-lists)**

1. 위 링크 접속 후 로그인
2. 개인 API 키 발급
3. 발급된 토큰 복사

### 2. Atlassian API 토큰

👉 **[https://id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens)**

1. 위 링크 접속 후 Atlassian 계정으로 로그인
2. **Create API token** 클릭
3. 토큰 이름 입력 후 생성 (예: `claude-mcp`)
4. 발급된 토큰 복사 (**한 번만 표시됨 — 반드시 저장**)

---

## 설치

터미널에서 아래 명령어 한 줄을 복사해서 실행하세요:

```bash
curl -sSL https://raw.githubusercontent.com/ignite-corp/claude-mcp-setup/main/install.sh | bash
```

설치 중 아래 정보를 입력받습니다:

| 입력 항목 | 설명 |
|-----------|------|
| Claude Code API Endpoint URL | 담당자에게 문의 |
| Claude Code 인증 토큰 | 위 1번에서 발급 |
| Atlassian URL | 예: `https://company.atlassian.net` |
| Atlassian 이메일 | Atlassian 로그인 이메일 |
| Atlassian API 토큰 | 위 2번에서 발급 |

## 설치되는 항목

| 항목 | 설명 |
|------|------|
| Homebrew | macOS 패키지 관리자 |
| NVM + Node.js 22 | Claude Code 실행 환경 |
| Claude Code | AI 코딩 어시스턴트 CLI |
| uv + mcp-atlassian | Jira/Confluence 연동 MCP 서버 |

이미 설치된 항목은 자동으로 스킵됩니다.

## 사용 방법

설치 완료 후 터미널에서:

```bash
claude
```

Claude Code 실행 후 `/mcp` 명령어로 Atlassian 연동 상태를 확인할 수 있습니다.

---

## 새 버전 릴리즈 방법

```bash
git tag v1.0.0
git push origin v1.0.0
```

태그를 푸시하면 GitHub Actions가 자동으로 Release를 생성하고 `setup.sh`를 배포합니다.
