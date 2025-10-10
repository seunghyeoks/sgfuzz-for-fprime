# SGFuzz for F Prime - Docker 사용 가이드

이 가이드는 Docker를 사용하여 F Prime의 CmdDispatcher 컴포넌트를 자동으로 퍼징하는 방법을 설명합니다.

## 📋 사전 요구사항

- Docker 및 Docker Compose 설치
- 최소 4GB RAM
- 충분한 디스크 공간 (최소 10GB 권장)

## 🏗️ Docker 이미지 구조

### **baseimage (베이스 이미지)**
- **역할**: F Prime 및 SGFuzz 기본 환경 구축
- **포함 내용**:
  - Ubuntu 22.04 + 개발 도구 (clang, cmake, python3)
  - F Prime 프레임워크 (main 브랜치)
  - SGFuzz 라이브러리 빌드
  - F Prime 전체 빌드 (fuzz 제외)
- **빌드 빈도**: 드물게 (의존성 변경 시에만)

### **fsgfuzz (작업 이미지)**
- **역할**: 최신 코드 + 퍼징 타겟 설정
- **주요 작업**:
  1. 원하는 브랜치로 전환 (기본값: try)
  2. 최신 코드 pull
  3. 퍼징 스크립트 복사
  4. **기존 빌드 디렉토리 삭제** ← 중요!
  5. 퍼징 파이프라인 실행
- **빌드 빈도**: 자주 (코드 변경마다)

### **왜 빌드 디렉토리를 삭제하나?**
```
BaseImage: fprime-util generate && build
→ fuzz 없이 빌드됨
→ 오토코더 파일 생성 안 됨

fsgfuzz: fuzz 디렉토리 추가
→ 빌드 디렉토리 삭제 필요
→ generate 재실행으로 오토코더 파일 생성
→ 정상 빌드
```

## 🚀 빠른 시작

### 1. Docker 이미지 빌드 및 실행

```bash
# 프로젝트 루트로 이동
cd /Users/BookShelf/Developer/sgfuzz-for-fprime/Sources/docker

# 베이스 이미지 빌드 (최초 1회, 시간 소요)
docker-compose build baseimage

# 퍼징 컨테이너 빌드 및 실행
docker-compose up --build fsgfuzz
```

### 2. 실행 과정

컨테이너가 시작되면 모듈화된 스크립트들이 순차적으로 실행됩니다:

1. ✅ **환경 변수 설정** (`01_setup_environment.sh`)
2. ✅ **의존성 확인** (`02_check_dependencies.sh`)
   - 필수 도구 확인 (fprime-util, clang, python3)
   - SGFuzz 라이브러리 확인/빌드
3. ✅ **퍼징 타겟 설정** (`03_setup_fuzz_target.sh`)
   - setup_fuzz_target.py 실행
   - CMakeLists.txt 및 퍼저 엔트리포인트 생성
4. ✅ **F Prime 빌드** (`04_build_fprime.sh`)
   - fprime-util generate
   - fprime-util build --target CmdDispatcher_fuzz
5. ✅ **퍼저 실행** (`05_run_fuzzer.sh`)
   - LibFuzzer 실행 및 로그 수집
6. ✅ **결과 요약 출력**

각 스크립트는 `Sources/shell/` 디렉토리에 모듈화되어 있습니다.

### 3. 결과 확인

퍼징 결과는 호스트의 `fuzz_output/` 디렉토리에 저장됩니다:

```bash
# 프로젝트 루트의 fuzz_output 디렉토리
fuzz_output/
├── corpus/          # 발견된 흥미로운 입력
├── crashes/         # (미사용)
├── artifacts/       # 크래시, 타임아웃, 메모리 누수 등
└── fuzzer.log       # 퍼징 로그
```

## ⚙️ 환경 변수 설정

`docker-compose.yml` 파일의 `environment` 섹션에서 설정을 변경할 수 있습니다:

```yaml
environment:
  - COMPONENT_NAME=CmdDispatcher      # 타겟 컴포넌트
  - FUZZ_RUNS=0                       # 실행 횟수 (0=무한)
  - FUZZ_MAX_LEN=1024                 # 최대 입력 크기
  - FUZZ_TIMEOUT=60                   # 타임아웃(초)
  - FUZZ_WORKERS=1                    # 워커 수
  - KEEP_ALIVE=false                  # 완료 후 대기
```

### 환경 변수 설명

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `COMPONENT_NAME` | 퍼징 대상 컴포넌트 이름 | `CmdDispatcher` |
| `FUZZ_RUNS` | 실행 횟수 (0=무한) | `0` |
| `FUZZ_MAX_LEN` | 최대 입력 크기 (bytes) | `1024` |
| `FUZZ_TIMEOUT` | 단일 테스트케이스 타임아웃 (초) | `60` |
| `FUZZ_WORKERS` | 병렬 실행 워커 수 | `1` |
| `KEEP_ALIVE` | 퍼징 완료 후 컨테이너 유지 | `false` |

## 🎯 고급 사용법

### 커스텀 설정으로 실행

```bash
# 환경 변수를 직접 지정하여 실행
docker-compose run -e FUZZ_RUNS=10000 -e FUZZ_MAX_LEN=2048 fsgfuzz
```

### 컨테이너 내부 접근

```bash
# 실행 중인 컨테이너에 접속
docker exec -it fsgfuzz /bin/bash

# 수동으로 퍼저 실행
cd /workspace/sgfuzz-for-fprime
./build-fprime-automatic-native/bin/CmdDispatcher_fuzz -help=1
```

### 로그 확인

```bash
# 실시간 로그 확인
docker-compose logs -f fsgfuzz

# 퍼징 로그 파일 확인
tail -f fuzz_output/fuzzer.log
```

### 정지 및 재시작

```bash
# 퍼징 중지 (Ctrl+C 또는)
docker-compose down

# 재시작
docker-compose up fsgfuzz
```

## 🐛 트러블슈팅

### 빌드 실패

```bash
# 캐시 없이 재빌드
docker-compose build --no-cache baseimage
docker-compose build --no-cache fsgfuzz
```

### SGFuzz 라이브러리 누락

```bash
# 컨테이너 내부에서 수동 빌드
docker exec -it fsgfuzz /bin/bash
cd /workspace/sgfuzz-for-fprime/SGFuzz
./build.sh
```

### fprime-util 오류

```bash
# 컨테이너 내부에서 수동 빌드
docker exec -it fsgfuzz /bin/bash
cd /workspace/sgfuzz-for-fprime/fprime
fprime-util generate
fprime-util build
```

### 퍼저 실행 파일을 찾을 수 없음

```bash
# 빌드 디렉토리 확인
find /workspace/sgfuzz-for-fprime/fprime/build-fprime-automatic-native -name "CmdDispatcher_fuzz"
```

## 📊 퍼징 결과 분석

### 크래시 재현

발견된 크래시를 재현하려면:

```bash
# 크래시 파일로 재실행
./CmdDispatcher_fuzz fuzz_output/artifacts/crash-xyz123
```

### 코퍼스 최소화

```bash
# 코퍼스 크기 줄이기
./CmdDispatcher_fuzz -merge=1 minimized_corpus/ fuzz_output/corpus/
```

### 커버리지 분석

```bash
# 커버리지 계산용 재빌드 필요
# (Dockerfile.baseImage에 LLVM coverage 도구 추가 필요)
```

## 🔧 개발자용

### 스크립트 구조

모듈화된 스크립트 구조:
```
Sources/shell/
├── common.sh                    # 공통 함수 (로깅, 유틸리티)
├── 01_setup_environment.sh      # 환경 변수 설정
├── 02_check_dependencies.sh     # 의존성 확인
├── 03_setup_fuzz_target.sh      # 퍼징 타겟 생성
├── 04_build_fprime.sh           # F Prime 빌드
├── 05_run_fuzzer.sh             # 퍼저 실행
└── entrypoint.sh                # 메인 오케스트레이터
```

자세한 내용은 `Sources/shell/README.md`를 참조하세요.

### 개별 단계 실행

컨테이너 내부에서 특정 단계만 다시 실행할 수 있습니다:

```bash
# 컨테이너 접속
docker exec -it fsgfuzz /bin/bash

# 환경 변수 로드
source /workspace/sgfuzz-for-fprime/.fuzz_env

# 특정 단계만 실행
source /usr/local/bin/fuzz_scripts/04_build_fprime.sh
source /usr/local/bin/fuzz_scripts/05_run_fuzzer.sh
```

### entrypoint.sh 수정

컨테이너 시작 동작을 변경하려면 `Sources/shell/entrypoint.sh` 또는 개별 스크립트를 수정하세요.

### 다른 컴포넌트 퍼징

```bash
# docker-compose.yml에서 COMPONENT_NAME 변경
environment:
  - COMPONENT_NAME=ActiveLogger  # 예시
```

또는:

```bash
# 명령줄에서 직접 지정
docker-compose run -e COMPONENT_NAME=ActiveLogger fsgfuzz
```

## 📚 참고 자료

- [SUMMARY.md](../../docs/SUMMARY.md) - F Prime + SGFuzz 통합 전략 요약
- [shell/README.md](../shell/README.md) - 자동화 스크립트 가이드
- [RESEARCH3.md](../../docs/RESEARCH3.md) - 상세 기술 문서
- [SGFuzz GitHub](https://github.com/bajinsheng/SGFuzz) - SGFuzz 공식 저장소
- [F Prime Documentation](https://nasa.github.io/fprime/) - F Prime 공식 문서

## 📝 라이센스

이 프로젝트는 F Prime 및 SGFuzz의 라이센스를 따릅니다.

