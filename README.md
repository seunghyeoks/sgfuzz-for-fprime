# SGFuzz for F Prime

F Prime에 SGFuzz를 적용하여 자동 퍼징을 수행하는 프로젝트입니다. Docker 환경을 사용합니다.

## 🚀 빠른 시작

이 레포지토리를 클론한 후:

```bash
cd Sources/docker; 
docker-compose build --no-cache fsgfuzz; 
docker-compose up fsgfuzz
```

 퍼저가 자동으로 실행되고, 결과는 `fuzz_output/` 디렉토리에 저장됩니다.

## ⚙️ 환경 변수 설정

`Sources/docker/docker-compose.yml` 파일에서 설정을 변경할 수 있습니다:

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
