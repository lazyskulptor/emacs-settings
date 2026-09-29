;; Common environment variables (non-sensitive, machine-agnostic)

(let ((local-bin (expand-file-name "~/.local/bin")))
  (setenv "PATH" (concat local-bin ":" (getenv "PATH")))
  (add-to-list 'exec-path local-bin))
;; NOTE: .emacs.d/.venv/bin과 .emacs.d/node_modules/.bin은 여기서 등록하지 않음.
;; interface.el의 exec-path-from-shell이 PATH를 login shell 환경으로 덮어씀.
;; 대신 lsp-bridge.el의 idle-timer bootstrap이 추가함 (exec-path-from-shell 이후 실행).

(setenv "LANG" "ko_KR.UTF-8")
(setenv "LC_ALL" "ko_KR.UTF-8")
(setenv "LSP_USE_PLISTS" "true")
(setenv "TERM" "xterm-256color")

;; Default values — overridden in properties.local.el (gitignored).
;;
;; ─────────────────────────────────────────────────────────────
;; 새 머신 설정 가이드
;; ─────────────────────────────────────────────────────────────
;;
;; 1. ~/.emacs.d/properties.local.el 파일을 생성하세요:
;;
;;    (setq
;;     ;; Clojure LSP (Homebrew 설치 시)
;;     clojure-lsp-path    "/opt/homebrew/Cellar/clojure-lsp-native/<version>/bin/clojure-lsp"
;;
;;     ;; Java Lombok JAR 경로 (JDT.LS javaagent용)
;;     java-lombok-path    "~/.emacs.d/.cache/lsp/lombok.jar"
;;
;;     ;; JDK 경로들 (버전별)
;;     java-home-21        "/Library/Java/JavaVirtualMachines/jdk-21.x.x/Contents/Home"
;;     java-home-17        "/Library/Java/JavaVirtualMachines/jdk-17.x.x/Contents/Home"
;;     java-home-11        "/Library/Java/JavaVirtualMachines/jdk-11.x.x/Contents/Home"
;;
;;     ;; Flutter/Dart SDK (FVM 사용 시)
;;     global-flutter-sdk-dir "/Users/<username>/fvm/default"
;;     global-dart-sdk-dir    "/Users/<username>/fvm/default/bin/cache/dart-sdk"
;;
;;     ;; .NET SDK 경로 (dotnet --list-sdks로 확인)
;;     dotnet-sdk-dir       "/usr/local/share/dotnet"
;;
;;     ;; Wiki 파일 경로 (journal.org, roam/ 등)
;;     wiki-dir             "~/Workspace/wiki/"
;;     wiki-archive-dir     "~/Workspace/wiki/.archive/")
;;
;; 2. 선택사항: SQL 연결 정보 (~/.emacs.d/config/sql-connections.el)
;;    이 파일이 있으면 ejc-sql 패키지에서 DB 연결을 로드합니다.
;;    없어도 Emacs는 정상 작동하지만, SQL 기능 사용 시 수동 연결 필요.
;;
;;    예시:
;;    (setq sql-connection-alist
;;          '(("mydb"
;;             (sql-product 'postgres)
;;             (sql-server "localhost")
;;             (sql-user "user")
;;             (sql-password "password")
;;             (sql-database "dbname"))))
;;    (provide 'sql-connections)
;;
;; ─────────────────────────────────────────────────────────────
(setq
 clojure-lsp-path    ""
 java-lombok-path    ""
 java-home-21        ""
 java-home-17        ""
 java-home-11        ""
  global-flutter-sdk-dir ""
  global-dart-sdk-dir    ""
  dotnet-sdk-dir         ""
  wiki-dir             "~/Workspace/wiki/"
  wiki-archive-dir     "~/Workspace/wiki/.archive/"
  opencode-shell-local-path nil
  ;; OpenCode profiles default to nil.  properties.local.el may set a list of
  ;; plists; remote profiles use one TRAMP-home :directory, local profiles omit it.
  opencode-shell-profiles nil

 ;; 메일 계정/다이제스트 — properties.local.el에서 실제 값 설정
 ;; mail-accounts: ((label "display-name" "addr") ...)
 ;; mail-digest-senders: 자동 요약할 발신자 이메일 주소 목록
 mail-accounts       nil
 mail-digest-senders nil

 ;; notmuch elisp 경로 (Homebrew: /opt/homebrew/share/emacs/site-lisp/notmuch)
 notmuch-site-lisp-dir nil

 ;; Org ditaa 다이어그램 블록용 JAR/실행파일 경로
 ditaa-jar-path  nil
 ditaa-exec-path nil

 ;; Fork 개발 모드 경로 — 설정 시 :local-repo 사용, nil이면 :branch(배포용) 사용
 mcp-server-local-repo            nil

 ;; aider(saider) 바이너리 경로
 saider-path "~/.local/bin/saider"

 ;; Slack 인증 정보 — properties.local.el에서만 실제 값 설정
 slack-team-name nil
 slack-token     nil
 slack-cookie    nil)

;; Load machine-specific overrides (gitignored)
(let ((local (expand-file-name "~/.emacs.d/properties.local.el")))
  (when (file-exists-p local)
    (load local)))

;; DOTNET_ROOT: properties.local.el의 dotnet-sdk-dir 값으로 설정
(when (and (boundp 'dotnet-sdk-dir)
           (not (string-empty-p dotnet-sdk-dir)))
  (setenv "DOTNET_ROOT" dotnet-sdk-dir))
