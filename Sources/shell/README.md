# SGFuzz for F Prime - 자동화 스크립트 가이드

이 디렉토리는 F Prime에 SGFuzz를 적용하기 위한 모듈화된 자동화 스크립트를 포함합니다.

## 📁 파일 구조

```
Sources/shell/
├── common.sh                    # 공통 함수 (로깅, 색상, 유틸리티)
├── 01_setup_environment.sh      # 환경 변수 설정
├── 02_check_dependencies.sh     # 의존성 확인 (도구, SGFuzz)
├── 03_setup_fuzz_target.sh      # 퍼징 타겟 생성 (CMake, 소스 복사, 계측)
├── 04_build_fprime.sh           # F Prime 빌드
├── 05_run_fuzzer.sh             # 퍼저 실행
├── entrypoint.sh                # 메인 오케스트레이션 (모든 단계 실행)
└── README.md                    # 이 파일
```

## 🚀 사용 방법

### 1. 전체 파이프라인 실행 (Docker 권장)

```bash
# docker-compose로 실행
cd Sources/docker
docker-compose up --build fsgfuzz

# 또는 Docker 직접 실행
docker build -t fsgfuzz:latest -f Sources/docker/Dockerfile.fsgfuzz .
docker run -it \
  -e COMPONENT_NAME=CmdDispatcher \
  -e FUZZ_RUNS=10000 \
  -v $(pwd)/fuzz_output:/workspace/sgfuzz-for-fprime/fuzz_output \
  fsgfuzz:latest
```

### 2. 개별 단계 실행 (로컬 또는 디버깅)

각 스크립트는 독립적으로 실행 가능합니다:

#### 단계 1: 환경 변수 설정
```bash
source Sources/shell/01_setup_environment.sh
```

환경 변수를 `.fuzz_env` 파일에 저장하므로, 다른 스크립트에서 재사용할 수 있습니다.

#### 단계 2: 의존성 확인
```bash
source Sources/shell/02_check_dependencies.sh
```

SGFuzz가 빌드되지 않았다면 자동으로 빌드합니다.

#### 단계 3: 퍼징 타겟 설정
```bash
source Sources/shell/03_setup_fuzz_target.sh
```

`scripts/setup_fuzz_target.py`를 호출하여 퍼징 타겟을 자동 생성합니다:
- `fuzz/CMakeLists.txt`
- `fuzz/CmdDispatcher_fuzz.cpp`
- `fuzz/README.md`

#### 단계 4: F Prime 빌드
```bash
source Sources/shell/04_build_fprime.sh
```

`fprime-util generate` 및 `fprime-util build --target CmdDispatcher_fuzz`를 실행합니다.

#### 단계 5: 퍼저 실행
```bash
source Sources/shell/05_run_fuzzer.sh
```

LibFuzzer를 실행하고 결과를 `fuzz_output/`에 저장합니다.

### 3. 특정 단계부터 시작

환경 변수 파일이 있다면, 중간 단계부터 시작할 수 있습니다:

```bash
# 환경 변수 로드
source .fuzz_env

# 특정 단계만 실행 (예: 빌드만 다시)
source Sources/shell/04_build_fprime.sh
```

## ⚙️ 환경 변수 설정

### Docker 환경 변수 (`docker-compose.yml`)

```yaml
environment:
  - COMPONENT_NAME=CmdDispatcher      # 타겟 컴포넌트 이름
  - FUZZ_RUNS=0                       # 실행 횟수 (0=무한)
  - FUZZ_MAX_LEN=1024                 # 최대 입력 크기
  - FUZZ_TIMEOUT=60                   # 타임아웃(초)
  - FUZZ_WORKERS=1                    # 병렬 워커 수
  - BUILD_TYPE=Testing                # CMake 빌드 타입
  - N_JOBS=4                          # 병렬 빌드 작업 수
  - CLEAN_BUILD=true                  # 빌드 디렉토리 정리 여부
  - KEEP_ALIVE=false                  # 퍼징 후 컨테이너 유지 여부
  - FUZZ_EXTRA_ARGS=-dict=dict.txt    # LibFuzzer 추가 옵션
```

### 로컬 실행 시 환경 변수

```bash
export COMPONENT_NAME=CmdDispatcher
export FUZZ_RUNS=10000
export FUZZ_MAX_LEN=2048
export FUZZ_TIMEOUT=120
export BUILD_TYPE=Debug
export N_JOBS=$(nproc)
export CLEAN_BUILD=false
```

## 📊 출력 파일

퍼징 실행 후 다음 파일들이 생성됩니다:

```
fuzz_output/
├── corpus/               # 발견된 흥미로운 입력들
├── artifacts/            # 크래시, 리크, 타임아웃 등
├── fuzzer.log            # 퍼징 실행 로그
└── fuzzer_session.txt    # 세션 정보 (시작/종료 시간, 종료 코드)
```

## 🐛 디버깅 및 문제 해결

### 개별 스크립트 실패 시

각 스크립트는 에러 시 중단되며, 실패 단계를 명확히 표시합니다:

```bash
[ERROR] 단계 3 실패: 퍼징 타겟 설정
```

### 환경 변수 확인

```bash
# 현재 환경 변수 확인
cat .fuzz_env

# 또는 스크립트 내부 함수 사용
source Sources/shell/common.sh
print_env_summary
```

### 빌드 오류 디버깅

```bash
# CMake 캐시 완전 삭제
rm -rf fprime/build-fprime-automatic-native

# 빌드 재시도 (상세 로그)
export CLEAN_BUILD=true
source Sources/shell/04_build_fprime.sh
```

### 퍼저 수동 실행

```bash
# 빌드된 퍼저 직접 실행
./fprime/build-fprime-automatic-native/bin/CmdDispatcher_fuzz \
  ./fuzz_output/corpus \
  -max_len=1024 \
  -runs=1000 \
  -artifact_prefix=./fuzz_output/artifacts/
```

## 🔧 스크립트 수정 및 확장

### 새로운 컴포넌트 추가

1. `COMPONENT_NAME` 환경 변수 변경
2. `scripts/setup_fuzz_target.py` 지원 여부 확인
3. 필요시 `03_setup_fuzz_target.sh` 수정

### 퍼저 옵션 커스터마이징

`05_run_fuzzer.sh` 파일에서 `FUZZER_ARGS` 배열을 수정:

```bash
FUZZER_ARGS=(
    "${FUZZ_OUTPUT}/corpus"
    "-max_len=${FUZZ_MAX_LEN}"
    "-timeout=${FUZZ_TIMEOUT}"
    # 여기에 추가 옵션 추가
    "-use_value_profile=1"
    "-reduce_inputs=1"
)
```

### 공통 함수 추가

`common.sh`에 새로운 유틸리티 함수를 추가하면 모든 스크립트에서 사용 가능:

```bash
# common.sh에 추가
check_port() {
    local port="$1"
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        log_warning "포트 $port가 이미 사용 중입니다."
        return 1
    fi
    return 0
}
```

## 📚 참고 자료

- **SUMMARY.md**: 전체 전략 요약
- **setup_fuzz_target.py**: 퍼징 타겟 자동 생성 스크립트
- **SGFuzz 문서**: `SGFuzz/README.md`
- **F Prime 문서**: `fprime/docs/`

## 🎯 SUMMARY.md 단계 매핑

이 스크립트들은 `docs/SUMMARY.md`의 전략을 구현합니다:

| SUMMARY.md 단계 | 스크립트 |
|----------------|---------|
| 1. 퍼징 타겟 등록 | `03_setup_fuzz_target.sh` (CMakeLists.txt 생성) |
| 2. 소스 복사 + 계측 자동화 | `03_setup_fuzz_target.sh` (Python 스크립트 호출) |
| 3. 헤더 및 라이브러리 설정 | `03_setup_fuzz_target.sh` (CMakeLists.txt 내) |
| 4. 모듈 내부 조건부 포함 | `03_setup_fuzz_target.sh` (상위 CMake 수정) |
| 5. 빌드 & 실행 흐름 | `04_build_fprime.sh` + `05_run_fuzzer.sh` |
| 6. Docker 자동화 | `entrypoint.sh` + `Dockerfile.fsgfuzz` |

## ✅ 체크리스트

퍼징 실행 전 확인사항:

- [ ] Docker 또는 로컬 환경 준비 완료
- [ ] SGFuzz 서브모듈 업데이트 (`git submodule update --init --recursive`)
- [ ] F Prime 서브모듈 업데이트
- [ ] Clang/LLVM 설치 확인
- [ ] `COMPONENT_NAME` 환경 변수 설정
- [ ] 충분한 디스크 공간 확보 (최소 5GB)
- [ ] 퍼징 타겟 구현 코드 작성 (`*_fuzz.cpp`)

## 📞 문의

문제가 발생하면 다음을 확인하세요:

1. 로그 파일: `fuzz_output/fuzzer.log`
2. 환경 변수: `.fuzz_env`
3. 빌드 디렉토리: `fprime/build-fprime-automatic-native`
4. CMake 파일: `fprime/Svc/<COMPONENT>/fuzz/CMakeLists.txt`

