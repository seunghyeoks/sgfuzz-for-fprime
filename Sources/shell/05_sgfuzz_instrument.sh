#!/bin/bash
# 단계 5: SGFuzz 자동 계측
# SUMMARY.md 전략 단계 6 반영:
#   - SGFuzz의 State_machine_instrument.py 실행
#   - 자동 생성된 enum 값들에 __sfuzzer_instrument() 호출 추가
#   - 상태 기반 퍼징을 위한 계측 적용

set -e

# 공통 함수 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 컨테이너 환경 확인
if [ ! -d "/workspace/sgfuzz-for-fprime" ]; then
    log_error "컨테이너 환경이 아닙니다!"
    log_error "이 스크립트는 Docker 컨테이너 내부에서만 실행되어야 합니다."
    exit 1
fi

# 환경 변수 로드
ENV_FILE="/workspace/sgfuzz-for-fprime/.fuzz_env"
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi

log_step "5" "SGFuzz 자동 계측"
start_timer

# ===========================================
# 5.1 SGFuzz 계측 스크립트 확인
# ===========================================
INSTRUMENT_SCRIPT="${SGFUZZ_ROOT}/sanitizer/State_machine_instrument.py"

log_info "SGFuzz 계측 스크립트 확인 중..."
if ! check_file "${INSTRUMENT_SCRIPT}" "State_machine_instrument.py"; then
    log_error "SGFuzz 계측 스크립트를 찾을 수 없습니다!"
    log_error "경로: ${INSTRUMENT_SCRIPT}"
    exit 1
fi

log_success "계측 스크립트 확인됨: ${INSTRUMENT_SCRIPT}"

# ===========================================
# 5.2 계측 대상 디렉토리 확인
# ===========================================
log_info "계측 대상 디렉토리 확인 중..."

# 자동 생성된 코드가 있는 빌드 디렉토리
TARGET_DIR="${BUILD_DIR}/fprime/Svc/${COMPONENT_NAME}"

if ! check_directory "${TARGET_DIR}" "계측 대상 디렉토리"; then
    log_warning "표준 경로에서 자동 생성 코드를 찾을 수 없습니다: ${TARGET_DIR}"
    log_info "전체 빌드 디렉토리에서 검색 중..."
    
    # 대안 경로 찾기
    ALT_TARGET=$(find "${BUILD_DIR}" -type d -name "${COMPONENT_NAME}" 2>/dev/null | head -n 1)
    if [ -n "${ALT_TARGET}" ] && [ -d "${ALT_TARGET}" ]; then
        TARGET_DIR="${ALT_TARGET}"
        log_info "발견된 경로: ${TARGET_DIR}"
    else
        log_error "자동 생성 코드 디렉토리를 찾을 수 없습니다!"
        exit 1
    fi
fi

log_success "계측 대상 디렉토리: ${TARGET_DIR}"

# ===========================================
# 5.3 blocked variables 파일 준비 (선택사항)
# ===========================================
BLOCKED_VARS_FILE="${PROJECT_ROOT}/blocked_variables.txt"

if [ -f "${BLOCKED_VARS_FILE}" ]; then
    log_info "Blocked variables 파일 발견: ${BLOCKED_VARS_FILE}"
    BLOCKED_VARS_ARG="-b ${BLOCKED_VARS_FILE}"
else
    log_info "Blocked variables 파일 없음 (선택사항)"
    log_info "모든 enum 변수가 계측됩니다."
    BLOCKED_VARS_ARG=""
fi

# ===========================================
# 5.4 SGFuzz 계측 실행
# ===========================================
log_info "SGFuzz 계측 실행 중..."
echo "  대상 디렉토리: ${TARGET_DIR}"
echo "  계측 스크립트: ${INSTRUMENT_SCRIPT}"
echo ""

# 계측 전 파일 수 확인
BEFORE_COUNT=$(find "${TARGET_DIR}" -type f \( -name "*.cpp" -o -name "*.hpp" \) 2>/dev/null | wc -l | tr -d ' ')
log_info "계측 대상 파일 수: ${BEFORE_COUNT}개"

# Python 스크립트 실행
if ! python3 "${INSTRUMENT_SCRIPT}" "${TARGET_DIR}" ${BLOCKED_VARS_ARG}; then
    log_error "SGFuzz 계측 실패!"
    log_error "State_machine_instrument.py 실행 중 오류가 발생했습니다."
    exit 1
fi

log_success "SGFuzz 계측 완료!"

# ===========================================
# 5.5 계측 결과 확인
# ===========================================
log_info "계측 결과 확인 중..."

# __sfuzzer_instrument 호출이 추가된 파일 찾기
INSTRUMENTED_FILES=$(grep -r "__sfuzzer_instrument" "${TARGET_DIR}" 2>/dev/null | cut -d: -f1 | sort -u | wc -l | tr -d ' ')

if [ "${INSTRUMENTED_FILES}" -gt 0 ]; then
    log_success "계측된 파일 수: ${INSTRUMENTED_FILES}개"
    
    # 계측 포인트 수 세기
    INSTRUMENT_COUNT=$(grep -r "__sfuzzer_instrument" "${TARGET_DIR}" 2>/dev/null | wc -l | tr -d ' ')
    log_info "총 계측 포인트: ${INSTRUMENT_COUNT}개"
    
    # 계측된 파일 샘플 출력
    log_info "계측된 파일 샘플 (최대 5개):"
    grep -r "__sfuzzer_instrument" "${TARGET_DIR}" 2>/dev/null | cut -d: -f1 | sort -u | head -n 5 | while read file; do
        echo "  - $(basename $file)"
    done
else
    log_warning "계측된 파일이 없습니다!"
    log_warning "enum 변수가 자동 생성 코드에 없거나, 계측 스크립트가 제대로 실행되지 않았을 수 있습니다."
fi

# ===========================================
# 5.6 원본 소스 코드 계측 (선택사항)
# ===========================================
log_info "원본 소스 코드 계측 확인 중..."

# CmdDispatcher 원본 소스에도 계측 적용 여부 확인
INSTRUMENT_ORIGINAL="${INSTRUMENT_ORIGINAL:-true}"

if [ "${INSTRUMENT_ORIGINAL}" = "true" ]; then
    log_info "원본 소스 코드에도 계측 적용 중..."
    
    if python3 "${INSTRUMENT_SCRIPT}" "${COMPONENT_PATH}" ${BLOCKED_VARS_ARG}; then
        log_success "원본 소스 코드 계측 완료"
    else
        log_warning "원본 소스 코드 계측 실패 (선택사항이므로 계속 진행)"
    fi
else
    log_info "원본 소스 코드 계측 건너뜀 (INSTRUMENT_ORIGINAL=false)"
fi

echo ""
log_success "SGFuzz 계측 완료!"
echo ""
echo "계측 결과:"
echo "  - 계측된 파일: ${INSTRUMENTED_FILES}개"
echo "  - 계측 포인트: ${INSTRUMENT_COUNT}개"
echo ""
echo "다음 단계:"
echo "  1. F Prime 빌드 (06_build_fprime.sh)"
echo "  2. 계측된 코드로 퍼저 실행 파일 생성"
echo ""

end_timer "SGFuzz 계측"


