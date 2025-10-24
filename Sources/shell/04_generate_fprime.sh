#!/bin/bash
# 단계 4: F Prime 자동 생성 코드 생성
# SUMMARY.md 전략 단계 5 반영:
#   - fprime-util generate (CMake 메타데이터 및 자동 생성 코드 생성)
#   - 이후 SGFuzz 계측을 위한 준비 단계

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

log_step "4" "F Prime 자동 생성 코드 생성"
start_timer

# ===========================================
# 4.1 F Prime 루트로 이동
# ===========================================
log_info "F Prime 루트 디렉토리로 이동: ${FPRIME_ROOT}"
cd "${FPRIME_ROOT}"

# ===========================================
# 4.2 기존 빌드 디렉토리 정리
# ===========================================
if [ -d "${BUILD_DIR}" ]; then
    log_warning "기존 빌드 디렉토리 발견: ${BUILD_DIR}"
    
    # CLEAN_BUILD 환경 변수로 제어 (기본값: true)
    CLEAN_BUILD="${CLEAN_BUILD:-true}"
    
    if [ "${CLEAN_BUILD}" = "true" ]; then
        log_info "fuzz 타겟 추가로 인한 클린 빌드 필요"
        log_info "기존 빌드 디렉토리 삭제 중..."
        rm -rf "${BUILD_DIR}"
        log_success "빌드 디렉토리 정리 완료"
    else
        log_info "기존 빌드 디렉토리 유지 (CLEAN_BUILD=false)"
        log_warning "⚠️  증분 빌드는 fuzz 타겟의 오토코더 파일을 생성하지 못할 수 있습니다."
    fi
else
    log_info "빌드 디렉토리가 없습니다. 클린 빌드를 수행합니다."
fi

# ===========================================
# 4.3 CMake 메타데이터 생성 (fprime-util generate)
# ===========================================
log_info "CMake 메타데이터 생성 중..."

# CMake에 SGFUZZ_ROOT 경로 명시적 전달
echo "  명령: fprime-util generate -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DSGFUZZ_ROOT=${SGFUZZ_ROOT}"
echo ""

# fprime-util generate 실행
if ! fprime-util generate -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DSGFUZZ_ROOT="${SGFUZZ_ROOT}"; then
    log_error "fprime-util generate 실패!"
    log_error "CMake 메타데이터 생성 중 오류가 발생했습니다."
    log_info ""
    log_info "디버깅 팁:"
    log_info "  1. ${COMPONENT_PATH}/fuzz/CMakeLists.txt 구문 확인"
    log_info "  2. ${COMPONENT_PATH}/CMakeLists.txt에 add_subdirectory(fuzz) 포함 확인"
    exit 1
fi

log_success "CMake 메타데이터 생성 완료"

# 빌드 디렉토리 확인
if ! check_directory "${BUILD_DIR}" "빌드 디렉토리"; then
    log_error "빌드 디렉토리가 생성되지 않았습니다!"
    exit 1
fi

# ===========================================
# 4.4 초기 빌드 (자동 생성 코드 생성을 위해)
# ===========================================
log_info "자동 생성 코드를 생성하기 위한 초기 빌드 중..."
echo "  타겟: ${COMPONENT_NAME}_fuzz"
echo "  명령: fprime-util build --target ${COMPONENT_NAME}_fuzz -j ${N_JOBS}"
echo ""

# 초기 빌드 (자동 생성 파일 생성)
if ! fprime-util build --target "${COMPONENT_NAME}_fuzz" -j "${N_JOBS}"; then
    log_error "초기 빌드 실패!"
    log_error "자동 생성 코드를 생성할 수 없습니다."
    log_info ""
    log_info "디버깅 팁:"
    log_info "  1. 퍼징 타겟이 제대로 설정되었는지 확인"
    log_info "  2. ${COMPONENT_PATH}/fuzz/CMakeLists.txt 확인"
    log_info "  3. 컴포넌트 소스 파일 오류 확인"
    exit 1
fi

log_success "초기 빌드 완료 - 자동 생성 파일이 생성되었습니다"

# ===========================================
# 4.5 자동 생성 코드 확인
# ===========================================
log_info "생성된 자동 생성 파일 확인 중..."

# 자동 생성된 *Ac.hpp 파일 찾기
AUTOGEN_COUNT=$(find "${BUILD_DIR}" -name "*ComponentAc.hpp" 2>/dev/null | wc -l | tr -d ' ')
log_info "발견된 자동 생성 헤더 파일: ${AUTOGEN_COUNT}개"

# CmdDispatcher의 자동 생성 파일 확인
POSSIBLE_AUTOGEN_PATHS=(
    "${BUILD_DIR}/F-Prime/Svc/${COMPONENT_NAME}/fuzz/CommandDispatcherComponentAc.hpp"
    "${BUILD_DIR}/F-Prime/Svc/${COMPONENT_NAME}/CommandDispatcherComponentAc.hpp"
    "${BUILD_DIR}/Svc/${COMPONENT_NAME}/fuzz/CommandDispatcherComponentAc.hpp"
    "${BUILD_DIR}/Svc/${COMPONENT_NAME}/CommandDispatcherComponentAc.hpp"
)

FOUND_AUTOGEN=false
for file in "${POSSIBLE_AUTOGEN_PATHS[@]}"; do
    if [ -f "$file" ]; then
        log_success "✓ 자동 생성 파일 발견: $(basename $file)"
        log_info "  경로: ${file}"
        FOUND_AUTOGEN=true
        break
    fi
done

if [ "$FOUND_AUTOGEN" = false ]; then
    log_warning "표준 경로에서 자동 생성 파일을 찾을 수 없습니다"
    log_info "전체 검색 중..."
    FOUND_FILE=$(find "${BUILD_DIR}" -name "CommandDispatcherComponentAc.hpp" 2>/dev/null | head -n 1)
    if [ -n "$FOUND_FILE" ]; then
        log_success "✓ 자동 생성 파일 발견: ${FOUND_FILE}"
    else
        log_error "자동 생성 파일을 찾을 수 없습니다!"
        log_info "다음 명령으로 수동 검색:"
        log_info "  find ${BUILD_DIR} -name '*ComponentAc.hpp'"
    fi
fi

echo ""
log_success "F Prime 자동 생성 코드 생성 완료!"
echo ""
echo "다음 단계:"
echo "  1. SGFuzz 계측 스크립트 실행 (05_sgfuzz_instrument.sh)"
echo "  2. 자동 생성된 enum 값들에 상태 계측 추가"
echo ""

end_timer "F Prime 자동 생성 코드 생성"


