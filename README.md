# 🤖 Agent-Docker: Universal AI Coding Agent Sandbox

**Agent-Docker**는 터미널 기반 AI 코딩 에이전트들(**Antigravity, Claude Code, OpenAI Codex, OpenCode, Hermes**)을 완전 격리된 Docker 컨테이너 환경에서 안전하고 강력하게 구동하기 위한 **올인원 샌드박스 시스템**입니다.

호스트 머신의 파일시스템(홈 디렉토리, SSH 키, 다른 프로젝트 등)을 완벽하게 보호하면서, 에이전트에게는 **무간섭 자동 승인(Auto-Approval)**과 **초고속 풀스택 툴체인**, **Camoufox 스텔스 브라우저 MCP**를 제공합니다.

---

## 🌟 핵심 특징 (Key Features)

1. **🛡️ 완전한 파일시스템 격리 (Strict Filesystem Isolation)**
   * 에이전트는 명령을 실행한 현재 작업 폴더(`$(pwd)`)와 그 하위만 접근할 수 있습니다.
   * 호스트 OS의 민감한 파일이나 상위 디렉토리 접근이 원천 차단됩니다.
2. **⚡ 무간섭 자동 승인 (Unattended Full-Auto Mode)**
   * 이미 완벽히 격리된 샌드박스이므로 매번 권한 승인 팝업 없이 최고 속도로 자율 코딩을 수행합니다.
3. **🦊 Camoufox 안티디텍트 브라우저 & MCP 서버 내장**
   * Cloudflare, Datadome, 봇 방지 캡차가 걸린 사이트도 C++ 패치 기반 스텔스 브라우저로 감지 없이 자동 탐색합니다.
   * 모든 에이전트에 `camoufox-mcp` 도구가 기본 등록됩니다.
4. **🧰 완벽한 풀스택 툴체인 & 패키지 캐시 연속성**
   * `Python 3.12 (uv/uvx)`, `Node.js 22 (pnpm)`, `Rust (cargo/rustc)`, `ast-grep`, `gh`, `ripgrep` 사전 탑재
   * `uv`, `npm`, `cargo` 패키지 캐시가 전용 볼륨에 보존되어 프로젝트를 옮겨도 다운로드 속도가 유지됩니다.
5. **🖥️ Herdr 멀티플렉서 완벽 연동**
   * `exec -a <agent>` 프로세스 위장 및 IPC 소켓 포워딩을 통해 `herdr` 터미널 사이드바에 각 에이전트의 상태와 알림이 실시간으로 잡힙니다.

---

## 📦 지원하는 AI 에이전트

| 에이전트 | 전용 단축 명령어 | 마스터 명령어 | 자동 연동 인증 경로 |
| :--- | :--- | :--- | :--- |
| **Google Antigravity** | `agy-docker` | `agent-docker agy` | `~/.gemini` |
| **Anthropic Claude Code** | `claude-docker` | `agent-docker claude` | `~/.claude` |
| **OpenAI Codex** | `codex-docker` | `agent-docker codex` | `~/.codex` |
| **OpenCode** | `opencode-docker` | `agent-docker opencode` | `~/.config/opencode` |
| **Hermes Agent** | `hermes-docker` | `agent-docker hermes` | `~/.hermes` |

---

## 🚀 빠른 시작 (Quick Start)

### 설치 (One-Liner Install)

```bash
git clone https://github.com/<username>/agent-docker.git ~/.config/agent-docker
~/.config/agent-docker/install.sh
```

### 사용법 (Usage)

어느 프로젝트 폴더에서든 원하는 명령어로 실행하세요:

```bash
cd ~/Dev/my-project

# 1. Antigravity 실행
agy-docker
# 또는
agent-docker agy

# 2. Claude Code 실행
claude-docker

# 3. OpenAI Codex 실행
codex-docker

# 4. 샌드박스 내부 디버깅용 Bash 셸 진입
agent-docker --shell

# 5. 최신 이미지 다시 빌드
agent-docker --build
```

---

## 📂 저장소 구조

```text
~/.config/agent-docker/
├── Dockerfile              # 통합 멀티 에이전트 베이스 이미지
├── Dockerfile.agy          # AGY 전용 단독 클린 이미지 (보관용)
├── entrypoint.sh          # 컨테이너 시작 시 MCP 자동 설정 및 환경 초기화
├── run.sh                 # 명령어 라우팅, 마운트, Herdr 연동 스크립트
├── install.sh             # 원클릭 심링크 등록 및 빌드 스크립트
├── docker-compose.yml     # Compose 설정 파일
└── test-workspace/        # 격리 및 Camoufox 테스트용 워크스페이스
```
