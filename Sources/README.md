# SGFuzz for F Prime - 단순화된 구조

**이전 문제점:** 9개의 복잡한 쉘 스크립트 + Python 생성기  
**현재 해결:** 단 1개의 스크립트 + Dockerfile COPY

---

## 📁 디렉토리 구조

```
Sources/
├── docker/
│   ├── Dockerfile.baseImage    # 캐싱용 (환경 설정)
│   └── Dockerfile.fsgfuzz       # 변경사항 COPY
├── run_fuzz.sh                  # ⭐ 단일 퍼징 스크립트!
├── generator/
│   └── setup_fuzz_target.py     # (선택) 로컬에서 fuzz 폴더 생성
└── README.md                    # 이 파일
```

---

## 🚀 사용법

### 1. fuzz 폴더 작성 (로컬에서)

```bash
# fuzz 폴더가 없는 경우, 직접 생성하거나 generator 사용
python3 Sources/generator/setup_fuzz_target.py --path fprime/Svc/CmdDispatcher

# 생성된 파일들:
# fprime/Svc/CmdDispatcher/fuzz/
# ├── CMakeLists.txt
# ├── CmdDispatcher_fuzz.cpp    ← 여기서 퍼징 로직 작성
# └── README.md
```

### 2. fuzz 코드 작성/수정

`fprime/Svc/CmdDispatcher/fuzz/CmdDispatcher_fuzz.cpp`에서 실제 퍼징 로직을 작성합니다.

### 3. Docker 빌드 & 실행

```bash
# Docker Compose로 실행 (권장)
docker-compose up --build fsgfuzz

# 또는 직접 Docker 실행
docker build -f Sources/docker/Dockerfile.baseImage -t baseimage:latest .
docker build -f Sources/docker/Dockerfile.fsgfuzz -t fsgfuzz:latest .
docker run -it fsgfuzz:latest
```

---

## ⚙️ 환경 변수

`docker-compose.yml`이나 `docker run -e`로 오버라이드 가능:

| 환경 변수 | 기본값 | 설명 |
|----------|--------|------|
| `COMPONENT_NAME` | `CmdDispatcher` | 타겟 컴포넌트 이름 |
| `FUZZ_RUNS` | `0` | 퍼징 실행 횟수 (0=무한) |
| `FUZZ_MAX_LEN` | `1024` | 최대 입력 크기 |
| `FUZZ_TIMEOUT` | `60` | 타임아웃(초) |

예시:
```yaml
# docker-compose.yml
services:
  fsgfuzz:
    environment:
      - FUZZ_RUNS=10000
      - FUZZ_MAX_LEN=2048
```

---

## 🔍 run_fuzz.sh가 하는 일

단일 스크립트가 모든 것을 처리합니다:

1. **F Prime Generate**
   - CMake 메타데이터 생성
   - 빌드 시스템 설정

2. **초기 빌드**
   - 자동 생성 코드 생성 (*ComponentAc.hpp 등)

3. **SGFuzz 계측**
   - `State_machine_instrument.py` 실행
   - enum 값에 `__sfuzzer_instrument()` 자동 삽입

4. **최종 빌드**
   - 계측된 코드로 퍼저 빌드

5. **퍼징 실행**
   - LibFuzzer 기반 퍼징 수행
   - 결과를 `fuzz_output/`에 저장

---

## 📂 출력 결과

```
fuzz_output/
├── corpus/          # 발견된 흥미로운 입력들
├── artifacts/       # 크래시/리크/타임아웃 케이스
├── crashes/         # 크래시 입력
└── fuzzer.log       # 퍼징 로그
```

---

## 🛠️ 디버깅

### 로그 확인
```bash
docker logs <container_id>
```

### 컨테이너 내부 접속
```bash
docker exec -it <container_id> /bin/bash
```

### 수동 실행 (컨테이너 내부)
```bash
/workspace/run_fuzz.sh
```

---

## 💡 핵심 개선사항

### Before (복잡함 😵)
```
9개 쉘 스크립트:
- 01_setup_environment.sh
- 02_check_dependencies.sh
- 03_setup_fuzz_target.sh (Python 호출)
- 04_generate_fprime.sh
- 05_sgfuzz_instrument.sh
- 06_build_fprime.sh
- 07_run_fuzzer.sh
- common.sh
- entrypoint.sh
+ Python 생성기
+ 환경 변수 파일 관리
```

### After (단순함 😊)
```
1개 쉘 스크립트:
- run_fuzz.sh (150줄, 모든 로직 포함)
+ Dockerfile COPY로 파일 관리
+ 명확한 환경 변수
```

---

## 🎯 장점

✅ **추적 가능**: 모든 로직이 하나의 파일에  
✅ **디버깅 쉬움**: 단일 스크립트만 보면 됨  
✅ **캐싱 최적화**: baseimage로 불변 환경 캐싱  
✅ **유연함**: 환경 변수로 쉽게 커스터마이징  
✅ **버전 관리**: 로컬 fuzz 코드 직접 작성/관리  

---

## 📝 참고 사항

- fuzz 폴더는 **반드시 로컬에 존재**해야 Docker 빌드 성공
- Python generator는 선택사항 (로컬에서 fuzz 폴더 생성용)
- 계측 스크립트는 SGFuzz에 포함되어 있으며, 필요시 COPY로 업데이트

---

**문제 발생 시:**
1. `run_fuzz.sh`를 확인 (모든 로직이 여기 있음)
2. Dockerfile의 COPY 경로 확인
3. 환경 변수 확인

