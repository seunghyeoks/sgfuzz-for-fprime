#!/bin/bash
# 단계 2: 의존성 확인
# SUMMARY.md 전략 반영 - 필수 도구 및 SGFuzz 라이브러리 확인

set -e

# 공통 함수 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 환경 변수 로드
ENV_FILE="${PROJECT_ROOT:-/workspace/sgfuzz-for-fprime}/.fuzz_env"
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
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
# 2.2 SGFuzz 라이브러리 확인
# ===========================================
log_info "SGFuzz 라이브러리 확인 중..."

LIBSFUZZER_PATH="${SGFUZZ_ROOT}/libsfuzzer.a"

if [ ! -f "${LIBSFUZZER_PATH}" ]; then
    log_warning "libsfuzzer.a를 찾을 수 없습니다: ${LIBSFUZZER_PATH}"
    log_info "SGFuzz 빌드를 시작합니다..."
    
    cd "${SGFUZZ_ROOT}"
    
    # build.sh 실행
    if [ ! -f "./build.sh" ]; then
        log_error "SGFuzz 빌드 스크립트를 찾을 수 없습니다: ${SGFUZZ_ROOT}/build.sh"
        exit 1
    fi
    
    chmod +x ./build.sh
    
    log_info "실행: ./build.sh"
    if ! ./build.sh; then
        log_error "SGFuzz 빌드 실패!"
        exit 1
    fi
    
    # 빌드 후 재확인
    if [ ! -f "${LIBSFUZZER_PATH}" ]; then
        log_error "SGFuzz 빌드 후에도 libsfuzzer.a를 찾을 수 없습니다!"
        exit 1
    fi
fi

log_success "SGFuzz 라이브러리 확인 완료: ${LIBSFUZZER_PATH}"

# 라이브러리 정보 출력
if command -v file >/dev/null 2>&1; then
    log_info "libsfuzzer.a 정보:"
    file "${LIBSFUZZER_PATH}"
fi

# ===========================================
# 2.3 SGFuzz 계측 스크립트 확인
# ===========================================
log_info "SGFuzz 계측 스크립트 확인 중..."

INSTRUMENT_SCRIPT="${SGFUZZ_ROOT}/sanitizer/State_machine_instrument.py"
if ! check_file "${INSTRUMENT_SCRIPT}" "State_machine_instrument.py"; then
    log_error "SGFuzz 계측 스크립트를 찾을 수 없습니다!"
    exit 1
fi

# Python 스크립트 실행 권한 확인
chmod +x "${INSTRUMENT_SCRIPT}" || true

log_success "SGFuzz 계측 스크립트 확인 완료"

# ===========================================
# 2.4 F Prime 요구사항 확인
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

