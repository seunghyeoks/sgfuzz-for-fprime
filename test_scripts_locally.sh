#!/bin/bash
# 로컬에서 스크립트를 순차적으로 테스트하는 도우미 스크립트
# Docker 없이 스크립트 구문 및 로직을 검증하는 용도

set -e

echo "=========================================="
echo "  SGFuzz 스크립트 로컬 테스트"
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_DIR="${SCRIPT_DIR}/Sources/shell"

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# 테스트 모드 환경 변수 설정 (실제 실행은 안 함)
export TEST_MODE=true
export PROJECT_ROOT="${SCRIPT_DIR}"
export FPRIME_ROOT="${PROJECT_ROOT}/fprime"
export SGFUZZ_ROOT="${PROJECT_ROOT}/SGFuzz"
export COMPONENT_NAME="CmdDispatcher"
export FUZZ_OUTPUT="${PROJECT_ROOT}/fuzz_output"

echo "테스트 환경:"
echo "  - PROJECT_ROOT: ${PROJECT_ROOT}"
echo "  - SHELL_DIR: ${SHELL_DIR}"
echo ""

# ====================================
# 테스트 1: 스크립트 파일 존재 확인
# ====================================
log_test "스크립트 파일 존재 확인..."

SCRIPTS=(
    "common.sh"
    "01_setup_environment.sh"
    "02_check_dependencies.sh"
    "03_setup_fuzz_target.sh"
    "04_build_fprime.sh"
    "05_run_fuzzer.sh"
    "entrypoint.sh"
)

ALL_EXISTS=true
for script in "${SCRIPTS[@]}"; do
    if [ -f "${SHELL_DIR}/${script}" ]; then
        log_pass "${script} 존재 확인"
    else
        log_fail "${script} 파일이 없습니다!"
        ALL_EXISTS=false
    fi
done

if [ "${ALL_EXISTS}" = false ]; then
    exit 1
fi

echo ""

# ====================================
# 테스트 2: 스크립트 구문 검사 (bash -n)
# ====================================
log_test "스크립트 구문 검사..."

SYNTAX_OK=true
for script in "${SCRIPTS[@]}"; do
    if bash -n "${SHELL_DIR}/${script}" 2>/dev/null; then
        log_pass "${script} 구문 정상"
    else
        log_fail "${script} 구문 오류!"
        bash -n "${SHELL_DIR}/${script}"
        SYNTAX_OK=false
    fi
done

if [ "${SYNTAX_OK}" = false ]; then
    exit 1
fi

echo ""

# ====================================
# 테스트 3: 실행 권한 확인
# ====================================
log_test "실행 권한 확인..."

PERMS_OK=true
for script in "${SCRIPTS[@]}"; do
    if [ -x "${SHELL_DIR}/${script}" ]; then
        log_pass "${script} 실행 가능"
    else
        log_fail "${script} 실행 권한 없음 (chmod +x 필요)"
        PERMS_OK=false
    fi
done

if [ "${PERMS_OK}" = false ]; then
    echo ""
    echo "다음 명령으로 실행 권한을 부여하세요:"
    echo "  chmod +x Sources/shell/*.sh"
    exit 1
fi

echo ""

# ====================================
# 테스트 4: common.sh 함수 로드 테스트
# ====================================
log_test "common.sh 함수 로드 테스트..."

if source "${SHELL_DIR}/common.sh" 2>/dev/null; then
    log_pass "common.sh 로드 성공"
    
    # 주요 함수 존재 확인
    FUNCTIONS=(
        "log_info"
        "log_success"
        "log_warning"
        "log_error"
        "check_command"
        "check_file"
        "check_directory"
    )
    
    FUNCTIONS_OK=true
    for func in "${FUNCTIONS[@]}"; do
        if declare -f "$func" > /dev/null; then
            log_pass "  - 함수 ${func} 정의됨"
        else
            log_fail "  - 함수 ${func} 정의 안 됨!"
            FUNCTIONS_OK=false
        fi
    done
    
    if [ "${FUNCTIONS_OK}" = false ]; then
        exit 1
    fi
else
    log_fail "common.sh 로드 실패!"
    exit 1
fi

echo ""

# ====================================
# 테스트 5: 환경 변수 설정 스크립트 실행 (dry-run)
# ====================================
log_test "01_setup_environment.sh 실행 테스트..."

if bash -c "source ${SHELL_DIR}/01_setup_environment.sh 2>&1 | head -n 20"; then
    log_pass "환경 변수 설정 스크립트 실행 성공"
else
    log_fail "환경 변수 설정 스크립트 실행 실패!"
    exit 1
fi

echo ""

# ====================================
# 최종 결과
# ====================================
echo "=========================================="
echo -e "${GREEN}✅ 모든 테스트 통과!${NC}"
echo "=========================================="
echo ""
echo "스크립트가 정상적으로 구성되었습니다."
echo "다음 단계:"
echo "  1. 로컬에서 전체 실행: source Sources/shell/entrypoint.sh"
echo "  2. Docker로 실행: cd Sources/docker && docker-compose up --build"
echo ""

