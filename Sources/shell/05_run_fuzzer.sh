#!/bin/bash
# 단계 5: 퍼저 실행
# SUMMARY.md 전략 단계 6 반영:
#   - LibFuzzer 실행
#   - corpus, crashes, artifacts 관리
#   - 실행 로그 및 통계 수집

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

log_step "5" "퍼저 실행"
start_timer

# ===========================================
# 5.1 퍼저 실행 파일 확인
# ===========================================
log_info "퍼저 실행 파일 확인 중..."

# FUZZER_EXEC가 환경 변수에 없으면 검색
if [ -z "${FUZZER_EXEC}" ]; then
    log_warning "FUZZER_EXEC 환경 변수가 설정되지 않았습니다. 검색 중..."
    
    POSSIBLE_PATHS=(
        "${BUILD_DIR}/bin/${COMPONENT_NAME}_fuzz"
        "${BUILD_DIR}/Svc/${COMPONENT_NAME}/fuzz/${COMPONENT_NAME}_fuzz"
        "${BUILD_DIR}/${COMPONENT_NAME}_fuzz"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -f "$path" ]; then
            FUZZER_EXEC="$path"
            break
        fi
    done
    
    if [ -z "${FUZZER_EXEC}" ]; then
        FUZZER_EXEC=$(find "${BUILD_DIR}" -name "${COMPONENT_NAME}_fuzz" -type f 2>/dev/null | head -n 1)
    fi
fi

if [ -z "${FUZZER_EXEC}" ] || [ ! -f "${FUZZER_EXEC}" ]; then
    log_error "퍼저 실행 파일을 찾을 수 없습니다!"
    log_info "빌드가 완료되었는지 확인하세요: ${COMPONENT_NAME}_fuzz"
    exit 1
fi

log_success "퍼저 실행 파일: ${FUZZER_EXEC}"
chmod +x "${FUZZER_EXEC}"

# ===========================================
# 5.2 출력 디렉토리 생성
# ===========================================
log_info "출력 디렉토리 생성 중..."

mkdir -p "${FUZZ_OUTPUT}/corpus"
mkdir -p "${FUZZ_OUTPUT}/crashes"
mkdir -p "${FUZZ_OUTPUT}/artifacts"

log_success "출력 디렉토리 생성 완료"
echo "  - corpus: ${FUZZ_OUTPUT}/corpus"
echo "  - crashes: ${FUZZ_OUTPUT}/crashes"
echo "  - artifacts: ${FUZZ_OUTPUT}/artifacts"

# ===========================================
# 5.3 초기 seed corpus 확인
# ===========================================
log_info "초기 seed corpus 확인 중..."

CORPUS_COUNT=$(find "${FUZZ_OUTPUT}/corpus" -type f 2>/dev/null | wc -l | tr -d ' ')

if [ "${CORPUS_COUNT}" -eq 0 ]; then
    log_warning "초기 seed corpus가 비어 있습니다."
    log_info "LibFuzzer가 자동으로 입력을 생성합니다."
    
    # (선택) 기본 seed 파일 생성
    echo -n "SEED" > "${FUZZ_OUTPUT}/corpus/seed1"
    log_info "기본 seed 파일 생성: seed1"
else
    log_success "초기 corpus: ${CORPUS_COUNT}개 파일"
fi

# ===========================================
# 5.4 퍼저 옵션 설정
# ===========================================
log_info "퍼저 옵션 설정 중..."

# 기본값 설정 (환경 변수가 없는 경우)
FUZZ_RUNS="${FUZZ_RUNS:-0}"              # 0 = 무한 실행
FUZZ_MAX_LEN="${FUZZ_MAX_LEN:-1024}"     # 최대 입력 크기
FUZZ_TIMEOUT="${FUZZ_TIMEOUT:-60}"       # 개별 입력 타임아웃(초)
FUZZ_WORKERS="${FUZZ_WORKERS:-1}"        # 병렬 워커 수
FUZZ_EXTRA_ARGS="${FUZZ_EXTRA_ARGS:-}"   # 추가 인자

# LibFuzzer 실행 옵션 구성
FUZZER_ARGS=(
    "${FUZZ_OUTPUT}/corpus"                          # corpus 디렉토리
    "-max_len=${FUZZ_MAX_LEN}"                       # 최대 입력 크기
    "-timeout=${FUZZ_TIMEOUT}"                       # 타임아웃
    "-runs=${FUZZ_RUNS}"                             # 실행 횟수
    "-workers=${FUZZ_WORKERS}"                       # 워커 수
    "-artifact_prefix=${FUZZ_OUTPUT}/artifacts/"     # artifact 저장 경로
    "-print_final_stats=1"                           # 최종 통계 출력
    "-print_corpus_stats=1"                          # corpus 통계 출력
    "-print_pcs=1"                                   # PC 커버리지 출력
    "-print_coverage=1"                              # 커버리지 출력
)

# 추가 인자가 있으면 포함
if [ -n "${FUZZ_EXTRA_ARGS}" ]; then
    FUZZER_ARGS+=( ${FUZZ_EXTRA_ARGS} )
fi

# ===========================================
# 5.5 퍼저 실행 정보 출력
# ===========================================
echo ""
echo "=========================================="
echo "  퍼저 실행 정보"
echo "=========================================="
echo "  실행 파일: ${FUZZER_EXEC}"
echo "  컴포넌트: ${COMPONENT_NAME}"
echo ""
echo "  옵션:"
echo "    - 최대 입력 크기: ${FUZZ_MAX_LEN} bytes"
echo "    - 실행 횟수: ${FUZZ_RUNS} $([ ${FUZZ_RUNS} -eq 0 ] && echo '(무한)')"
echo "    - 타임아웃: ${FUZZ_TIMEOUT}초"
echo "    - 워커 수: ${FUZZ_WORKERS}"
echo ""
echo "  출력:"
echo "    - corpus: ${FUZZ_OUTPUT}/corpus"
echo "    - artifacts: ${FUZZ_OUTPUT}/artifacts"
echo "    - 로그: ${FUZZ_OUTPUT}/fuzzer.log"
echo ""
if [ -n "${FUZZ_EXTRA_ARGS}" ]; then
    echo "  추가 옵션: ${FUZZ_EXTRA_ARGS}"
    echo ""
fi
echo "=========================================="
echo ""

log_info "퍼저 시작..."
echo ""

# ===========================================
# 5.6 퍼저 실행
# ===========================================
cd "${FUZZ_OUTPUT}"

# 시작 시간 기록
START_TIME=$(date +%s)
echo "START_TIME=$(date)" > "${FUZZ_OUTPUT}/fuzzer_session.txt"

# LibFuzzer 실행 (로그 파일에 tee)
"${FUZZER_EXEC}" "${FUZZER_ARGS[@]}" 2>&1 | tee "${FUZZ_OUTPUT}/fuzzer.log"

FUZZER_EXIT_CODE=$?

# 종료 시간 기록
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "END_TIME=$(date)" >> "${FUZZ_OUTPUT}/fuzzer_session.txt"
echo "ELAPSED=${ELAPSED}" >> "${FUZZ_OUTPUT}/fuzzer_session.txt"
echo "EXIT_CODE=${FUZZER_EXIT_CODE}" >> "${FUZZ_OUTPUT}/fuzzer_session.txt"

# ===========================================
# 5.7 퍼저 종료 처리
# ===========================================
echo ""
echo "=========================================="
echo "  퍼저 실행 종료"
echo "=========================================="

if [ ${FUZZER_EXIT_CODE} -eq 0 ]; then
    log_success "퍼저가 정상 종료되었습니다."
else
    log_warning "퍼저가 비정상 종료되었습니다 (종료 코드: ${FUZZER_EXIT_CODE})"
fi

echo "  실행 시간: ${ELAPSED}초 ($(($ELAPSED / 60))분)"

# ===========================================
# 5.8 결과 요약
# ===========================================
log_info "퍼징 결과 요약 중..."

# Corpus 카운트
CORPUS_FINAL=$(find "${FUZZ_OUTPUT}/corpus" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  - Corpus: ${CORPUS_FINAL}개 파일"

# Artifacts 카운트 (crash, leak, timeout 등)
CRASH_COUNT=$(find "${FUZZ_OUTPUT}/artifacts" -name "crash-*" 2>/dev/null | wc -l | tr -d ' ')
LEAK_COUNT=$(find "${FUZZ_OUTPUT}/artifacts" -name "leak-*" 2>/dev/null | wc -l | tr -d ' ')
TIMEOUT_COUNT=$(find "${FUZZ_OUTPUT}/artifacts" -name "timeout-*" 2>/dev/null | wc -l | tr -d ' ')
TOTAL_ISSUES=$((CRASH_COUNT + LEAK_COUNT + TIMEOUT_COUNT))

echo "  - 발견된 이슈: ${TOTAL_ISSUES}개"
echo "    * Crashes: ${CRASH_COUNT}개"
echo "    * Leaks: ${LEAK_COUNT}개"
echo "    * Timeouts: ${TIMEOUT_COUNT}개"

# 이슈 파일 목록 출력 (최대 10개)
if [ ${TOTAL_ISSUES} -gt 0 ]; then
    echo ""
    log_warning "발견된 이슈 목록:"
    find "${FUZZ_OUTPUT}/artifacts" -type f \( -name "crash-*" -o -name "leak-*" -o -name "timeout-*" \) 2>/dev/null | head -n 10 | while read issue; do
        echo "    - $(basename $issue)"
    done
    
    if [ ${TOTAL_ISSUES} -gt 10 ]; then
        echo "    ... 외 $((TOTAL_ISSUES - 10))개"
    fi
fi

# 로그 파일 위치
echo ""
echo "  로그: ${FUZZ_OUTPUT}/fuzzer.log"
echo "  세션 정보: ${FUZZ_OUTPUT}/fuzzer_session.txt"
echo ""

log_success "퍼징 세션 완료!"
end_timer "퍼저 실행"

# ===========================================
# 5.9 후속 작업 안내
# ===========================================
if [ ${TOTAL_ISSUES} -gt 0 ]; then
    echo ""
    log_warning "다음 단계:"
    echo "  1. artifacts 디렉토리에서 이슈 파일 확인"
    echo "  2. 재현 테스트:"
    echo "     ${FUZZER_EXEC} ${FUZZ_OUTPUT}/artifacts/crash-XXXXX"
    echo "  3. 디버거로 분석:"
    echo "     gdb --args ${FUZZER_EXEC} ${FUZZ_OUTPUT}/artifacts/crash-XXXXX"
    echo ""
fi

