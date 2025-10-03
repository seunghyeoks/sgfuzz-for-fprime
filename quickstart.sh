#!/bin/bash
# SGFuzz for F Prime - 빠른 시작 스크립트

set -e

# 색상 코드
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "=========================================="
echo "  SGFuzz for F Prime"
echo "  빠른 시작 스크립트"
echo "  Engine: SGFuzz (Stateful Greybox Fuzzer)"
echo "=========================================="
echo -e "${NC}"

# 프로젝트 루트 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${GREEN}[1/5]${NC} 환경 확인 중..."

# Docker 확인
if ! command -v docker &> /dev/null; then
    echo "❌ Docker가 설치되어 있지 않습니다."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose가 설치되어 있지 않습니다."
    exit 1
fi

echo "✅ Docker 환경 확인 완료"

# 서브모듈 초기화
echo -e "${GREEN}[2/5]${NC} Git 서브모듈 초기화 중..."
if [ -d ".git" ]; then
    git submodule update --init --recursive
    echo "✅ 서브모듈 초기화 완료"
else
    echo "⚠️  Git 저장소가 아닙니다. 서브모듈 초기화를 건너뜁니다."
fi

# 출력 디렉토리 생성
echo -e "${GREEN}[3/5]${NC} 출력 디렉토리 생성 중..."
mkdir -p fuzz_output/corpus
mkdir -p fuzz_output/artifacts
echo "✅ 출력 디렉토리 생성 완료"

# Docker 이미지 빌드
echo -e "${GREEN}[4/5]${NC} Docker 이미지 빌드 중..."
echo "⏳ 이 작업은 처음 실행 시 시간이 오래 걸릴 수 있습니다 (약 10-20분)"
cd Sources/docker

# baseimage 빌드
if ! docker images | grep -q "baseimage.*latest"; then
    echo "📦 베이스 이미지 빌드 중..."
    docker-compose build baseimage
else
    echo "✅ 베이스 이미지가 이미 존재합니다."
fi

# fsgfuzz 빌드
echo "📦 퍼징 이미지 빌드 중..."
docker-compose build fsgfuzz

echo "✅ Docker 이미지 빌드 완료"

# 실행 옵션 선택
echo ""
echo -e "${GREEN}[5/5]${NC} 실행 옵션을 선택하세요:"
echo "  1) 바로 실행 (기본 설정)"
echo "  2) 커스텀 설정으로 실행"
echo "  3) 컨테이너 셸 접속만 하기"
echo "  4) 종료"
echo ""
read -p "선택 (1-4): " choice

case $choice in
    1)
        echo -e "${BLUE}퍼징을 시작합니다...${NC}"
        docker-compose up fsgfuzz
        ;;
    2)
        echo ""
        read -p "실행 횟수 (0=무한, 기본=0): " runs
        read -p "최대 입력 크기 (기본=1024): " maxlen
        read -p "타임아웃 초 (기본=60): " timeout
        
        runs=${runs:-0}
        maxlen=${maxlen:-1024}
        timeout=${timeout:-60}
        
        echo -e "${BLUE}커스텀 설정으로 퍼징을 시작합니다...${NC}"
        docker-compose run \
            -e FUZZ_RUNS=$runs \
            -e FUZZ_MAX_LEN=$maxlen \
            -e FUZZ_TIMEOUT=$timeout \
            fsgfuzz
        ;;
    3)
        echo -e "${BLUE}컨테이너 셸에 접속합니다...${NC}"
        docker-compose run --entrypoint /bin/bash fsgfuzz
        ;;
    4)
        echo "종료합니다."
        exit 0
        ;;
    *)
        echo "잘못된 선택입니다."
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}=========================================="
echo "  완료!"
echo "==========================================${NC}"
echo ""
echo "✅ SGFuzz + AddressSanitizer 빌드 완료"
echo ""
echo "퍼징 결과는 다음 위치에 저장됩니다:"
echo "  📁 $SCRIPT_DIR/fuzz_output/"
echo "    - corpus/     : 생성된 테스트 케이스"
echo "    - artifacts/  : 발견된 크래시/버그"
echo "    - fuzzer.log  : 퍼징 로그"
echo ""
echo "추가 명령어:"
echo "  - 로그 확인: cd Sources/docker && docker-compose logs -f fsgfuzz"
echo "  - 정지: cd Sources/docker && docker-compose down"
echo "  - 재시작: cd Sources/docker && docker-compose up fsgfuzz"
echo ""
echo "💡 참고:"
echo "  - SGFuzz 라이브러리 사용 중 (SM 모듈 포함)"
echo "  - 상태 계측은 비활성화 (기본 커버리지 기반 퍼징)"
echo "  - 상태 계측을 활성화하려면 USE_STATE_INSTRUMENTATION=true 설정"
echo ""

