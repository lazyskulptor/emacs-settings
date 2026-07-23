# AGENTS.md

This file provides guidance to AI agents (Claude Code and OpenCode) when working with code in this repository.

## Repository Purpose

This is a personal Emacs configuration (`~/.emacs.d`) — an Emacs Lisp codebase, not a compiled project. There are no build, lint, or test commands. Changes take effect by restarting Emacs or evaluating the changed buffer (`M-x eval-buffer`).

## Architecture

### Load Order

```
init.el → required-packages.el → properties.el + properties.local.el + all config/* modules
```

1. `init.el` — bootstraps the package system (MELPA), installs `use-package`, sets backup dir, loads the zenburn theme
2. `required-packages.el` — the single loader that requires every config module in order
3. `properties.el` — environment variables, SDK paths (Flutter/Dart/Clojure LSP/Lombok), locale; loads `properties.local.el` if it exists

### Config Module Layout

```
config/
├── interface.el         # UI, keybindings, Evil prefix maps
├── utils.el             # Utility functions
├── remote.el            # TRAMP + SSH + remote env
├── org-setting.el       # Org-mode, pomodoro, LaTeX export, wiki agenda/archive
├── org-table-align.el   # Org table alignment
├── slack-setting.el     # Slack client (token/cookie auth)
├── mcp-server-setting.el # MCP server configuration
├── agent-shell-setting.el # Agent Shell integration
├── wiki-tools.el        # Wiki management (Org→MD archive, validation, AI formatting)
├── sql-connections.el   # SQL/JDBC connections (optional, gitignored)
└── ide/
    ├── completion.el    # Completion UI (vertico, corfu, consult)
    ├── lsp-bridge.el    # LSP Bridge core (server commands, keys, peek)
    ├── languages.el     # Language-specific settings (Python, Go, Java, Groovy, JS/TS, YAML)
    ├── projectile.el    # Projectile project management
    ├── dap.el           # Debug Adapter Protocol
    ├── ejc.el           # SQL/JDBC client
    ├── eshell-config.el # eshell settings (prompt, bash-completion, aliases)
    └── tools.el         # Misc tools
```

Each file ends with `(provide '<module-name>)` and is loaded via `(require ...)` in `required-packages.el`.

### Key Design Patterns

- All packages managed declaratively via `use-package`
- SDK/tool/wiki paths are centralised in `properties.el` with defaults; machine-specific values go in `properties.local.el` (gitignored) — config modules reference these variables, never hardcode paths directly
- SQL connection credentials live in `config/sql-connections.el` (gitignored, optional)
- eshell built-in aliases (`eshell/ll`, `eshell/la`)는 `eshell-config.el`에서 정의

### `properties.el` Variables Reference

| Variable | Purpose |
|---|---|
| `java-lombok-path` | Lombok JAR path for JDT.LS `-javaagent` |
| `java-home-21` | JDK 21 home |
| `java-home-17` | JDK 17 home |
| `java-home-11` | JDK 11 home |
| `clojure-lsp-path` | Clojure LSP binary path |
| `global-flutter-sdk-dir` | Flutter SDK root (via FVM) |
| `global-dart-sdk-dir` | Dart SDK root (via FVM) |

새 머신 설정: `properties.el` 상단 주석의 예시를 참고해 `properties.local.el`을 생성.

## External Dependencies

모든 LSP 서버 바이너리는 **`~/.emacs.d/` 내부**에서 관리한다. 글로벌 설치(Homebrew 등)는 bootstrap용 패키지 매니저가 아니면 사용하지 않는다.

### Python LSP (`.venv/bin/`)
`pyproject.toml`이 관리하며 `uv sync`로 설치:
```sh
uv sync --directory ~/.emacs.d
```
- `basedpyright`, `debugpy`, `epc`, `sexpdata`, `watchdog`, `orjson`, `grip`

### Node LSP (`node_modules/.bin/`)
`package.json`이 관리하며 `npm install`로 설치:
```sh
npm install --prefix ~/.emacs.d
```
- `typescript-language-server`, `yaml-language-server`, `bash-language-server`
- `vscode-langservers-extracted`, `groovy-language-server`, `eslint`

### Go LSP (`~/.emacs.d/.cache/lsp/<name>/`)
설치는 Emacs 명령으로 수행 (자동 설치 없음):

```sh
# LSP 서버 (gopls, terraform-ls)
M-x my/install-emacs-lsp-tools

# Go 개발 도구 (dlv, gomodifytags, impl)
M-x my/install-emacs-go-development-tools
```

또는 개별 `go install`:
```sh
mkdir -p ~/.emacs.d/.cache/lsp/gopls && GOBIN=~/.emacs.d/.cache/lsp/gopls go install golang.org/x/tools/gopls@latest
mkdir -p ~/.emacs.d/.cache/lsp/terraform-ls && GOBIN=~/.emacs.d/.cache/lsp/terraform-ls go install github.com/hashicorp/terraform-ls@latest
mkdir -p ~/.emacs.d/.cache/lsp/dlv && GOBIN=~/.emacs.d/.cache/lsp/dlv go install github.com/go-delve/delve/cmd/dlv@latest
mkdir -p ~/.emacs.d/.cache/lsp/gomodifytags && GOBIN=~/.emacs.d/.cache/lsp/gomodifytags go install github.com/fatih/gomodifytags@latest
mkdir -p ~/.emacs.d/.cache/lsp/impl && GOBIN=~/.emacs.d/.cache/lsp/impl go install github.com/josharian/impl@latest
```

### Clojure LSP (`~/.emacs.d/.cache/lsp/clojure-lsp/clojure-lsp`)
GitHub Release에 의존하지 않음. upstream `master` branch 소스를 `~/.emacs.d/.cache/src/clojure-lsp/`에 shallow clone하고 `bb prod-cli`로 build. Script가 git/Clojure CLI/JDK를 자동 확인:

```sh
bash ~/.emacs.d/scripts/install-clojure-lsp.sh
```

Build 도구인 Babashka (`bb`)는 `~/.emacs.d/.cache/tools/bb/bb`에 관리:

```sh
bash ~/.emacs.d/scripts/install-babashka.sh
```

Clojure LSP binary (`clojure-lsp`)는 `.cache/lsp/`에, build tool (`bb`)는 `.cache/tools/`에 위치. Clojure CLI와 JDK는 source build 시 필요한 runtime prerequisite이며 system/global에 설치한다.

### Java LSP (JDT.LS — `~/.emacs.d/.cache/lsp/eclipse.jdt.ls/`)
`lsp-bridge-install-jdtls` 명령어로 설치. Lombok JAR은 `~/.emacs.d/lsp/lombok.jar`에 위치.

### Dart/Flutter LSP
FVM으로 관리되는 Flutter SDK 사용. `properties.local.el`의 `global-flutter-sdk-dir` / `global-dart-sdk-dir` 경로 참조. SDK 전체를 Emacs 내부로 옮길 수 없으므로 FVM 경로 유지.

### C# (OmniSharp)
`lsp-bridge-install-omnisharp`로 `~/.emacs.d/.cache/omnisharp/`에 설치.

### Python (CLI — `uv`)
패키지 매니저 자체는 시스템에 설치:
```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Other implicit dependencies: JDK (for Eclipse JDT.LS), Flutter/FVM.

```sh
# Font (Monoid)
curl -o monoid.zip https://cdn.jsdelivr.net/gh/larsenwork/monoid@2db2d289f4e61010dd3f44e09918d9bb32fb96fd/Monoid.zip
```

## Language-specific Notes

### Python (`config/ide/languages.el`)
- `.venv`가 없으면 uv로 자동 생성, `pyproject.toml`이 있으면 `uv sync`까지 실행
- direnv 연동: 프로젝트 루트에 `.envrc` (`source .venv/bin/activate`) + `M-x envrc-allow`
- 디버깅: `dap-debug → Python :: Run file` 첫 실행, 이후 `C-t r`
- ruff/pytest 단축키: 별도 이슈(#13)로 추적 중

### Go (`config/ide/languages.el`)
- 저장 시 `gofmt` + import 자동 정리
- 단축키: `C-c t a/r` (struct 태그), `C-c i` (interface 스텁), `C-c t t/f/p` (gotest)
- 디버깅: `dap-debug → Go :: Run file` 첫 실행, 이후 `C-t r`

### YAML (`config/ide/languages.el`)
- `yaml-language-server` 사용, Kubernetes/Docker Compose/Ansible 스키마 자동 적용
- `C-c y s` — 버퍼에 스키마 수동 선택

### eshell (`config/ide/eshell-config.el`)
- evil-mode와 함께 사용 시 insert 모드로 시작, RET → `eshell-send-input`으로 바인딩
- `eshell/ll`, `eshell/la` built-in alias 정의됨 (`eshell-config.el`)

## Editing Guidelines

- **ELPA 패키지 파일 수정 금지**: `~/.emacs.d/elpa/` 하위 파일은 절대 직접 수정하지 않는다. 패키지 코드를 커스터마이징해야 할 경우 `advice-add`를 사용하여 `config/` 모듈에서 감싼다.
- **새 언어 config 추가**: `config/ide/languages.el`에 언어별 설정 추가 → `config/ide/lsp-bridge.el`의 hook에 mode 추가
- **새 top-level 모듈 추가**: `config/<name>-setting.el` 생성 → `required-packages.el`에 `require` 추가
- **경로/환경변수**: `properties.el`에 기본값 추가, `properties.local.el`에 실제 값 설정
- **민감한 값** (토큰, 비밀번호, DB 자격증명): `config/sql-connections.el` 또는 `properties.local.el`에만 저장 — gitignore 확인 필수
- **`init.el` 수정 금지**: `init.el`은 `.gitignore`에 등록되어 있어 git에 반영되지 않습니다. init.el에 추가해야 할 내용은 `required-packages.el` (모듈 로드), `properties.el` (환경변수/경로 기본값), `properties.local.el` (머신별 실제 값) 파일들을 통해 관리합니다.
- **Upstream 패키지 fork 개발**: `advice-add`로 해결 불가능한 변경(람다 클로저 내부, 매크로 확장 등)만 fork한다.
  1. GitHub에 fork 생성 (`gh repo fork upstream/repo --clone=false`)
  2. `~/Workspace/contribute/<repo>/`에 clone
  3. **개발 중**에는 straight recipe에 `:local-repo`를 지정해 GitHub 경유 없이 로컬 소스 직접 사용:
     ```elisp
     (use-package <package>
       :straight (<pkg> :type git :host github :repo "user/repo"
                       :local-repo "~/Workspace/contribute/repo"))
     ```
  4. 로컬 수정 후 `M-x straight-rebuild-package RET <package> RET`로 즉시 반영
  5. **배포 시** `:local-repo`를 제거하고 `:branch`로 전환:
     ```elisp
     (use-package <package>
       :straight (<pkg> :type git :host github :repo "user/repo"
                       :branch "feature-branch"))
     ```
  6. commit → push → `straight-pull-package`로 최종 동기화
  - Fork repo 경로: `~/Workspace/contribute/<repo>/`
  - Straight repo 경로: `~/.emacs.d/straight/repos/<package>/`

## MCP Server Configuration

MCP servers are configured in `config/mcp-server-setting.el`. The configuration follows the Model Context Protocol standard and integrates with various tools and services.

## Agent-Specific Notes

### For Claude Code
This repository was originally configured for Claude Code. The `CLAUDE.md` file contains the original guidance. This `AGENTS.md` file consolidates guidance for both Claude Code and OpenCode.

### For OpenCode
- When suggesting changes, consider Emacs Lisp best practices
- All files follow the `(provide '<module-name>)` pattern at the end
- Test changes by evaluating the buffer with `M-x eval-buffer`

## Issue Management on GitHub

이슈 생성/조회/관리를 요청받으면 아래 GitHub 저장소를 사용합니다:

- **Repository**: `lazyskulptor/emacs-settings` (`https://github.com/lazyskulptor/emacs-settings`)
- **CLI**: `gh issue` 명령어 사용
- `config/remote.el` 등 머신별 path 변수의 `properties.el` 이관 작업은 별도 이슈로 추적 중

## Testing Changes

Since this is an Emacs configuration:
1. Make your edits
2. Evaluate the buffer: `M-x eval-buffer` or `C-x C-e` (eval-last-sexp)
3. Or restart Emacs to verify full loading
4. Check `*Messages*` buffer for any errors during startup

## MCP Tool Usage Guidelines

### Emacs MCP Tools (`emacs_*`) vs General Tools

Prefer general-purpose tools over `emacs_eval-elisp` for non-Emacs-specific tasks:

| Priority | Tool | Use For | Avoid |
|---|---|---|---|
| 1 | `bash` (ls, test, cat, head, tail, grep, rg) | File existence checks, simple file reads, process status | Using `eval-elisp` for `(file-exists-p ...)` or `(with-current-buffer ...)` |
| 2 | `read` | Reading file contents (≤1KB, otherwise use bash head/tail) | Using `eval-elisp` to read buffer contents |
| 3 | `glob` / `grep` | File pattern matching, content search | Using `eval-elisp` for directory traversal |
| 4 | `emacs_org-*` | Org file operations (org-get-node, org-search, org-agenda) | Using `eval-elisp` with `with-current-buffer` + `insert` for Org files |
| 5 | `emacs_get_*` | Imenu symbols, diagnostics, project structure | Using `eval-elisp` for `(imenu--make-index-alist)` |
| **6** | **`emacs_eval-elisp`** | **Fallback only: when no dedicated tool exists for the task** | Routine file/buffer/directory operations |

### Rationale
- `eval-elisp` executes arbitrary code in the Emacs process, which can have side effects
- General tools (`bash`, `read`, `glob`) are safer, more predictable, and do not interfere with the running Emacs state
- Use `eval-elisp` only for operations that inherently require Emacs runtime context (e.g., evaluating expressions, inspecting buffer-local variables, testing code changes)

### Batch File Operations
When reading files larger than 1KB, use `bash` with `head`/`tail`/`grep` to extract relevant snippets instead of loading entire files into buffers via Emacs tools.

## Git Workflow

- Do not commit machine-specific files (properties.local.el, sql-connections.el)
- Ensure `.gitignore` is properly configured
- Test changes in a separate Emacs instance before committing
