# 🚀 SGFuzz for F Prime - 빠른 시작 가이드

이 문서는 Docker를 사용하여 F Prime 컴포넌트를 자동으로 퍼징하는 가장 빠른 방법을 안내합니다.

## ⚡ 3분 만에 시작하기

### 1단계: 스크립트 실행

```bash
./quickstart.sh
```

이 명령 하나로 모든 것이 자동으로 실행됩니다:
- ✅ 환경 확인 (Docker, Git)
- ✅ 서브모듈 초기화
- ✅ Docker 이미지 빌드
- ✅ 퍼징 자동 실행

### 2단계: 결과 확인

퍼징이 실행되면 실시간으로 통계를 볼 수 있습니다:

```
#12345    NEW    cov: 156 ft: 234 corp: 45/12KB exec/s: 789 rss: 67Mb
```

- `cov`: 코드 커버리지
- `corp`: 발견한 고유 입력 수
- `exec/s`: 초당 실행 횟수

### 3단계: 크래시 확인

```bash
# 발견된 크래시 확인
ls -la fuzz_output/artifacts/

# 로그 확인
cat fuzz_output/fuzzer.log
```

## 🎯 주요 사용 시나리오

### 시나리오 1: 기본 퍼징 (무한 실행)

```bash
cd Sources/docker
docker-compose up fsgfuzz
```

종료: `Ctrl+C`

### 시나리오 2: 제한된 시간 퍼징

```bash
cd Sources/docker
docker-compose run -e FUZZ_RUNS=10000 fsgfuzz
```

### 시나리오 3: 큰 입력 테스트

```bash
cd Sources/docker
docker-compose run -e FUZZ_MAX_LEN=4096 fsgfuzz
```

### 시나리오 4: 병렬 퍼징

```bash
cd Sources/docker
docker-compose run -e FUZZ_WORKERS=4 fsgfuzz
```

### 시나리오 5: 수동 제어

```bash
# 컨테이너 셸 접속
cd Sources/docker
docker-compose run --entrypoint /bin/bash fsgfuzz

# 컨테이너 내부에서
cd /workspace/sgfuzz-for-fprime
./quickstart.sh  # 또는 수동으로 명령 실행
```

## 📊 결과 분석

### 파일 구조

```
fuzz_output/
├── corpus/              # 흥미로운 입력들
│   ├── 1a2b3c4d...
│   └── 2b3c4d5e...
├── artifacts/           # 문제 발견!
│   ├── crash-1a2b3c     # 크래시를 발생시킨 입력
│   ├── timeout-2b3c4d   # 타임아웃
│   └── leak-3c4d5e      # 메모리 누수
└── fuzzer.log           # 전체 로그
```

### 크래시 재현

```bash
# Docker 컨테이너 내부에서
./build-fprime-automatic-native/bin/CmdDispatcher_fuzz \
    /workspace/sgfuzz-for-fprime/fuzz_output/artifacts/crash-xyz123
```

### 통계 분석

```bash
# 로그에서 최종 통계 추출
grep "stat::" fuzz_output/fuzzer.log | tail -20
```

## 🔧 커스터마이징

### 다른 컴포넌트 퍼징

`docker-compose.yml` 수정:

```yaml
environment:
  - COMPONENT_NAME=ActiveLogger  # 원하는 컴포넌트로 변경
```

또는 명령줄에서:

```bash
docker-compose run -e COMPONENT_NAME=ActiveLogger fsgfuzz
```

### 퍼징 설정 조정

| 환경 변수 | 설명 | 기본값 |
|-----------|------|--------|
| `FUZZ_RUNS` | 총 실행 횟수 (0=무한) | 0 |
| `FUZZ_MAX_LEN` | 최대 입력 크기 | 1024 |
| `FUZZ_TIMEOUT` | 테스트케이스 타임아웃 | 60 |
| `FUZZ_WORKERS` | 병렬 워커 수 | 1 |

## 🐛 문제 해결

### Docker 빌드 실패

```bash
# 캐시 무시하고 재빌드
cd Sources/docker
docker-compose build --no-cache baseimage
docker-compose build --no-cache fsgfuzz
```

### 퍼저가 실행되지 않음

```bash
# 수동으로 단계별 실행
cd Sources/docker
docker-compose run --entrypoint /bin/bash fsgfuzz

# 컨테이너 내부에서
cd /workspace/sgfuzz-for-fprime

# 1. 퍼징 타겟 생성
python3 scripts/setup_fuzz_target.py --component CmdDispatcher

# 2. 빌드
cd fprime
fprime-util generate
fprime-util build --target CmdDispatcher_fuzz

# 3. 실행
cd ..
./fprime/build-fprime-automatic-native/bin/CmdDispatcher_fuzz
```

### 로그 확인

```bash
# 실시간 로그
cd Sources/docker
docker-compose logs -f fsgfuzz

# 퍼저 로그만
tail -f fuzz_output/fuzzer.log
```

## 📚 더 알아보기

- [DOCKER_GUIDE.md](Sources/docker/DOCKER_GUIDE.md) - Docker 상세 가이드
- [RESEARCH3.md](docs/RESEARCH3.md) - 기술 상세 문서
- [setup_fuzz_target.py](scripts/setup_fuzz_target.py) - 자동화 스크립트

## 💡 팁

### 효율적인 퍼징

1. **짧은 타임아웃으로 시작**: 먼저 `FUZZ_TIMEOUT=10`으로 빠른 버그 찾기
2. **병렬 실행**: CPU 코어 수만큼 워커 사용 (`FUZZ_WORKERS=4`)
3. **코퍼스 재사용**: 이전 `corpus/` 디렉토리 보관하여 다음 실행에 활용
4. **사전(Dictionary) 사용**: 프로토콜 키워드를 담은 사전 파일 활용

### 지속적 퍼징

```bash
# screen 또는 tmux 사용
screen -S fuzzing
./quickstart.sh
# Ctrl+A, D로 detach

# 나중에 다시 연결
screen -r fuzzing
```

### 결과 백업

```bash
# 중요한 발견을 백업
cp -r fuzz_output/ fuzz_results_$(date +%Y%m%d_%H%M%S)/
```

## 🎓 학습 리소스

- LibFuzzer 옵션: `./CmdDispatcher_fuzz -help=1`
- SGFuzz 논문: [Stateful Greybox Fuzzing](docs/Stateful%20Greybox%20Fuzzing.pdf)
- F Prime 문서: https://nasa.github.io/fprime/

---

**문제가 발생하면** GitHub Issues에 보고해주세요! 🙏

