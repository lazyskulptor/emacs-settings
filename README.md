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

```sh
# 1. Clone
git clone https://github.com/lazyskulptor/emacs-settings.git ~/.emacs.d

# 2. Python venv + 의존성
uv sync --directory ~/.emacs.d

# 3. Node 의존성
npm install --prefix ~/.emacs.d

# 4. properties.local.el 생성
cp ~/.emacs.d/properties.el ~/.emacs.d/properties.local.el
# → machine-specific 값 (JDK, Flutter 등) 편집
```

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

\* Clojure를 사용하지 않으면 생략 가능.

예시:
```elisp
(setq
 clojure-lsp-path    "/opt/homebrew/bin/clojure-lsp"
 java-lombok-path    "~/.emacs.d/.cache/lsp/lombok.jar"
 java-home-21        "/Library/Java/JavaVirtualMachines/jdk-21.0.3+9/Contents/Home"
 global-flutter-sdk-dir "/Users/hyeonjunpark/fvm/default"
 global-dart-sdk-dir    "/Users/hyeonjunpark/fvm/default/bin/cache/dart-sdk"
 dotnet-sdk-dir         "/usr/local/share/dotnet")
```

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

```sh
# 저장소 업데이트
git -C ~/.emacs.d pull

# Python 의존성 업데이트
uv sync --directory ~/.emacs.d --upgrade

# Node 의존성 업데이트
npm update --prefix ~/.emacs.d

# Emacs 패키지 업데이트
# M-x straight-pull-all 후 Emacs 재시작
```

## Troubleshooting

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
