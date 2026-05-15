# Claude Code + HMG Atlassian 설치 마법사

HMG Atlassian(Jira, Confluence)을 Claude Code와 연동하는 인터랙티브 설치 도구입니다.

## 설치

터미널에서 아래 명령어 한 줄을 복사해서 실행하세요:

```bash
curl -sSL https://raw.githubusercontent.com/ignite-corp/claude-mcp-setup/main/install.sh | bash
```

## 설치되는 항목

| 항목 | 설명 |
|------|------|
| Homebrew | macOS 패키지 관리자 |
| Node.js | Claude Code 실행 환경 |
| Claude Code | AI 코딩 어시스턴트 CLI |
| mcp-atlassian | Jira/Confluence 연동 MCP 서버 |

이미 설치된 항목은 자동으로 스킵됩니다.

## 사용 방법

설치 완료 후 터미널에서:

```bash
claude
```

Claude Code 실행 후 `/mcp` 명령어로 HMG Atlassian 연동 상태를 확인할 수 있습니다.

## 새 버전 릴리즈 방법

```bash
git tag v1.0.0
git push origin v1.0.0
```

태그를 푸시하면 GitHub Actions가 자동으로 Release를 생성하고 `setup.sh`를 배포합니다.
