#!/bin/bash
# 공통 함수 및 유틸리티
# 모든 단계별 스크립트에서 source로 불러와서 사용

# 색상 코드 정의
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${MAGENTA}[STEP $1]${NC} $2"
    echo "=========================================="
}

# 배너 출력
print_banner() {
    echo ""
    echo "=========================================="
    echo "  SGFuzz for F Prime - Auto Fuzzer"
    echo "  Target: ${COMPONENT_NAME:-CmdDispatcher}"
    echo "=========================================="
    echo ""
}

# 시간 측정 시작
start_timer() {
    TIMER_START=$(date +%s)
}

# 시간 측정 종료 및 출력
end_timer() {
    local step_name="$1"
    TIMER_END=$(date +%s)
    TIMER_DIFF=$((TIMER_END - TIMER_START))
    log_info "${step_name} 소요 시간: ${TIMER_DIFF}초"
}

# 디렉토리 존재 확인
check_directory() {
    local dir="$1"
    local desc="$2"
    
    if [ ! -d "$dir" ]; then
        log_error "${desc} 디렉토리가 없습니다: $dir"
        return 1
    fi
    return 0
}

# 파일 존재 확인
check_file() {
    local file="$1"
    local desc="$2"
    
    if [ ! -f "$file" ]; then
        log_error "${desc} 파일이 없습니다: $file"
        return 1
    fi
    return 0
}

# 명령어 존재 확인
check_command() {
    local cmd="$1"
    local desc="$2"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "${desc} 명령어를 찾을 수 없습니다: $cmd"
        return 1
    fi
    log_success "${desc} 확인: $(command -v $cmd)"
    return 0
}

# 단계 실패 시 처리
handle_step_failure() {
    local step_num="$1"
    local step_name="$2"
    
    log_error "단계 ${step_num} 실패: ${step_name}"
    log_error "퍼징 파이프라인을 중단합니다."
    exit 1
}

# 환경 변수 출력
print_env_summary() {
    echo ""
    log_info "환경 변수 요약:"
    echo "  - PROJECT_ROOT: ${PROJECT_ROOT}"
    echo "  - FPRIME_ROOT: ${FPRIME_ROOT}"
    echo "  - SGFUZZ_ROOT: ${SGFUZZ_ROOT}"
    echo "  - COMPONENT_NAME: ${COMPONENT_NAME}"
    echo "  - COMPONENT_PATH: ${COMPONENT_PATH}"
    echo "  - BUILD_DIR: ${BUILD_DIR}"
    echo "  - FUZZ_OUTPUT: ${FUZZ_OUTPUT}"
    echo "  - BUILD_TYPE: ${BUILD_TYPE}"
    echo "  - CC: ${CC}"
    echo "  - CXX: ${CXX}"
    echo "  - N_JOBS: ${N_JOBS}"
    echo ""
}

