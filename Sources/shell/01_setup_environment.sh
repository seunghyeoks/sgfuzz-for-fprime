#!/bin/bash
# 단계 1: 환경 변수 설정
# SUMMARY.md 전략 반영 - 프로젝트 경로 및 빌드 환경 구성

set -e

# 공통 함수 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_step "1" "환경 변수 설정"
start_timer

# 컨테이너 환경 확인
if [ ! -d "/workspace/sgfuzz-for-fprime" ]; then
    log_error "컨테이너 환경이 아닙니다!"
    log_error "이 스크립트는 Docker 컨테이너 내부에서만 실행되어야 합니다."
    log_info "사용법: docker-compose up --build fsgfuzz"
    exit 1
fi

# 프로젝트 경로 설정 (컨테이너 내부 경로만 사용)
export PROJECT_ROOT="/workspace/sgfuzz-for-fprime"
export FPRIME_ROOT="${PROJECT_ROOT}/fprime"
export SGFUZZ_ROOT="${PROJECT_ROOT}/SGFuzz"

# 컴포넌트 설정 (Docker 환경 변수 또는 기본값)
export COMPONENT_NAME="${COMPONENT_NAME:-CmdDispatcher}"
export COMPONENT_PATH="${COMPONENT_PATH:-${FPRIME_ROOT}/Svc/${COMPONENT_NAME}}"

# 빌드 디렉토리 설정
export BUILD_DIR="${BUILD_DIR:-${FPRIME_ROOT}/build-fprime-automatic-native}"
export BUILD_TYPE="${BUILD_TYPE:-Testing}"

# 출력 디렉토리 설정
export FUZZ_OUTPUT="${FUZZ_OUTPUT:-${PROJECT_ROOT}/fuzz_output}"

# 컴파일러 설정 (SGFuzz는 Clang 필요)
export CC="${CC:-clang}"
export CXX="${CXX:-clang++}"

# 빌드 병렬화 설정
if [ -z "${N_JOBS}" ]; then
    # CPU 코어 수 자동 감지 (Linux/macOS 모두 지원)
    if command -v nproc >/dev/null 2>&1; then
        export N_JOBS=$(nproc)
    elif command -v sysctl >/dev/null 2>&1; then
        export N_JOBS=$(sysctl -n hw.ncpu)
    else
        export N_JOBS=2
    fi
fi

# 퍼저 실행 옵션 (Docker 환경 변수 또는 기본값)
export FUZZ_RUNS="${FUZZ_RUNS:-0}"              # 0 = 무한 실행
export FUZZ_MAX_LEN="${FUZZ_MAX_LEN:-1024}"     # 최대 입력 크기
export FUZZ_TIMEOUT="${FUZZ_TIMEOUT:-60}"       # 타임아웃(초)
export FUZZ_WORKERS="${FUZZ_WORKERS:-1}"        # 병렬 워커 수
export FUZZ_EXTRA_ARGS="${FUZZ_EXTRA_ARGS:-}"   # 추가 인자

# Keep-alive 설정
export KEEP_ALIVE="${KEEP_ALIVE:-false}"

# 환경 변수 요약 출력
print_env_summary

# 기본 경로 검증
log_info "프로젝트 경로 검증 중..."
check_directory "${PROJECT_ROOT}" "프로젝트 루트" || exit 1
check_directory "${FPRIME_ROOT}" "F Prime 루트" || exit 1
check_directory "${SGFUZZ_ROOT}" "SGFuzz 루트" || exit 1

log_success "환경 변수 설정 완료"
end_timer "환경 변수 설정"

# 환경 변수를 파일로 저장 (다른 스크립트에서 재사용 가능)
ENV_FILE="${PROJECT_ROOT}/.fuzz_env"
cat > "${ENV_FILE}" <<EOF
# SGFuzz 환경 변수 (자동 생성)
# Generated at: $(date)

export PROJECT_ROOT="${PROJECT_ROOT}"
export FPRIME_ROOT="${FPRIME_ROOT}"
export SGFUZZ_ROOT="${SGFUZZ_ROOT}"
export COMPONENT_NAME="${COMPONENT_NAME}"
export COMPONENT_PATH="${COMPONENT_PATH}"
export BUILD_DIR="${BUILD_DIR}"
export BUILD_TYPE="${BUILD_TYPE}"
export FUZZ_OUTPUT="${FUZZ_OUTPUT}"
export CC="${CC}"
export CXX="${CXX}"
export N_JOBS="${N_JOBS}"
export FUZZ_RUNS="${FUZZ_RUNS}"
export FUZZ_MAX_LEN="${FUZZ_MAX_LEN}"
export FUZZ_TIMEOUT="${FUZZ_TIMEOUT}"
export FUZZ_WORKERS="${FUZZ_WORKERS}"
export FUZZ_EXTRA_ARGS="${FUZZ_EXTRA_ARGS}"
export KEEP_ALIVE="${KEEP_ALIVE}"
EOF

log_success "환경 변수 저장: ${ENV_FILE}"

