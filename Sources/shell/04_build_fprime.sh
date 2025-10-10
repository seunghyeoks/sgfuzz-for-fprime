#!/bin/bash
# 단계 4: F Prime 빌드
# SUMMARY.md 전략 단계 5 반영:
#   - fprime-util generate (CMake 메타데이터 생성)
#   - fprime-util build --target <component>_fuzz (퍼징 타겟 빌드)

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

log_step "4" "F Prime 프로젝트 빌드"
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

# SGFUZZ_ROOT 경로 확인 및 검증
log_info "SGFuzz 경로 확인: ${SGFUZZ_ROOT}"
if ! check_file "${SGFUZZ_ROOT}/libsfuzzer.a" "libsfuzzer.a"; then
    log_error "libsfuzzer.a를 찾을 수 없습니다!"
    log_error "경로: ${SGFUZZ_ROOT}/libsfuzzer.a"
    log_info ""
    log_info "SGFuzz 빌드 확인:"
    log_info "  cd ${SGFUZZ_ROOT}"
    log_info "  ./build.sh"
    exit 1
fi
log_success "libsfuzzer.a 확인됨: ${SGFUZZ_ROOT}/libsfuzzer.a"

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
    log_info "  3. SGFUZZ_ROOT 경로: ${SGFUZZ_ROOT}"
    log_info "  4. libsfuzzer.a 존재: ${SGFUZZ_ROOT}/libsfuzzer.a"
    exit 1
fi

log_success "CMake 메타데이터 생성 완료"

# 빌드 디렉토리 확인
if ! check_directory "${BUILD_DIR}" "빌드 디렉토리"; then
    log_error "빌드 디렉토리가 생성되지 않았습니다!"
    exit 1
fi

# ===========================================
# 4.4 퍼징 타겟 빌드 (fprime-util build)
# ===========================================
log_info "퍼징 타겟 빌드 중..."
echo "  타겟: ${COMPONENT_NAME}_fuzz"
echo "  병렬 작업: ${N_JOBS}개"
echo "  명령: fprime-util build --target ${COMPONENT_NAME}_fuzz -j ${N_JOBS}"
echo ""

# 디버그 모드 활성화 여부 확인
DEBUG_BUILD="${DEBUG_BUILD:-false}"
if [ "${DEBUG_BUILD}" = "true" ]; then
    log_info "디버그 모드: 상세 빌드 로그 활성화"
    export VERBOSE=1
    
    # CMake 캐시 변수 확인
    log_info "CMake 캐시 변수 확인:"
    if [ -f "${BUILD_DIR}/CMakeCache.txt" ]; then
        echo ""
        echo "SGFUZZ_ROOT 설정:"
        grep "SGFUZZ_ROOT" "${BUILD_DIR}/CMakeCache.txt" || echo "  (설정되지 않음)"
        echo ""
        echo "CMAKE_SOURCE_DIR 관련:"
        grep "CMAKE_SOURCE_DIR" "${BUILD_DIR}/CMakeCache.txt" || echo "  (설정되지 않음)"
        echo ""
    fi
fi

# fprime-util build 실행
if ! fprime-util build --target "${COMPONENT_NAME}_fuzz" -j "${N_JOBS}"; then
    log_warning "퍼징 타겟 빌드 실패!"
    log_info "전체 프로젝트 빌드를 시도합니다..."
    
    # 전체 빌드 재시도
    if ! fprime-util build -j "${N_JOBS}"; then
        log_error "전체 빌드도 실패했습니다."
        log_info ""
        log_info "디버깅 팁:"
        log_info "  1. 빌드 로그에서 컴파일 오류 확인"
        log_info "  2. ${COMPONENT_NAME}_fuzz.cpp에서 헤더 경로 확인"
        log_info "  3. libsfuzzer.a 링크 오류 확인"
        log_info "  4. -fsanitize=fuzzer-no-link 옵션 적용 여부 확인"
        exit 1
    fi
fi

log_success "빌드 완료!"

# ===========================================
# 4.5 빌드 결과 확인
# ===========================================
log_info "빌드된 실행 파일 검색 중..."

# 가능한 경로들
POSSIBLE_PATHS=(
    "${BUILD_DIR}/bin/${COMPONENT_NAME}_fuzz"
    "${BUILD_DIR}/Svc/${COMPONENT_NAME}/fuzz/${COMPONENT_NAME}_fuzz"
    "${BUILD_DIR}/${COMPONENT_NAME}_fuzz"
)

FUZZER_EXEC=""
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        FUZZER_EXEC="$path"
        break
    fi
done

# find 명령어로 추가 검색
if [ -z "${FUZZER_EXEC}" ]; then
    log_info "표준 경로에서 찾을 수 없음. 전체 검색 중..."
    FUZZER_EXEC=$(find "${BUILD_DIR}" -name "${COMPONENT_NAME}_fuzz" -type f 2>/dev/null | head -n 1)
fi

if [ -n "${FUZZER_EXEC}" ] && [ -f "${FUZZER_EXEC}" ]; then
    log_success "퍼저 실행 파일 발견!"
    echo "  경로: ${FUZZER_EXEC}"
    
    # 실행 권한 부여
    chmod +x "${FUZZER_EXEC}"
    
    # 파일 정보 출력
    if command -v file >/dev/null 2>&1; then
        echo ""
        log_info "실행 파일 정보:"
        file "${FUZZER_EXEC}"
    fi
    
    # 크기 확인
    if command -v du >/dev/null 2>&1; then
        FILE_SIZE=$(du -h "${FUZZER_EXEC}" | cut -f1)
        log_info "파일 크기: ${FILE_SIZE}"
    fi
    
    # 환경 변수에 저장 (다음 단계에서 사용)
    export FUZZER_EXEC
    echo "export FUZZER_EXEC=\"${FUZZER_EXEC}\"" >> "${ENV_FILE}"
else
    log_error "퍼저 실행 파일을 찾을 수 없습니다!"
    log_info "검색한 경로:"
    for path in "${POSSIBLE_PATHS[@]}"; do
        echo "  - $path"
    done
    log_info ""
    log_info "빌드 디렉토리: ${BUILD_DIR}"
    log_info "다음 명령으로 수동 검색:"
    log_info "  find ${BUILD_DIR} -name '*_fuzz' -type f"
    exit 1
fi

echo ""
log_success "F Prime 빌드 완료!"
end_timer "F Prime 빌드"

