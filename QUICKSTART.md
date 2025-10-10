# SGFuzz for F Prime - 빠른 시작 가이드 (모듈화 버전)

이 가이드는 모듈화된 스크립트를 사용하여 F Prime에 SGFuzz를 빠르게 적용하는 방법을 설명합니다.

## 🚀 5분 안에 시작하기

### 전제 조건

- Docker 및 Docker Compose 설치
- Git 설치
- 최소 4GB RAM 및 10GB 디스크 공간

### 단계 1: 저장소 클론

```bash
git clone https://github.com/seunghyeoks/sgfuzz-for-fprime.git
cd sgfuzz-for-fprime
git submodule update --init --recursive
```

### 단계 2: Docker로 실행

```bash
cd Sources/docker
docker-compose up --build fsgfuzz
```

**완료!** 퍼저가 자동으로 실행되고, 결과는 `fuzz_output/` 디렉토리에 저장됩니다.

---

## 📂 새로운 모듈화 구조

SUMMARY.md의 전략을 기반으로 각 단계를 독립적인 스크립트로 분리했습니다:

```
Sources/shell/
├── common.sh                    # 공통 함수 및 유틸리티
├── 01_setup_environment.sh      # 환경 변수 설정
├── 02_check_dependencies.sh     # 의존성 확인 (도구 + SGFuzz)
├── 03_setup_fuzz_target.sh      # 퍼징 타겟 생성
├── 04_build_fprime.sh           # F Prime 빌드
├── 05_run_fuzzer.sh             # 퍼저 실행
└── entrypoint.sh                # 전체 오케스트레이션
```

### 장점

✅ **모듈화**: 각 단계를 독립적으로 실행/디버깅 가능  
✅ **재사용성**: 환경 변수를 파일에 저장하여 재사용  
✅ **유지보수성**: 단계별로 쉽게 수정 및 확장  
✅ **디버깅**: 실패한 단계만 다시 실행 가능  

---

## 🎯 사용 사례

### 사례 1: 전체 파이프라인 실행 (기본)

```bash
# Docker Compose 사용 (권장)
cd Sources/docker
docker-compose up --build fsgfuzz
```

### 사례 2: 특정 단계만 재실행

```bash
# 컨테이너 접속
docker exec -it fsgfuzz /bin/bash

# 환경 변수 로드
source /workspace/sgfuzz-for-fprime/.fuzz_env

# 빌드만 다시 실행
source /usr/local/bin/fuzz_scripts/04_build_fprime.sh

# 퍼저만 다시 실행
source /usr/local/bin/fuzz_scripts/05_run_fuzzer.sh
```

### 사례 3: 로컬에서 단계별 실행

```bash
# 환경 변수 설정
source Sources/shell/01_setup_environment.sh

# 의존성 확인
source Sources/shell/02_check_dependencies.sh

# 퍼징 타겟 설정
source Sources/shell/03_setup_fuzz_target.sh

# 빌드
source Sources/shell/04_build_fprime.sh

# 퍼저 실행
source Sources/shell/05_run_fuzzer.sh
```

### 사례 4: 다른 컴포넌트 퍼징

```bash
# 환경 변수 설정 후 실행
export COMPONENT_NAME=ActiveLogger
docker-compose run -e COMPONENT_NAME=ActiveLogger fsgfuzz
```

---

## ⚙️ 환경 변수 커스터마이징

`Sources/docker/docker-compose.yml` 파일에서 설정을 변경하세요:

```yaml
environment:
  - COMPONENT_NAME=CmdDispatcher      # 타겟 컴포넌트
  - FUZZ_RUNS=0                       # 실행 횟수 (0=무한)
  - FUZZ_MAX_LEN=1024                 # 최대 입력 크기
  - FUZZ_TIMEOUT=60                   # 타임아웃(초)
  - FUZZ_WORKERS=1                    # 워커 수
  - BUILD_TYPE=Testing                # CMake 빌드 타입
  - N_JOBS=4                          # 병렬 빌드 작업 수
  - CLEAN_BUILD=true                  # 빌드 디렉토리 정리 여부
  - KEEP_ALIVE=false                  # 퍼징 후 대기 여부
```

---

## 📊 결과 확인

퍼징 실행 후 다음 위치에서 결과를 확인하세요:

```
fuzz_output/
├── corpus/               # 발견된 흥미로운 입력들
├── artifacts/            # 크래시, 리크, 타임아웃 등
│   ├── crash-*           # 크래시를 유발한 입력
│   ├── leak-*            # 메모리 누수를 유발한 입력
│   └── timeout-*         # 타임아웃을 유발한 입력
├── fuzzer.log            # 퍼징 실행 로그
└── fuzzer_session.txt    # 세션 정보
```

### 크래시 재현

```bash
# 컨테이너 내부에서
./fprime/build-fprime-automatic-native/bin/CmdDispatcher_fuzz \
  fuzz_output/artifacts/crash-abc123
```

---

## 🐛 트러블슈팅

### 문제: 빌드 실패

```bash
# 캐시 없이 재빌드
docker-compose build --no-cache baseimage
docker-compose build --no-cache fsgfuzz
```

### 문제: SGFuzz 라이브러리 누락

```bash
# 컨테이너 내부에서 수동 빌드
docker exec -it fsgfuzz /bin/bash
source /usr/local/bin/fuzz_scripts/02_check_dependencies.sh
```

### 문제: 특정 단계 실패

각 스크립트는 에러 메시지와 디버깅 팁을 제공합니다:

```bash
[ERROR] 단계 3 실패: 퍼징 타겟 설정

디버깅 팁:
  1. setup_fuzz_target.py 로그 확인
  2. 컴포넌트 경로 확인: /workspace/sgfuzz-for-fprime/fprime/Svc/CmdDispatcher
  3. CMakeLists.txt 구문 오류 확인
```

---

## 📚 자세한 문서

- **[Sources/shell/README.md](Sources/shell/README.md)** - 스크립트 상세 가이드
- **[Sources/docker/DOCKER_GUIDE.md](Sources/docker/DOCKER_GUIDE.md)** - Docker 사용 가이드
- **[docs/SUMMARY.md](docs/SUMMARY.md)** - 전략 요약
- **[docs/RESEARCH3.md](docs/RESEARCH3.md)** - 기술 세부사항

---

## 🎓 학습 경로

1. **초보자**: `docker-compose up`으로 바로 시작
2. **중급자**: 환경 변수 커스터마이징, 로그 분석
3. **고급자**: 개별 스크립트 수정, 새 컴포넌트 추가

---

## 📞 문제 발생 시

1. 로그 확인: `fuzz_output/fuzzer.log`
2. 환경 변수 확인: `cat .fuzz_env`
3. 컨테이너 로그: `docker-compose logs -f fsgfuzz`
4. 개별 단계 재실행으로 문제 격리

---

## ✅ 성공 확인

퍼저가 정상 실행되면 다음과 같은 출력을 볼 수 있습니다:

```
========================================
  퍼저 실행 정보
========================================
  실행 파일: /workspace/sgfuzz-for-fprime/fprime/build-.../CmdDispatcher_fuzz
  컴포넌트: CmdDispatcher

  옵션:
    - 최대 입력 크기: 1024 bytes
    - 실행 횟수: 0 (무한)
    - 타임아웃: 60초
    - 워커 수: 1

  출력:
    - corpus: /workspace/sgfuzz-for-fprime/fuzz_output/corpus
    - artifacts: /workspace/sgfuzz-for-fprime/fuzz_output/artifacts
========================================

INFO: Running with entropic power schedule (0xFF, 100).
INFO: Seed: 1234567890
INFO: -max_len is not provided; libFuzzer will not generate inputs larger than 1024 bytes
...
```

축하합니다! 🎉 퍼징이 실행 중입니다.

---

**다음 단계**: 발견된 크래시를 분석하고 수정하세요!

