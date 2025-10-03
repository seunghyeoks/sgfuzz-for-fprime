#!/bin/bash
set -e  # 에러 발생 시 즉시 종료

# 색상 코드 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 배너 출력
print_banner() {
    echo ""
    echo "=========================================="
    echo "  SGFuzz for F Prime - Auto Fuzzer"
    echo "  Target: CmdDispatcher Component"
    echo "  Engine: SGFuzz (Stateful Greybox Fuzzer)"
    echo "=========================================="
    echo ""
}

# 환경 변수 설정
setup_environment() {
    log_info "환경 변수 설정 중..."
    
    export PROJECT_ROOT="/workspace/sgfuzz-for-fprime"
    export FPRIME_ROOT="${PROJECT_ROOT}/fprime"
    export SGFUZZ_ROOT="${PROJECT_ROOT}/SGFuzz"
    export COMPONENT_NAME="${COMPONENT_NAME:-CmdDispatcher}"
    export COMPONENT_PATH="${FPRIME_ROOT}/Svc/${COMPONENT_NAME}"
    export BUILD_DIR="${FPRIME_ROOT}/build-fprime-automatic-native"
    export FUZZ_OUTPUT="${PROJECT_ROOT}/fuzz_output"
    
    # Clang 컴파일러 설정 (LibFuzzer 필수)
    log_info "Clang 컴파일러 설정 중..."
    if command -v clang-14 &> /dev/null; then
        export CC=clang-14
        export CXX=clang++-14
        log_success "Clang-14 사용"
    elif command -v clang &> /dev/null; then
        export CC=clang
        export CXX=clang++
        log_success "Clang 사용"
    else
        log_error "Clang 컴파일러를 찾을 수 없습니다!"
        log_error "LibFuzzer는 Clang이 필수입니다."
        exit 1
    fi
    
    log_success "환경 변수 설정 완료"
    echo "  - PROJECT_ROOT: ${PROJECT_ROOT}"
    echo "  - COMPONENT_NAME: ${COMPONENT_NAME}"
    echo "  - FUZZ_OUTPUT: ${FUZZ_OUTPUT}"
    echo "  - CC: ${CC}"
    echo "  - CXX: ${CXX}"
}

# SGFuzz 라이브러리 확인 및 빌드
check_sgfuzz() {
    log_info "SGFuzz 라이브러리 확인 중..."
    
    if [ ! -f "${SGFUZZ_ROOT}/libsfuzzer.a" ]; then
        log_warning "libsfuzzer.a를 찾을 수 없습니다. SGFuzz 빌드를 시작합니다..."
        cd "${SGFUZZ_ROOT}"
        ./build.sh
        
        if [ ! -f "${SGFUZZ_ROOT}/libsfuzzer.a" ]; then
            log_error "SGFuzz 빌드 실패!"
            exit 1
        fi
    fi
    
    log_success "SGFuzz 라이브러리 확인 완료: ${SGFUZZ_ROOT}/libsfuzzer.a"
    log_info "상태 계측(State Instrumentation): ${USE_STATE_INSTRUMENTATION:-DISABLED}"
}

# 퍼징 타겟 자동 생성
setup_fuzz_target() {
    log_info "퍼징 타겟 자동 생성 중..."
    
    cd "${PROJECT_ROOT}"
    
    # 퍼징 타겟이 이미 존재하는지 확인
    if [ -d "${COMPONENT_PATH}/fuzz" ]; then
        log_warning "fuzz 디렉토리가 이미 존재합니다. 건너뜁니다."
    else
        # setup_fuzz_target.py 실행
        python3 scripts/setup_fuzz_target.py \
            --component "${COMPONENT_NAME}" \
            --force
        
        if [ $? -ne 0 ]; then
            log_error "퍼징 타겟 생성 실패!"
            exit 1
        fi
    fi
    
    log_success "퍼징 타겟 설정 완료"
}

# F Prime 프로젝트 빌드
build_fprime() {
    log_info "F Prime 프로젝트 빌드 중..."
    
    cd "${FPRIME_ROOT}"
    
    # 기존 빌드 디렉토리 확인 및 정리
    if [ -d "${BUILD_DIR}" ]; then
        log_warning "기존 빌드 디렉토리 발견: ${BUILD_DIR}"
        log_info "기존 빌드 디렉토리 삭제 중..."
        rm -rf "${BUILD_DIR}"
    fi
    
    # CMake 메타데이터 생성
    log_info "fprime-util generate 실행 중..."
    fprime-util generate
    
    if [ $? -ne 0 ]; then
        log_error "fprime-util generate 실패!"
        exit 1
    fi
    
    log_success "CMake 메타데이터 생성 완료"
    
    # 퍼징 타겟 빌드
    log_info "fprime-util build --target ${COMPONENT_NAME}_fuzz 실행 중..."
    fprime-util build --target "${COMPONENT_NAME}_fuzz"
    
    if [ $? -ne 0 ]; then
        log_error "퍼징 타겟 빌드 실패!"
        log_warning "전체 빌드를 시도합니다..."
        fprime-util build
    fi
    
    log_success "빌드 완료"
}

# 빌드된 퍼저 실행 파일 찾기
find_fuzzer_executable() {
    log_info "퍼저 실행 파일 검색 중..."
    
    # 가능한 경로들
    POSSIBLE_PATHS=(
        "${BUILD_DIR}/bin/${COMPONENT_NAME}_fuzz"
        "${BUILD_DIR}/Svc/${COMPONENT_NAME}/fuzz/${COMPONENT_NAME}_fuzz"
        "${BUILD_DIR}/${COMPONENT_NAME}_fuzz"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -f "$path" ]; then
            FUZZER_EXEC="$path"
            log_success "퍼저 실행 파일 발견: ${FUZZER_EXEC}"
            return 0
        fi
    done
    
    # find 명령어로 검색
    log_info "디렉토리 스캔 중..."
    FUZZER_EXEC=$(find "${BUILD_DIR}" -name "${COMPONENT_NAME}_fuzz" -type f 2>/dev/null | head -n 1)
    
    if [ -n "${FUZZER_EXEC}" ] && [ -f "${FUZZER_EXEC}" ]; then
        log_success "퍼저 실행 파일 발견: ${FUZZER_EXEC}"
        return 0
    fi
    
    log_error "퍼저 실행 파일을 찾을 수 없습니다!"
    return 1
}

# 퍼저 실행
run_fuzzer() {
    log_info "퍼저 실행 준비 중..."
    
    # 출력 디렉토리 생성
    mkdir -p "${FUZZ_OUTPUT}/corpus"
    mkdir -p "${FUZZ_OUTPUT}/crashes"
    mkdir -p "${FUZZ_OUTPUT}/artifacts"
    
    # 퍼저 실행 파일 찾기
    if ! find_fuzzer_executable; then
        log_error "퍼저 실행 불가"
        exit 1
    fi
    
    # 실행 권한 확인
    chmod +x "${FUZZER_EXEC}"
    
    # 퍼저 옵션 설정
    FUZZ_RUNS="${FUZZ_RUNS:-0}"           # 0 = 무한 실행
    FUZZ_MAX_LEN="${FUZZ_MAX_LEN:-1024}"
    FUZZ_TIMEOUT="${FUZZ_TIMEOUT:-60}"
    FUZZ_WORKERS="${FUZZ_WORKERS:-1}"
    
    log_success "퍼저 실행 시작!"
    echo ""
    echo "=========================================="
    echo "  퍼저 설정:"
    echo "  - 실행 파일: ${FUZZER_EXEC}"
    echo "  - 퍼징 엔진: SGFuzz + AddressSanitizer"
    echo "  - 상태 추적: ${USE_STATE_INSTRUMENTATION:-비활성화 (기본 커버리지 기반)}"
    echo "  - 최대 입력 크기: ${FUZZ_MAX_LEN} bytes"
    echo "  - 실행 횟수: ${FUZZ_RUNS} (0=무한)"
    echo "  - 타임아웃: ${FUZZ_TIMEOUT}초"
    echo "  - 워커 수: ${FUZZ_WORKERS}"
    echo "  - 출력 디렉토리: ${FUZZ_OUTPUT}"
    echo "=========================================="
    echo ""
    log_info "종료하려면 Ctrl+C를 누르세요"
    echo ""
    
    # LibFuzzer 실행
    cd "${FUZZ_OUTPUT}"
    
    "${FUZZER_EXEC}" \
        "${FUZZ_OUTPUT}/corpus" \
        -max_len="${FUZZ_MAX_LEN}" \
        -timeout="${FUZZ_TIMEOUT}" \
        -runs="${FUZZ_RUNS}" \
        -workers="${FUZZ_WORKERS}" \
        -artifact_prefix="${FUZZ_OUTPUT}/artifacts/" \
        -print_final_stats=1 \
        -print_corpus_stats=1 \
        2>&1 | tee "${FUZZ_OUTPUT}/fuzzer.log"
    
    FUZZER_EXIT_CODE=$?
    
    echo ""
    if [ ${FUZZER_EXIT_CODE} -eq 0 ]; then
        log_success "퍼저가 정상 종료되었습니다."
    else
        log_warning "퍼저가 종료되었습니다 (종료 코드: ${FUZZER_EXIT_CODE})"
        
        # 크래시 파일 확인
        CRASH_COUNT=$(find "${FUZZ_OUTPUT}/artifacts" -name "crash-*" 2>/dev/null | wc -l)
        if [ ${CRASH_COUNT} -gt 0 ]; then
            log_warning "발견된 크래시: ${CRASH_COUNT}개"
            echo "  위치: ${FUZZ_OUTPUT}/artifacts/"
        fi
    fi
}

# 결과 요약 출력
print_summary() {
    echo ""
    echo "=========================================="
    echo "  퍼징 세션 완료"
    echo "=========================================="
    
    if [ -d "${FUZZ_OUTPUT}" ]; then
        log_info "결과 요약:"
        echo "  - 로그: ${FUZZ_OUTPUT}/fuzzer.log"
        
        CORPUS_COUNT=$(find "${FUZZ_OUTPUT}/corpus" -type f 2>/dev/null | wc -l)
        echo "  - 코퍼스: ${CORPUS_COUNT}개 파일"
        
        CRASH_COUNT=$(find "${FUZZ_OUTPUT}/artifacts" -name "crash-*" -o -name "leak-*" -o -name "timeout-*" 2>/dev/null | wc -l)
        echo "  - 발견된 이슈: ${CRASH_COUNT}개"
        
        if [ ${CRASH_COUNT} -gt 0 ]; then
            echo ""
            log_warning "발견된 이슈 목록:"
            find "${FUZZ_OUTPUT}/artifacts" -type f -name "*-*" 2>/dev/null | head -n 10
        fi
    fi
    
    echo ""
    log_info "컨테이너는 계속 실행 중입니다. 종료하려면 Ctrl+C를 누르세요."
}

# 메인 함수
main() {
    print_banner
    
    # 단계별 실행
    setup_environment
    check_sgfuzz
    setup_fuzz_target
    build_fprime
    run_fuzzer
    print_summary
    
    # 컨테이너가 종료되지 않도록 대기
    if [ "${KEEP_ALIVE}" = "true" ]; then
        log_info "Keep-alive 모드: 무한 대기 중..."
        tail -f /dev/null
    fi
}

# 스크립트 실행
main "$@"
