# emacs-settings

개인 Emacs 설정 저장소. `straight.el`로 패키지를 관리하고, `uv` + `npm`으로 외부 LSP 도구 의존성을 `.emacs.d` 내에 설치한다.

## Prerequisites

### Required

| 프로그램 | 용도 | 설치 (macOS) |
|---|---|---|
| `git` | 저장소 clone | `xcode-select --install` |
| `emacs` 29+ | 편집기 | `brew install --cask emacs` |
| `gcc` + `libgccjit` | native-comp (early-init.el) | `brew install gcc` |
| `uv` | Python 패키지 + venv 관리 | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `node` / `npm` | Node LSP 도구 | `brew install node` |
| Monoid 폰트 | UI 기본 폰트 | AGENTS.md 하단 참조 |

### Optional (언어/기능별)

| 도구 | 용도 | 설치 |
|---|---|---|
| `ripgrep` | 검색 가속 (consult) | `brew install ripgrep` |
| `fd` | 파일 검색 가속 | `brew install fd` |
| `socat` | MCP 서버 | `brew install socat` |
| `latexmk` | Org LaTeX export | `brew install --cask mactex` |
| Go (`go`, `gopls`, `dlv`) | Go 개발 | `brew install go` + `go install ...` |
| JDK 11/17/21 | Java 개발 | `brew install openjdk@21` 등 |
| `clojure-lsp` | Clojure LSP | `brew install clojure-lsp` |
| FVM | Flutter/Dart SDK 관리 | `brew tap leoafarias/fvm && brew install fvm` |
| `ruff` (선택) | Python 린터/포매터 | `uv tool install ruff` |

## Installation

빠른 설치:
```sh
git clone https://github.com/lazyskulptor/emacs-settings.git ~/.emacs.d
bash ~/.emacs.d/scripts/install.sh
emacs
```

`scripts/install.sh`는 필수 도구(uv/node) 확인, `uv sync`/`npm install` 실행,
`properties.local.el` 생성(템플릿: `properties.local.el.example`, 이미 존재하면 덮어쓰지
않음)을 한 번에 수행한다. 설치 상태는 언제든 `bash ~/.emacs.d/scripts/doctor.sh`로 재점검할 수 있다.

수동 설치 (동일한 단계):
```sh
# 1. Clone
git clone https://github.com/lazyskulptor/emacs-settings.git ~/.emacs.d

# 2. Python venv + 의존성
uv sync --directory ~/.emacs.d

# 3. Node 의존성
npm install --prefix ~/.emacs.d

# 4. properties.local.el 생성
cp ~/.emacs.d/properties.local.el.example ~/.emacs.d/properties.local.el
# → machine-specific 값 (JDK, Flutter 등) 편집
```

**주의**: `properties.el` 자체를 복사하지 말 것. `properties.el`은 끝부분에서
`properties.local.el`을 `load`하는 코드를 포함하므로, 그 파일을 그대로 복사하면 사본이
자기 자신을 무한 로드하다 스택 오버플로가 난다. 반드시 `properties.local.el.example`을
복사할 것.

## direnv (선택사항)

Clojure/Maven 프로젝트의 GitHub Packages 인증에 필요한 환경변수(`GITHUB_ACTOR`, `GITHUB_TOKEN`)를
프로젝트별로 자동 관리하려면 **direnv** 설치:

```sh
# macOS (Homebrew)
brew install direnv

# Linux (APT)
sudo apt-get install direnv

# Linux (Fedora/RHEL)
sudo yum install direnv

# Linux (Arch)
sudo pacman -S direnv
```

설치 후 shell hook 등록 (`.bashrc` / `.zshrc` / `~/.config/fish/config.fish` 등):

```bash
# For Bash
eval "$(direnv hook bash)" >> ~/.bashrc

# For Zsh
eval "$(direnv hook zsh)" >> ~/.zshrc
```

프로젝트 폴더에 `.envrc` 파일을 추가 (예: `translator/`):

```bash
# translator/.envrc
export GITHUB_ACTOR=<your-github-username>
export GITHUB_TOKEN=<your-personal-access-token>
```

`.envrc` 승인:

```bash
cd translator/
direnv allow
```

이제 `cd translator` 할 때마다 자동으로 환경변수가 설정되어, `lein` / `clojure` 명령어가
GitHub Packages 저장소에 접근할 수 있다.

언어별(Go/Java/Clojure/PowerShell 등) LSP 도구는 `install.sh`가 다루지 않는 optional
의존성이다 — AGENTS.md의 "External Dependencies" 절과 아래 Optional 표를 참고해 필요한
것만 설치한다.

## `properties.local.el` 설정

`properties.local.el`은 `.gitignore`로 보호되는 머신별 설정 파일. 아래 변수들을 실제 환경에 맞게 설정:

| 변수 | 필수 | 설명 |
|---|---|---|
| `clojure-lsp-path` | 아니오* | Clojure LSP 바이너리 전체 경로 |
| `java-lombok-path` | 아니오 | Lombok JAR 경로 (JDT.LS -javaagent) |
| `java-home-21` | 아니오 | JDK 21 Home |
| `java-home-17` | 아니오 | JDK 17 Home |
| `java-home-11` | 아니오 | JDK 11 Home |
| `global-flutter-sdk-dir` | 아니오 | Flutter SDK 경로 (FVM) |
| `global-dart-sdk-dir` | 아니오 | Dart SDK 경로 (FVM) |
| `dotnet-sdk-dir` | 아니오 | .NET SDK 경로 |
| `wiki-dir` | 아니오 | Wiki 디렉토리 |
| `wiki-archive-dir` | 아니오 | Wiki 아카이브 디렉토리 |
| `notmuch-site-lisp-dir` | 아니오 | notmuch elisp 경로 (Homebrew 등) |
| `ditaa-jar-path` / `ditaa-exec-path` | 아니오 | Org ditaa 블록용 JAR/실행파일 |
| `mcp-server-local-repo` | 아니오 | emacs-mcp-server fork 개발 모드 경로 |
| `lsp-bridge-powershell-local-repo` | 아니오 | lsp-bridge fork 개발 모드 경로 |
| `saider-path` | 아니오 | aider(saider) 바이너리 경로 (기본값 `~/.local/bin/saider`) |
| `slack-team-name` / `slack-token` / `slack-cookie` | 아니오 | Slack 인증 정보 |

\* Clojure를 사용하지 않으면 생략 가능.

예시 (`properties.local.el.example` 참고):
```elisp
(setq
 clojure-lsp-path    "/opt/homebrew/bin/clojure-lsp"
 java-lombok-path    "~/.emacs.d/.cache/lsp/lombok.jar"
 java-home-21        "/Library/Java/JavaVirtualMachines/jdk-21.0.3+9/Contents/Home"
 global-flutter-sdk-dir "/Users/hyeonjunpark/fvm/default"
 global-dart-sdk-dir    "/Users/hyeonjunpark/fvm/default/bin/cache/dart-sdk"
 dotnet-sdk-dir         "/usr/local/share/dotnet"
 notmuch-site-lisp-dir  "/opt/homebrew/share/emacs/site-lisp/notmuch"
 ditaa-jar-path         "/opt/homebrew/Cellar/ditaa/0.11.0_1/libexec/ditaa-0.11.0-standalone.jar"
 ditaa-exec-path        "/opt/homebrew/bin/ditaa"
 slack-team-name        "my-team"
 slack-token            "xoxs-..."
 slack-cookie           "...")
```

## Configuration boot sequence

`init.el`은 최소 부팅 파일로 유지하고, 실제 설정 모듈의 로드와 의존성 순서는
`required-packages.el`에서 관리한다. 이 분리로 기본 `init.el` 변경을 설정 모듈의
Git 이력과 분리할 수 있다.

부팅 순서:

1. `init.el`이 `required-packages.el`을 `load`한다.
2. `required-packages.el`이 `properties.el`을 읽고 `config/`와 `config/ide/`를
   `load-path`에 추가한다.
3. 공통 유틸리티와 UI를 먼저 로드한 뒤, `remote.el`을 `(require 'remote)`로 로드한다.
4. completion, Eshell, LSP 등 `remote.el` 이후 모듈을 순서대로 로드한다.

`remote.el`은 `~/.emacs.d/config/remote.el`에 있으며 TRAMP, SSH, 원격 환경변수
설정을 담당한다. 실행 중 로드 여부는 `M-: (featurep 'remote)`로 확인할 수 있다.
`required-packages.el`을 다시 로드한 뒤의 `(require 'required-packages)`는 feature가
이미 제공된 경우 no-op이므로, 중복 로드 오류를 의미하지 않는다.

## First Run

```sh
emacs  # 또는 'open /Applications/Emacs.app'
```

첫 실행 시 자동으로 진행되는 작업:

1. **straight.el** 부트스트랩 (5~10분 소요, 모든 Emacs 패키지 설치)
2. Emacs 재시작 후 Python 파일 열기 → **`.emacs.d/.venv/`** 확인 (my/ensure-emacs-venv)
3. JS/TS 파일 열기 → **`.emacs.d/node_modules/.bin/`** 경로로 LSP 서버 자동 검색
4. Org 파일 Python 코드 블록 → `uv run python`으로 실행

**참고**: JS/TS 프로젝트에서 `typescript-language-server`를 프로젝트 버전으로 사용하려면:
```sh
cd ~/Workspace/your-ts-project
npm install --save-dev typescript typescript-language-server eslint
```

## Update

### 자동 체크 (Background)

Emacs 시작 후 idle 10초가 지나면, 하루 1회 자동으로 저장소 git 상태만 확인한다
(`make-process`로 비동기 background fetch — Emacs를 블로킹하지 않음). 뒤처져 있으면
echo area에 알림이 뜬다:

```
[Emacs] Config: 5 commits behind origin/main. Run M-x my/emacs-update to pull.
```

### 수동 업데이트

항상 수동으로 적용:

```
M-x my/emacs-update
```

이 커맨드는:
1. `scripts/update.sh` 실행 (git pull + `uv sync --upgrade` + `npm update`)
2. `straight-pull-all`로 모든 Emacs 패키지 업데이트
3. 결과를 `*emacs-update*` 버퍼에 표시

터미널에서 저장소/의존성 부분만 따로 업데이트:

```sh
bash ~/.emacs.d/scripts/update.sh
```

자동 체크 간격 변경 (`properties.local.el`):

```elisp
;; 기본값: 86400 (24시간), 0으로 설정하면 비활성화
(setq my/update-check-interval 86400)
```

## Troubleshooting

먼저 `bash ~/.emacs.d/scripts/doctor.sh`로 필수 도구/설치 상태를 한 번에 점검한다.

### lsp-bridge가 LSP 서버를 찾지 못함
LSP 서버 바이너리가 `~/.emacs.d/node_modules/.bin/`에 있는지 확인:
```sh
ls ~/.emacs.d/node_modules/.bin/typescript-language-server
```
없으면 `npm install --prefix ~/.emacs.d` 실행.

### Python venv 관련 에러
```sh
uv sync --directory ~/.emacs.d
~/.emacs.d/.venv/bin/python -c "import epc"  # 정상 동작 확인
```

### native-comp 에러 (macOS)
`early-init.el`이 Homebrew GCC 경로를 설정. GCC 설치 상태 확인:
```sh
brew list gcc            # 설치 확인
ls /opt/homebrew/lib/    # libgccjit 존재 확인
```

### Emacs가 실행되지 않음 / 무한 로딩
```sh
emacs --debug-init       # 백트레이스 확인
```
`straight/` 디렉토리 삭제 후 재시작:
```sh
rm -rf ~/.emacs.d/straight
```

### direnv 설정 관련

direnv가 설치되었으나 환경변수가 로드되지 않는 경우:

```sh
# Shell hook이 등록되었는지 확인
grep "direnv hook" ~/.bashrc   # 또는 ~/.zshrc / ~/.config/fish/config.fish

# 등록되지 않았으면
eval "$(direnv hook bash)" >> ~/.bashrc
source ~/.bashrc

# 또는 현재 셸에서 임시로 hook 활성화
eval "$(direnv hook bash)"
```

`.envrc` 파일이 있는데도 변수가 로드되지 않는 경우:

```sh
# .envrc 승인
cd <project-dir>
direnv allow

# 상태 확인
direnv status
```

direnv를 제거하려면:

```sh
brew uninstall direnv       # macOS
# 또는
sudo apt-get remove direnv  # Linux (APT)
sudo yum remove direnv      # Linux (Fedora/RHEL)

# Shell hook도 제거 (.bashrc / .zshrc 등에서)
eval "$(direnv hook bash)" 라인 삭제
```
