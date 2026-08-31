<div align="center">

# 🤖 Agent-Docker

**격리된 Docker 컨테이너 환경에서 모든 AI 코딩 에이전트를 안전하고 강력하게 구동하는 올인원 샌드박스**

[English](README.md) | [한국어](README_KR.md)

</div>

---

**Agent-Docker**는 주요 터미널 기반 AI 코딩 에이전트(**Google Antigravity, Anthropic Claude Code, OpenAI Codex, OpenCode, Hermes Agent**)를 격리된 샌드박스 환경에서 실행할 수 있도록 설계된 도커 런타임입니다.

호스트의 다른 프로젝트와 개인 파일을 건드리지 않으면서, 에이전트에게는 **무간섭 자동 승인(Auto-Approval)**, **초고속 풀스택 툴체인**, 그리고 **Camoufox 안티디텍트 브라우저 MCP**를 제공합니다.

> **⚠️ 격리를 신뢰하기 전에 [보안 및 샌드박스 구조](#-보안-및-샌드박스-구조)를 반드시 읽어주세요.** 샌드박스 안에서 skill과 plugin을 수정할 수 있도록 에이전트 설정 디렉토리는 **의도적으로 읽기/쓰기로 마운트**되어 있습니다. 완전한 격리가 아닙니다.

---

## 🌟 핵심 특징 (Key Features)

* **🛡️ 워크스페이스 단위 파일시스템**: 에이전트는 명령을 실행한 현재 디렉토리(`$(pwd)`)만 `/workspace`로 보게 됩니다. 다른 저장소나 `~/.ssh`, `~/.aws`, `~/Documents`는 아예 마운트되지 않습니다.
* **⚡ 무간섭 자율 코딩 모드**: 도구 실행마다 승인 팝업 없이 최고 속도로 작업합니다 (`--dangerously-skip-permissions`, `--dangerously-bypass-approvals-and-sandbox`, `--auto` 자동 적용).
* **🔑 로그인 상태 영속화**: 한 번만 로그인하면 됩니다. `docker run --rm`으로 컨테이너가 사라져도 전용 상태 디렉토리에 세션이 남아, 실행할 때마다 온보딩을 다시 하지 않습니다.
* **🦊 Camoufox 안티디텍트 스텔스 브라우저 & MCP 내장**: Cloudflare, Datadome, 봇 방지 캡차가 걸린 사이트도 C++ 엔진 패치 기반 스텔스 브라우저로 감지 없이 처리하며, 모든 에이전트에 MCP 도구가 자동 등록됩니다.
* **🧰 풍부한 개발 도구 & 캐시 연속성**: Python 3.12 (`uv`/`uvx`), Node.js 22 (`pnpm`), Rust (`cargo`/`rustc`), `ast-grep` (`sg`), `gh`, `git-lfs`, `ripgrep`, `fd`, `jq`, `bubblewrap`, `socat`, `tree` 사전 탑재. 패키지 캐시(`uv`, `npm`, `pip`, `cargo`)가 전용 볼륨에 영구 보존됩니다.
* **🖥️ Herdr 멀티플렉서 완벽 연동**: `exec -a <agent>` 프로세스 위장 및 IPC 소켓 포워딩으로 `herdr` 터미널 사이드바에 각 에이전트의 상태와 실시간 완료 알림이 정상 수신됩니다.

---

## 📦 지원하는 AI 에이전트

| 에이전트 | 단축 실행 명령어 | 마스터 명령어 | 자동 마운트 인증 경로 |
| :--- | :--- | :--- | :--- |
| **Google Antigravity** | `agy-docker` | `agent-docker agy` | `~/.gemini` |
| **Anthropic Claude Code** | `claude-docker` | `agent-docker claude` | `~/.claude` + `state/claude.json` |
| **OpenAI Codex** | `codex-docker` | `agent-docker codex` | `~/.codex` |
| **OpenCode** | `opencode-docker` | `agent-docker opencode` | `~/.config/opencode` |
| **Hermes Agent** | `hermes-docker` | `agent-docker hermes` | `~/.hermes` |

---

## 🚀 빠른 시작 (Quick Start)

### 1. 설치 (Installation)

```bash
git clone https://github.com/j3bit/agent-docker.git ~/.config/agent-docker
cd ~/.config/agent-docker

# 대화형 설치: 설치할 에이전트를 고른 뒤 바로 빌드
./install.sh
```

`install.sh`는 에이전트를 하나씩 물어본 뒤 답변을 `agent-docker.env`에 저장합니다.
이 파일을 직접 편집하고 언제든 다시 적용할 수 있습니다:

```bash
# 현재 설정 확인
agent-docker config

# agent-docker.env 를 수정한 뒤 반영
agent-docker --build
```

필요한 에이전트만 설치하면 빌드 시간과 이미지 용량이 크게 줄어듭니다.

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

## 🔑 인증 (Authentication)

호스트의 로그인 세션이 그대로 마운트되므로 대부분의 에이전트는 추가 설정이 필요 없습니다.

**Claude Code**는 상태가 두 군데로 나뉘어 있고, 그중 하나만 호스트와 공유해도 안전합니다:

| 위치 | 담긴 것 | 처리 방식 |
| :--- | :--- | :--- |
| `~/.claude/` | settings, skills, hooks, `.credentials.json` | 호스트에서 읽기/쓰기로 마운트 |
| `~/.claude.json` | 온보딩 완료 플래그, `oauthAccount`, user-scope MCP, 프로젝트 신뢰 | **컨테이너 전용**, `state/claude.json`에 보관 |

두 번째 파일을 분리한 건 의도적입니다. macOS 전용 호스트 상태가 들어있어서 리눅스 컨테이너가
덮어쓰면 안 되기 때문입니다. 반대로 아예 마운트하지 않으면 `--rm` 실행마다 온보딩과 로그인을
처음부터 다시 하게 됩니다.

### 확정적인 로그인 (권장)

macOS에서는 OAuth 토큰이 Keychain에만 저장될 수 있는데, 리눅스 컨테이너는 이를 읽지 못합니다.
샌드박스가 `Not logged in`을 띄운다면 호스트에서 장기 토큰을 발급하세요:

```bash
claude setup-token
```

그리고 `agent-docker.env`에 넣습니다:

```bash
CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...
```

`agent-docker.env`는 git에서 제외되어 있습니다. `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`,
`OPENAI_API_KEY`, `GH_TOKEN`, `GITHUB_TOKEN`도 셸 환경변수에서 그대로 전달됩니다.

---

## 🔧 샌드박스 안의 Git

호스트의 `~/.gitconfig`는 **의도적으로 마운트하지 않습니다.** 보통 컨테이너에 없는 호스트 전용
도구(`delta`, `neovide`, Homebrew 경로의 `gh`, `required = true`인 LFS 필터)를 참조하고 있어서
그대로 가져오면 모든 `git` 명령이 깨집니다.

대신 entrypoint가 컨테이너 전용 `~/.gitconfig`를 생성합니다:

* `safe.directory = *` — Docker Desktop이 바인드 마운트를 컨테이너 유저와 다른 UID로 노출하기 때문에, 이게 없으면 git이 모든 명령을 `detected dubious ownership`으로 거부합니다. 와일드카드라 서브모듈·중첩 repo·worktree까지 함께 커버합니다. 여기서 닿는 모든 경로는 이미 컨테이너 안입니다.
* `credential.helper = !gh auth git-credential` — 컨테이너 자체의 `gh`를 사용합니다.
* `init.defaultBranch = main`.

커밋 신원은 호스트의 global git 설정에서 읽어 `GIT_USER_NAME` / `GIT_USER_EMAIL`로 전달되므로,
샌드박스 안에서 만든 커밋도 본인 이름으로 기록됩니다.

---

## 🔒 보안 및 샌드박스 구조

```text
[호스트 머신]
  ~/.ssh, ~/.aws, ~/Documents, 다른 저장소   ──► 🛡️ 마운트 안 됨
  $(pwd) (현재 프로젝트 디렉토리)            ──► 📂 /workspace 로 연결
  ~/.gemini ~/.claude ~/.codex               ──► ⚠️ 읽기/쓰기 마운트
  ~/.agents ~/.hermes ~/.config/gh           ──► ⚠️ 읽기/쓰기 마운트

[Docker 컨테이너 (/workspace)]
  Developer 유저 (호스트와 UID/GID 일치)
  ├── 사전 탑재 런타임: uv (Python), Node 22 (pnpm), Rust (cargo), ast-grep
  ├── Camoufox 안티디텍트 브라우저 & MCP 서버 (xvfb, GUI 라이브러리, CJK 폰트)
  └── AI 에이전트 CLI (샌드박스 경계 안에서 자동 승인 모드로 동작)
```

1. **디렉토리 바인드 마운트 (`-v "$PWD:/workspace"`)**: 지정된 프로젝트 폴더만 노출됩니다.
2. **인증 정보 공유**: `$HOME`의 인증 디렉토리를 마운트하여 재로그인이 불필요합니다.
3. **권한 일치 (UID/GID Mapping)**: 호스트 사용자의 UID/GID를 컨테이너 `developer` 계정과 일치시켜 파일 소유권 잠김을 방지합니다.
4. **Herdr 프로세스 & 소켓 연동**: `exec -a <agent>`로 프로세스 이름을 보고하고 IPC 소켓을 연결하여 터미널 멀티플렉서에 실시간 상태를 전달합니다.

### ⚠️ 이 샌드박스가 막아주지 *않는* 것

에이전트 설정 디렉토리는 샌드박스 안에서 skill, plugin, 에이전트 설정을 수정할 수 있도록
**의도적으로 읽기/쓰기로** 마운트되어 있습니다. 그 결과 자동 승인으로 도는 에이전트는 다음이
가능합니다:

* `~/.claude/settings.json`의 hooks 수정 → **다음에 Docker 밖에서 에이전트를 실행할 때 호스트에서 그대로 실행됩니다**
* `~/.claude`, `~/.agents` 아래 skill과 plugin 추가·변조
* 마운트된 `~/.config/gh` 자격증명으로 접근 권한이 있는 아무 저장소에나 push

컨테이너 entrypoint가 실행할 때마다 이 경고를 출력합니다. 이 샌드박스는 *내 프로젝트 파일과
무관한 저장소를 보호하는 장치*이지, 악의적인 에이전트를 막는 경계가 아닙니다. 더 강한 격리가
필요하면 `run.sh`에서 설정 마운트를 제거하고, 재로그인과 skill 공유 상실을 감수해야 합니다.

### 에이전트 자동 업데이트

자동 업데이트는 꺼져 있습니다 — `DISABLE_AUTOUPDATER=1`(Claude Code),
`OPENCODE_DISABLE_AUTOUPDATE=1`, `AGY_CLI_DISABLE_AUTO_UPDATE=true`. Codex는 별도 변수가
필요 없습니다. npm 런처가 `CODEX_MANAGED_BY_NPM`을 설정해 자체 업데이트를 이미 막습니다.

에이전트는 root로 설치되지만 실행은 권한 없는 `developer` 유저로 하며, 어차피 `--rm` 때문에
런타임에 받은 업데이트는 사라집니다. 버전 관리 단위는 이미지이므로, 이제 스스로 갱신되는 것이
없는 만큼 `agent-docker --update`를 주기적으로 돌려주셔야 합니다.

---

## 📂 저장소 구조

```text
~/.config/agent-docker/
├── Dockerfile              # 모든 툴체인이 포함된 통합 멀티 에이전트 베이스 이미지
├── entrypoint.sh           # 컨테이너 entrypoint: MCP 및 git 자동 설정
├── run.sh                  # 실행 런처, 인증 라우터, Herdr 브리지
├── install.sh              # 대화형 에이전트 선택 및 빌드 설치 스크립트
├── agent-docker.env        # 로컬 설정: 설치할 에이전트, 인증 토큰 (git 제외)
├── agent-docker.env.example # 위 파일의 템플릿
├── docker-compose.yml      # run.sh 와 동기화된 Compose 정의
├── state/                  # 컨테이너 측 영속 상태 (git 제외)
├── README.md               # 영문 문서
└── README_KR.md            # 한글 문서
```

---

## 📄 라이선스 (License)

이 프로젝트는 [MIT License](LICENSE)에 따라 배포됩니다.
