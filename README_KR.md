<div align="center">

# 🤖 Agent-Docker

**격리된 Docker 컨테이너 환경에서 모든 AI 코딩 에이전트를 안전하고 강력하게 구동하는 올인원 샌드박스**

[English](README.md) | [한국어](README_KR.md)

</div>

---

**Agent-Docker**는 주요 터미널 기반 AI 코딩 에이전트(**Google Antigravity, Anthropic Claude Code, OpenAI Codex, OpenCode, Hermes Agent**)를 완전 격리된 샌드박스 환경에서 실행할 수 있도록 설계된 도커 런타임입니다.

호스트 머신의 파일시스템(홈 디렉토리, SSH 키, 다른 프로젝트 코드 등)을 100% 안전하게 보호하면서, 에이전트에게는 **무간섭 자동 승인(Auto-Approval)**, **초고속 풀스택 툴체인**, 그리고 **Camoufox 안티디텍트 브라우저 MCP**를 제공합니다.

---

## 🌟 핵심 특징 (Key Features)

* **🛡️ 완전한 파일시스템 격리 (Strict Sandbox)**: 에이전트는 명령을 실행한 현재 디렉토리(`$(pwd)`)와 그 하위 파일만 접근할 수 있으며, 호스트 머신의 상위 경로는 원천 차단됩니다.
* **⚡ 무간섭 자율 코딩 모드 (Unattended Full-Auto)**: 이미 안전하게 격리되어 있으므로 매번 도구 실행 승인 팝업 없이 최고 속도로 코딩 작업을 수행합니다 (`--dangerously-skip-permissions`, `--dangerously-bypass-approvals-and-sandbox`, `--auto` 자동 적용).
* **🦊 Camoufox 안티디텍트 스텔스 브라우저 & MCP 내장**: Cloudflare, Datadome, 봇 방지 캡차가 걸린 사이트도 C++ 엔진 패치 기반 스텔스 브라우저로 감지 없이 스크래핑/렌더링하며, 모든 에이전트에 MCP 도구가 자동 등록됩니다.
* **🧰 풍부한 개발 도구 & 캐시 연속성**: Python 3.12 (`uv`/`uvx`), Node.js 22 (`pnpm`), Rust (`cargo`/`rustc`), `ast-grep` (`sg`), `gh`, `ripgrep`, `fd`, `jq`, `tree` 사전 탑재. 패키지 캐시가 전용 볼륨에 영구 보존됩니다.
* **🖥️ Herdr 멀티플렉서 완벽 연동**: `exec -a <agent>` 프로세스 위장 및 IPC 소켓 포워딩으로 `herdr` 터미널 사이드바에 각 에이전트의 상태와 실시간 완료 알림이 정상 수신됩니다.

---

## 📦 지원하는 AI 에이전트

| 에이전트 | 단축 실행 명령어 | 마스터 명령어 | 자동 마운트 인증 경로 |
| :--- | :--- | :--- | :--- |
| **Google Antigravity** | `agy-docker` | `agent-docker agy` | `~/.gemini` |
| **Anthropic Claude Code** | `claude-docker` | `agent-docker claude` | `~/.claude` |
| **OpenAI Codex** | `codex-docker` | `agent-docker codex` | `~/.codex` |
| **OpenCode** | `opencode-docker` | `agent-docker opencode` | `~/.config/opencode` |
| **Hermes Agent** | `hermes-docker` | `agent-docker hermes` | `~/.hermes` |

---

## 🚀 빠른 시작 (Quick Start)

### 1. 설치 (One-Liner Install)

```bash
git clone https://github.com/j3bit/agent-docker.git ~/.config/agent-docker
~/.config/agent-docker/install.sh
```

### 2. 사용법 (Usage)

원하는 프로젝트 폴더로 이동한 뒤 실행하세요:

```bash
cd ~/Dev/my-project

# Antigravity 실행
agent-docker agy
# 또는
agy-docker

# Claude Code 실행
agent-docker claude
# 또는
claude-docker

# OpenAI Codex 실행
agent-docker codex

# 샌드박스 내부 디버깅용 Bash 터미널 열기
agent-docker --shell

# 이미지 다시 빌드 (캐시 사용)
agent-docker --build

# 모든 에이전트 및 도구를 최신 버전으로 강제 업데이트 (--no-cache)
agent-docker --update
```

---

## 🔒 격리(Sandbox) 동작 원리

1. **디렉토리 바인드 마운트 (`-v "$PWD:/workspace"`)**: 지정된 프로젝트 폴더만 컨테이너의 `/workspace`에 연결됩니다.
2. **인증 정보 공유**: `~/.gemini`, `~/.claude`, `~/.codex`, `~/.config/gh` 등 호스트의 로그인 세션을 그대로 공유하여 재로그인이 불필요합니다.
3. **권한 일치 (UID/GID Mapping)**: 호스트 사용자의 UID/GID를 컨테이너 내부 `developer` 계정과 일치시켜 파일 소유권 잠김을 방지합니다.
4. **Herdr 프로세스 & 소켓 연동**: `exec -a <agent>`로 프로세스 이름을 보고하고 IPC 소켓을 연결하여 터미널 멀티플렉서에 실시간 상태를 전달합니다.

---

## 📄 라이선스 (License)

이 프로젝트는 [MIT License](LICENSE)에 따라 배포됩니다.
