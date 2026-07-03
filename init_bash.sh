# ~/.emacs.d/init_bash.sh
# bash-completion Emacs 패키지가 자동으로 로드하는 파일
# bash-completion 기본 유틸리티와 명령어 completion을 로드

# 1. bash-completion 기본 유틸리티 로드 (_get_comp_words_by_ref 등)
# 에러가 발생해도 계속 진행
source /opt/homebrew/etc/bash_completion 2>/dev/null || true

# bash-completion Emacs 패키지가 확인하는 환경변수 수동 설정
# /opt/homebrew/etc/bash_completion이 이 변수를 설정하지 않으므로 수동으로 설정
if [ -z "${BASH_COMPLETION_VERSINFO[*]}" ]; then
    export BASH_COMPLETION_VERSINFO="2.11"
fi

# 2. 명령어별 completion 로드 (캐시된 파일 사용)
if command -v kubectl &> /dev/null && [ -f ~/.kubectl_completion.bash ]; then
    source ~/.kubectl_completion.bash 2>/dev/null || true
    
    # eshell alias 'k'를 위한 wrapper 함수
    # COMP_WORDS[0]를 'k'에서 'kubectl'로 변환하여 completion 작동
    __start_k() {
        local saved_word0="${COMP_WORDS[0]}"
        COMP_WORDS[0]="kubectl"
        __start_kubectl "$@"
        COMP_WORDS[0]="$saved_word0"
    }
    complete -o default -F __start_k k
fi

if command -v docker &> /dev/null && [ -f ~/.docker_completion.bash ]; then
    source ~/.docker_completion.bash 2>/dev/null || true
fi

if command -v helm &> /dev/null && [ -f ~/.helm_completion.bash ]; then
    source ~/.helm_completion.bash 2>/dev/null || true
fi

# 3. aws completion (process completion 방식)
if command -v aws &> /dev/null; then
    complete -C '/opt/homebrew/bin/aws_completer' aws
fi
