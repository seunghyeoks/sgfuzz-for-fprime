#!/bin/bash
# SGFuzz for F Prime - 단순화 버전

set -e

# ===========================================
# 환경 변수
# ===========================================
export PROJECT_ROOT="${PROJECT_ROOT:-/workspace/sgfuzz-for-fprime}"
export FPRIME_ROOT="${FPRIME_ROOT:-${PROJECT_ROOT}/fprime}"
export SGFUZZ_ROOT="${SGFUZZ_ROOT:-${PROJECT_ROOT}/SGFuzz}"
export COMPONENT_NAME="${COMPONENT_NAME:-CmdDispatcher}"
export BUILD_DIR="${BUILD_DIR:-${FPRIME_ROOT}/build-fprime-automatic-native}"
export FUZZ_OUTPUT="${FUZZ_OUTPUT:-${PROJECT_ROOT}/fuzz_output}"

# 컴파일러 (Clang 필수)
export CC="${CC:-clang}"
export CXX="${CXX:-clang++}"

# 퍼저 옵션
export FUZZ_RUNS="${FUZZ_RUNS:--1}"
export FUZZ_MAX_LEN="${FUZZ_MAX_LEN:-1024}"
export FUZZ_TIMEOUT="${FUZZ_TIMEOUT:-60}"

N_JOBS=$(nproc 2>/dev/null || echo 4)

echo "=========================================="
echo "  SGFuzz for F Prime - ${COMPONENT_NAME}"
echo "=========================================="

# ===========================================
# 1. Generate
# ===========================================

echo "[1/4] Generate"
cd "${FPRIME_ROOT}"
rm -rf "${BUILD_DIR}"

fprime-util generate \
    -DCMAKE_BUILD_TYPE=Testing \
    -DSGFUZZ_ROOT="${SGFUZZ_ROOT}" \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_CXX_COMPILER="${CXX}"

# ===========================================
# 2. 초기 빌드
# ===========================================
echo "[2/4] Build (initial)"
fprime-util build --target "${COMPONENT_NAME}_fuzz" -j "${N_JOBS}"

# ===========================================
# 3. 계측
# ===========================================
echo "[3/4] Instrument"
INSTRUMENT_TARGET=$(find "${BUILD_DIR}" -type d -path "*/Svc/${COMPONENT_NAME}/fuzz" | head -n 1)
python3 "${SGFUZZ_ROOT}/sanitizer/State_machine_instrument.py" "${INSTRUMENT_TARGET}" || true

# ===========================================
# 4. 최종 빌드
# ===========================================
echo "[4/4] Build (final)"
fprime-util build --target "${COMPONENT_NAME}_fuzz" -j "${N_JOBS}"

# ===========================================
# 5. 퍼징
# ===========================================
echo "[5/5] Fuzzing"
mkdir -p "${FUZZ_OUTPUT}"/{corpus,artifacts}

FUZZER_BIN=$(find "${BUILD_DIR}" -name "${COMPONENT_NAME}_fuzz" -type f -executable | head -n 1)

if [ -z "${FUZZER_BIN}" ]; then
    echo "ERROR: Fuzzer not found!"
    exit 1
fi

echo "Fuzzer: ${FUZZER_BIN}"
echo "Fuzzer options:"
if [ "${FUZZ_RUNS}" = "-1" ]; then
    echo "  - FUZZ_RUNS=${FUZZ_RUNS} (infinite)"
else
    echo "  - FUZZ_RUNS=${FUZZ_RUNS}"
fi
echo "  - FUZZ_MAX_LEN=${FUZZ_MAX_LEN}"
echo "  - FUZZ_TIMEOUT=${FUZZ_TIMEOUT}"

cd "${FUZZ_OUTPUT}"

# 실제 실행 명령어 출력 (디버깅용)
echo "Executing: ${FUZZER_BIN} corpus -max_len=${FUZZ_MAX_LEN} -timeout=${FUZZ_TIMEOUT} -runs=${FUZZ_RUNS} -artifact_prefix=artifacts/"
echo ""

"${FUZZER_BIN}" \
    corpus \
    -max_len="${FUZZ_MAX_LEN}" \
    -timeout="${FUZZ_TIMEOUT}" \
    -runs="${FUZZ_RUNS}" \
    -artifact_prefix=artifacts/ \
    2>&1 | tee fuzzer.log

echo ""
echo "=========================================="
echo "Done! Check: ${FUZZ_OUTPUT}"
echo "=========================================="
