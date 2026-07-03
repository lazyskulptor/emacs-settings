# Emacs 트러블슈팅

현재 해결 중이거나 관찰 중인 문제들. 관련 문제가 발견되면 이 문서에 추가하고 상호 영향도를 확인하세요.

---

## 1. TRAMP eshell 관련 문제들 (공통 원인)

### 상태: 🔍 디버깅 중 - 추가 로그 수집 필요

### 공통 근본 원인

**커밋 6a77e9c** (2026-06-10)에서 추가된 `remote.el`의 두 가지 설계 문제:

1. **`exec-path`를 원격 경로로 설정**
   - 원래 의도: 원격 PATH를 Emacs의 `exec-path`에 동기화하여 원격 명령 검색
   - 실제 결과: `exec-path`가 로컬에서 해석되어 파이프 에러 발생

2. **상태 복원 로직이 불완전**
   - `my-original-*` 변수가 nil이면 복원이 안 됨
   - 원격 관련 변수들이 초기화되지 않음

### 변수별 용도와 문제

| 변수 | 용도 | 원격 설정 시 문제 |
|------|------|-------------------|
| `tramp-remote-path` | TRAMP가 원격 명령 검색 | ✅ 정상 작동 |
| `exec-path` | 로컬 명령 검색 | ❌ 원격 경로가 로컬로 해석됨 |

### 증상 목록

| # | 증상 | 발생 시점 | 관련 코드 |
|---|------|-----------|-----------|
| 1-1 | 파이프 명령 에러: `sh: ~/.cache/emacs/ssh: No such file` | TRAMP 환경 | `my/tramp-eshell-load-remote-env` line 430-432 |
| 1-2 | 자동완성 실패: kubectl, docker 자동완성 안 됨 | TRAMP 환경 | bash-completion이 잘못된 `exec-path` 참조 |
| 1-3 | 로컬 복원 후 자동완성 실패 | TRAMP→로컬 | `my-original-exec-path`가 nil이라 복원 안 됨 |
| 1-4 | 로컬에서 `~`가 TRAMP 루트로 이동 | TRAMP→로컬 | 원격 상태 변수들이 초기화되지 않음 |

### 재현 방법

**문제 1-1, 1-2:**
1. TRAMP로 원격 서버 연결: `C-x C-f /ssh:user@host:/RET`
2. eshell 열기
3. 파이프 명령 실행: `ll | grep BE` 또는 `ps -ef | grep java`
4. kubectl, docker 자동완성 시도

**문제 1-3, 1-4:**
1. TRAMP eshell에서 로컬 경로로 변경: `cd /local/path`
2. kubectl, docker 자동완성 시도 (문제 1-3)
3. `cd ~` 실행 (문제 1-4)

### 관련 코드 위치

- `/Users/hyeonjunpark/.emacs.d/config/remote.el`
  - `my/tramp-eshell-update-env` (line 342-362)
  - `my/tramp-eshell-load-remote-env` (line 375-440)
  - 특히 line 429-432: `exec-path` 설정 부분

### 해결 계획

**`exec-path`를 원격 경로로 설정하지 않음** + **상태 복원 로직 개선** + **`eshell-search-path` advice 수정**

#### 변경 1: `my/tramp-eshell-update-env` 함수 수정

```elisp
(defun my/tramp-eshell-update-env ()
  "디렉토리 변경 시 환경변수를 적절히 업데이트."
  (if (file-remote-p default-directory)
      (when (and my-remote-env-vars my-remote-path-cache)
        ;; exec-path는 로컬 유지, tramp-remote-path만 설정
        (setq-local tramp-remote-path (split-string my-remote-path-cache ":"))
        (setq-local process-environment
                    (my/tramp-apply-env-vars my-remote-env-vars
                                             my-original-process-environment))
        (when my/tramp-remote-env-debug
          (message "[tramp-env] 원격 환경변수로 설정: %s" default-directory)))
    ;; 로컬로 돌아왔을 때 완전한 초기화
    (setq-local exec-path (or my-original-exec-path exec-path))
    (setq-local process-environment 
                (or my-original-process-environment process-environment))
    (setq-local eshell-variable-aliases-list 
                (or my-original-eshell-variable-aliases-list eshell-variable-aliases-list))
    ;; 원격 관련 변수 초기화
    (setq-local my-remote-env-vars nil)
    (setq-local my-remote-path-cache nil)
    (setq-local my--tramp-env-loaded-p nil)
    (when my/tramp-remote-env-debug
      (message "[tramp-env] 로컬 환경변수로 복원 및 초기화 완료"))))
```

#### 변경 2: `my/tramp-eshell-load-remote-env` 함수 수정

```elisp
;; 기존 코드 (line 429-432, 삭제):
;; (setq-local exec-path
;;             (mapcar (lambda (p) (concat rid p))
;;                     (split-string remote-path ":")))

;; 새 코드: tramp-remote-path만 설정
(setq-local tramp-remote-path (split-string remote-path ":"))
```

#### 변경 3: `my/tramp-eshell-search-path` advice 수정

```elisp
(defun my/tramp-eshell-search-path (orig-fun command)
  "TRAMP 환경에서 eshell-search-path를 개선.
TRAMP 환경에서는 tramp-remote-path를 사용하여 원격 명령을 검색합니다."
  (or (funcall orig-fun command)
      (when (file-remote-p default-directory)
        ;; TRAMP 환경에서는 tramp-remote-path를 사용하여 명령 검색
        (let* ((remote-id (file-remote-p default-directory))
               (remote-paths (or tramp-remote-path
                                 (split-string my-remote-path-cache ":" t)))
               (remote-cmd (locate-file command
                                        (mapcar (lambda (p) (concat remote-id p))
                                                remote-paths)
                                        exec-suffixes)))
          (when (and remote-cmd (file-executable-p remote-cmd))
            remote-cmd)))))
```

### 왜 이 해결책이 올바른가

1. **bash-completion은 영향받지 않음**
   - `bash-completion-remote-prog` = "bash" (기본값)
   - `start-file-process` 사용하여 TRAMP 경유로 원격 bash 실행
   - `exec-path`와 무관하게 작동

2. **TRAMP 명령 검색은 정상 작동**
   - `tramp-remote-path`가 원격 명령 검색 담당
   - eshell이 원격 명령 실행 시 TRAMP 메커니즘 사용

3. **파이프 명령 정상 작동**
   - `exec-path`가 로컬 유지되므로 로컬에서 파이프 실행 가능

### 테스트 체크리스트

- [ ] TRAMP 연결 후 `ll | grep BE` 정상 작동
- [ ] TRAMP 연결 후 `ps -ef | grep java` 정상 작동
- [ ] TRAMP 연결 후 `kubectl get pods` 정상 작동
- [ ] TRAMP 연결 후 kubectl 자동완성 정상 작동
- [ ] TRAMP→로컬 전환 후 kubectl 자동완성 정상 작동
- [ ] TRAMP→로컬 전환 후 `cd ~`가 로컬 홈으로 이동
- [ ] 로컬 eshell에서 모든 명령 정상 작동
- [ ] 로컬 eshell에서 자동완성 정상 작동
- [ ] TRAMP 연결 후 파일 편집 정상 작동
- [ ] TRAMP 연결 후 `M-x grep` 정상 작동

### 참고 자료
- TRAMP 문서: `C-h i g (tramp) RET`
- eshell 문서: `C-h i g (eshell) RET`
- bash-completion TRAMP 처리: `bash-completion.el` line 1163-1235
- 관련 변수: `tramp-remote-path`, `exec-path`, `process-environment`

---

## 2. (다음 문제 추가 공간)
