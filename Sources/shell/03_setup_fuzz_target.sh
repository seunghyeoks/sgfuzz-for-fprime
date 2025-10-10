#!/bin/bash
# 단계 3: 퍼징 타겟 설정
# SUMMARY.md 전략 단계 1-4 반영:
#   1. 퍼징 타겟 등록 (CMake)
#   2. 소스 복사 + 계측 자동화
#   3. 헤더 및 라이브러리 설정
#   4. 모듈 내부 조건부 포함

set -e

# 공통 함수 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 환경 변수 로드
ENV_FILE="${PROJECT_ROOT:-/workspace/sgfuzz-for-fprime}/.fuzz_env"
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi

log_step "3" "퍼징 타겟 설정"
start_timer

# ===========================================
# 3.1 컴포넌트 경로 확인
# ===========================================
log_info "타겟 컴포넌트 경로 확인 중..."

if ! check_directory "${COMPONENT_PATH}" "컴포넌트 경로"; then
    log_error "컴포넌트를 찾을 수 없습니다: ${COMPONENT_NAME}"
    log_info "경로를 확인하세요: ${COMPONENT_PATH}"
    exit 1
fi

log_success "컴포넌트 확인: ${COMPONENT_NAME}"
echo "  경로: ${COMPONENT_PATH}"

# ===========================================
# 3.2 기존 fuzz 디렉토리 정리
# ===========================================
FUZZ_DIR="${COMPONENT_PATH}/fuzz"

if [ -d "${FUZZ_DIR}" ]; then
    log_warning "fuzz 디렉토리가 이미 존재합니다: ${FUZZ_DIR}"
    log_info "강제 재생성을 위해 기존 디렉토리를 삭제합니다..."
    rm -rf "${FUZZ_DIR}"
    log_success "기존 fuzz 디렉토리 삭제 완료"
fi

# ===========================================
# 3.3 퍼징 타겟 자동 생성 스크립트 실행
# ===========================================
log_info "setup_fuzz_target.py 실행 중..."

SETUP_SCRIPT="${PROJECT_ROOT}/scripts/setup_fuzz_target.py"

if ! check_file "${SETUP_SCRIPT}" "퍼징 타겟 생성 스크립트"; then
    log_error "setup_fuzz_target.py를 찾을 수 없습니다!"
    exit 1
fi

cd "${PROJECT_ROOT}"

# Python 스크립트 실행 (--force 옵션으로 강제 생성)
log_info "명령: python3 ${SETUP_SCRIPT} --component ${COMPONENT_NAME} --force"

if ! python3 "${SETUP_SCRIPT}" --component "${COMPONENT_NAME}" --force; then
    log_error "퍼징 타겟 생성 실패!"
    log_error "setup_fuzz_target.py 실행 중 오류가 발생했습니다."
    exit 1
fi

log_success "퍼징 타겟 생성 완료"

# ===========================================
# 3.4 생성된 파일 검증
# ===========================================
log_info "생성된 파일 검증 중..."

EXPECTED_FILES=(
    "${FUZZ_DIR}/CMakeLists.txt"
    "${FUZZ_DIR}/${COMPONENT_NAME}_fuzz.cpp"
    "${FUZZ_DIR}/README.md"
)

ALL_FILES_OK=true
for file in "${EXPECTED_FILES[@]}"; do
    if [ -f "$file" ]; then
        log_success "✓ $(basename $file)"
    else
        log_error "✗ $(basename $file) - 파일이 생성되지 않았습니다!"
        ALL_FILES_OK=false
    fi
done

if [ "${ALL_FILES_OK}" = false ]; then
    log_error "일부 파일이 생성되지 않았습니다."
    exit 1
fi

# ===========================================
# 3.5 상위 CMakeLists.txt 확인
# ===========================================
log_info "상위 CMakeLists.txt 확인 중..."

PARENT_CMAKE="${COMPONENT_PATH}/CMakeLists.txt"

if ! check_file "${PARENT_CMAKE}" "상위 CMakeLists.txt"; then
    log_error "상위 CMakeLists.txt를 찾을 수 없습니다!"
    exit 1
fi

# add_subdirectory(fuzz) 포함 여부 확인
if grep -q "add_subdirectory(fuzz)" "${PARENT_CMAKE}"; then
    log_success "add_subdirectory(fuzz)가 상위 CMakeLists.txt에 포함되어 있습니다"
else
    log_warning "add_subdirectory(fuzz)가 상위 CMakeLists.txt에 없습니다"
    log_info "setup_fuzz_target.py가 자동으로 추가했어야 합니다. 수동 확인 필요."
fi

# ===========================================
# 3.6 퍼징 타겟 설정 요약
# ===========================================
echo ""
log_success "퍼징 타겟 설정 완료!"
echo ""
echo "생성된 파일:"
echo "  - ${FUZZ_DIR}/CMakeLists.txt"
echo "  - ${FUZZ_DIR}/${COMPONENT_NAME}_fuzz.cpp"
echo "  - ${FUZZ_DIR}/README.md"
echo ""
echo "다음 단계:"
echo "  1. ${COMPONENT_NAME}_fuzz.cpp 파일에서 실제 퍼징 로직 구현 (필요 시)"
echo "  2. fprime-util generate 실행"
echo "  3. fprime-util build --target ${COMPONENT_NAME}_fuzz 실행"
echo ""

end_timer "퍼징 타겟 설정"

