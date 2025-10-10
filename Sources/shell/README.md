## File Structure

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
