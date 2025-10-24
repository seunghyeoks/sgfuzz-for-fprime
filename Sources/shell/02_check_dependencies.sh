#!/bin/bash
# 단계 2: 의존성 확인
# SUMMARY.md 전략 반영 - 필수 도구 및 SGFuzz 라이브러리 확인

set -e

# 공통 함수 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 환경 변수 로드 (먼저 로드해서 PROJECT_ROOT 사용)
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/workspace/sgfuzz-for-fprime}"
ENV_FILE="${WORKSPACE_ROOT}/.fuzz_env"

if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi

# 컨테이너 환경 확인
if [ ! -d "${PROJECT_ROOT}" ]; then
    log_error "프로젝트 루트를 찾을 수 없습니다: ${PROJECT_ROOT}"
    log_error "이 스크립트는 Docker 컨테이너 내부에서만 실행되어야 합니다."
    exit 1
fi

log_step "2" "의존성 확인"
start_timer

# ===========================================
# 2.1 필수 도구 확인
# ===========================================
log_info "필수 도구 확인 중..."

TOOLS_OK=true

# F Prime 도구
if ! check_command "fprime-util" "fprime-util"; then
    TOOLS_OK=false
fi

# Python 3
if ! check_command "python3" "Python 3"; then
    TOOLS_OK=false
fi

# Clang 컴파일러
if ! check_command "clang" "Clang"; then
    log_warning "Clang이 설치되어 있지 않습니다. SGFuzz는 Clang 필요!"
    TOOLS_OK=false
fi

if ! check_command "clang++" "Clang++"; then
    log_warning "Clang++이 설치되어 있지 않습니다."
    TOOLS_OK=false
fi

# CMake
if ! check_command "cmake" "CMake"; then
    TOOLS_OK=false
fi

# Git
if ! check_command "git" "Git"; then
    TOOLS_OK=false
fi

if [ "${TOOLS_OK}" = false ]; then
    log_error "필수 도구가 누락되었습니다. 설치 후 재시도하세요."
    exit 1
fi

log_success "모든 필수 도구 확인 완료"


# ===========================================
# 2.2 F Prime 요구사항 확인
# ===========================================
log_info "F Prime 요구사항 확인 중..."

FPRIME_REQUIREMENTS="${FPRIME_ROOT}/requirements.txt"
if [ -f "${FPRIME_REQUIREMENTS}" ]; then
    log_info "F Prime requirements.txt 발견, 패키지 확인 중..."
    
    # pip로 설치 여부 확인 (간단하게 fprime-gds만 체크)
    if python3 -c "import fprime_gds" 2>/dev/null; then
        log_success "fprime-gds 패키지 설치됨"
    else
        log_warning "fprime-gds가 설치되지 않았습니다."
        log_info "설치 명령: pip3 install -r ${FPRIME_REQUIREMENTS}"
    fi
else
    log_warning "F Prime requirements.txt를 찾을 수 없습니다."
fi

log_success "의존성 확인 완료"
end_timer "의존성 확인"

