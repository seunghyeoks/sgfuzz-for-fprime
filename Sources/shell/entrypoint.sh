#!/bin/bash
# SGFuzz for F Prime - 메인 엔트리포인트
# 모든 단계를 순차적으로 오케스트레이션

set -e  # 에러 발생 시 즉시 종료

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 공통 함수 로드
source "${SCRIPT_DIR}/common.sh"

# 컨테이너 환경 확인
if [ ! -d "/workspace/sgfuzz-for-fprime" ]; then
    echo "❌ 컨테이너 환경이 아닙니다!"
    echo "❌ 이 스크립트는 Docker 컨테이너 내부에서만 실행되어야 합니다."
    echo "💡 사용법: docker-compose up --build fsgfuzz"
    exit 1
fi

# ===========================================
# 메인 배너 출력
# ===========================================
print_banner

# ===========================================
# 전체 실행 시간 측정 시작
# ===========================================
TOTAL_START=$(date +%s)

# ===========================================
# 단계별 스크립트 실행
# ===========================================

# 단계 1: 환경 변수 설정
if [ -f "${SCRIPT_DIR}/01_setup_environment.sh" ]; then
    source "${SCRIPT_DIR}/01_setup_environment.sh" || handle_step_failure "1" "환경 변수 설정"
else
    log_error "01_setup_environment.sh를 찾을 수 없습니다!"
    exit 1
fi

# 단계 2: 의존성 확인
if [ -f "${SCRIPT_DIR}/02_check_dependencies.sh" ]; then
    source "${SCRIPT_DIR}/02_check_dependencies.sh" || handle_step_failure "2" "의존성 확인"
else
    log_error "02_check_dependencies.sh를 찾을 수 없습니다!"
    exit 1
fi

# 단계 3: 퍼징 타겟 설정
if [ -f "${SCRIPT_DIR}/03_setup_fuzz_target.sh" ]; then
    source "${SCRIPT_DIR}/03_setup_fuzz_target.sh" || handle_step_failure "3" "퍼징 타겟 설정"
else
    log_error "03_setup_fuzz_target.sh를 찾을 수 없습니다!"
    exit 1
fi

# 단계 4: F Prime 자동 생성 코드 생성
if [ -f "${SCRIPT_DIR}/04_generate_fprime.sh" ]; then
    source "${SCRIPT_DIR}/04_generate_fprime.sh" || handle_step_failure "4" "F Prime 자동 생성"
else
    log_error "04_generate_fprime.sh를 찾을 수 없습니다!"
    exit 1
fi

# 단계 5: SGFuzz 계측
if [ -f "${SCRIPT_DIR}/05_sgfuzz_instrument.sh" ]; then
    source "${SCRIPT_DIR}/05_sgfuzz_instrument.sh" || handle_step_failure "5" "SGFuzz 계측"
else
    log_error "05_sgfuzz_instrument.sh를 찾을 수 없습니다!"
    exit 1
fi

# 단계 6: F Prime 빌드
if [ -f "${SCRIPT_DIR}/06_build_fprime.sh" ]; then
    source "${SCRIPT_DIR}/06_build_fprime.sh" || handle_step_failure "6" "F Prime 빌드"
else
    log_error "06_build_fprime.sh를 찾을 수 없습니다!"
    exit 1
fi

# 단계 7: 퍼저 실행
if [ -f "${SCRIPT_DIR}/07_run_fuzzer.sh" ]; then
    source "${SCRIPT_DIR}/07_run_fuzzer.sh" || handle_step_failure "7" "퍼저 실행"
else
    log_error "07_run_fuzzer.sh를 찾을 수 없습니다!"
    exit 1
fi

# ===========================================
# 전체 실행 시간 계산
# ===========================================
TOTAL_END=$(date +%s)
TOTAL_ELAPSED=$((TOTAL_END - TOTAL_START))
TOTAL_MINUTES=$((TOTAL_ELAPSED / 60))
TOTAL_SECONDS=$((TOTAL_ELAPSED % 60))

# ===========================================
# 최종 요약 출력
# ===========================================
echo ""
echo "=========================================="
echo "  SGFuzz 파이프라인 완료"
echo "=========================================="
echo ""
log_success "모든 단계가 성공적으로 완료되었습니다!"
echo ""
echo "  총 실행 시간: ${TOTAL_MINUTES}분 ${TOTAL_SECONDS}초"
echo ""
echo "  실행된 단계:"
echo "    ✓ 1. 환경 변수 설정"
echo "    ✓ 2. 의존성 확인"
echo "    ✓ 3. 퍼징 타겟 설정"
echo "    ✓ 4. F Prime 자동 생성 코드 생성"
echo "    ✓ 5. SGFuzz 계측"
echo "    ✓ 6. F Prime 빌드"
echo "    ✓ 7. 퍼저 실행"
echo ""

# ===========================================
# 결과 파일 위치 안내
# ===========================================
log_info "결과 파일 위치:"
echo "  - 로그: ${FUZZ_OUTPUT}/fuzzer.log"
echo "  - Corpus: ${FUZZ_OUTPUT}/corpus"
echo "  - Artifacts: ${FUZZ_OUTPUT}/artifacts"
echo "  - 환경 변수: ${PROJECT_ROOT}/.fuzz_env"
echo ""

# 이슈 요약
TOTAL_ISSUES=$(find "${FUZZ_OUTPUT}/artifacts" -type f \( -name "crash-*" -o -name "leak-*" -o -name "timeout-*" \) 2>/dev/null | wc -l | tr -d ' ')
if [ ${TOTAL_ISSUES} -gt 0 ]; then
    log_warning "발견된 이슈: ${TOTAL_ISSUES}개"
    echo "  자세한 내용은 ${FUZZ_OUTPUT}/artifacts 디렉토리를 확인하세요."
else
    log_success "이슈가 발견되지 않았습니다."
fi

echo ""

# ===========================================
# Keep-alive 모드
# ===========================================
if [ "${KEEP_ALIVE}" = "true" ]; then
    log_info "Keep-alive 모드 활성화: 컨테이너가 계속 실행됩니다."
    log_info "종료하려면 Ctrl+C를 누르거나 docker stop을 사용하세요."
    echo ""
    tail -f /dev/null
else
    log_info "파이프라인이 종료됩니다."
fi

exit 0
