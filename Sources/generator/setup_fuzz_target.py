#!/usr/bin/env python3
"""
SGFuzz 퍼징 타겟 자동 생성 스크립트
F Prime 컴포넌트를 위한 퍼징 하네스를 자동으로 생성합니다.
"""

import os
import sys
import argparse
import shutil
from pathlib import Path
from datetime import datetime


def get_project_root():
    """프로젝트 루트 디렉토리 반환"""
    # 스크립트가 Sources/generator/ 안에 있으므로 두 단계 위로 올라감
    script_dir = Path(__file__).resolve().parent  # Sources/generator
    sources_dir = script_dir.parent                # Sources
    return sources_dir.parent                      # 프로젝트 루트


def create_fuzz_directory(component_path):
    """퍼징 타겟 디렉토리 생성"""
    fuzz_dir = component_path / "fuzz"
    fuzz_dir.mkdir(exist_ok=True)
    print(f"✅ 퍼징 디렉토리 생성: {fuzz_dir}")
    return fuzz_dir


def generate_cmake_lists(fuzz_dir, component_name, project_root, component_path):
    """RESEARCH3.md의 수정안 기반 CMakeLists.txt 생성"""
    
    # .fpp 파일 찾기
    parent_dir = fuzz_dir.parent
    fpp_files = list(parent_dir.glob("*.fpp"))
    
    if not fpp_files:
        print(f"⚠️  경고: {component_name}.fpp 파일을 찾을 수 없습니다.")
        print(f"   디렉토리: {parent_dir}")
        fpp_input = f"../{component_name}.fpp"
    else:
        fpp_file = fpp_files[0]
        print(f"✅ FPP 파일 발견: {fpp_file.name}")
        fpp_input = f"../{fpp_file.name}"
    
    cmake_content = f'''# Auto-generated CMakeLists.txt for {component_name} fuzzing target
# Generated at: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

option(ENABLE_FUZZ "Build fuzz targets" ON)

# SGFUZZ_ROOT 경로 설정 (명령줄에서 전달되지 않은 경우에만 기본값 사용)
if(NOT DEFINED SGFUZZ_ROOT)
    # 기본값: CMAKE_SOURCE_DIR의 상위 디렉토리에서 SGFuzz 찾기
    set(SGFUZZ_ROOT "${{CMAKE_SOURCE_DIR}}/../SGFuzz" CACHE PATH "SGFuzz library path")
    message(STATUS "SGFUZZ_ROOT not provided, using default: ${{SGFUZZ_ROOT}}")
else()
    message(STATUS "Using provided SGFUZZ_ROOT: ${{SGFUZZ_ROOT}}")
endif()

if(ENABLE_FUZZ)
  message(STATUS "Configuring fuzz target for {component_name}")

  # 상위 스코프에서 설정된 역사적 변수 제거 (신규 API와 혼용 금지)
  unset(SOURCE_FILES)
  unset(MOD_DEPS)
  unset(UT_SOURCE_FILES)
  unset(EXECUTABLE_NAME)

  # 플랫폼 의존 링크 항목 구성
  set(EXTRA_DEPS "${{SGFUZZ_ROOT}}/libsfuzzer.a" pthread)
  if(NOT APPLE)
    list(APPEND EXTRA_DEPS dl)
  endif()

  # 퍼징 실행 파일 등록
  # AUTOCODER_INPUTS로 원본 컴포넌트의 .fpp 파일을 지정하여 오토코더 실행
  register_fprime_executable(
    {component_name}_fuzz
    SOURCES
      "${{CMAKE_CURRENT_LIST_DIR}}/{component_name}_fuzz.cpp"  # LibFuzzer 엔트리포인트
    AUTOCODER_INPUTS
      "${{CMAKE_CURRENT_LIST_DIR}}/{fpp_input}"                # 원본 .fpp로 오토코더 실행
    DEPENDS
      Svc/{component_name}  # 원본 컴포넌트 구현 링크
      ${{EXTRA_DEPS}}       # SGFuzz 라이브러리 및 기타 의존성
  )

  # 원본 컴포넌트가 먼저 빌드되도록 명시적 의존성 추가
  if(TARGET Svc_{component_name})
    add_dependencies({component_name}_fuzz Svc_{component_name})
    message(STATUS "  - Build dependency: Svc_{component_name} will be built first")
  endif()

  # 컴파일 및 링크 옵션 설정
  target_compile_options({component_name}_fuzz PRIVATE 
    -fsanitize=fuzzer-no-link  # LibFuzzer 메인 중복 방지
    -g                         # 디버그 심볼
    -O1                        # 최소 최적화
  )
  
  target_link_options({component_name}_fuzz PRIVATE 
    -fsanitize=fuzzer-no-link
  )

  # SGFuzz 헤더 경로 추가
  target_include_directories({component_name}_fuzz PRIVATE 
    "${{SGFUZZ_ROOT}}"
    "${{SGFUZZ_ROOT}}/include"
  )

  message(STATUS "Fuzz target {component_name}_fuzz configured successfully")
  message(STATUS "  - Using original component: Svc/{component_name}")
  message(STATUS "  - SGFuzz library: ${{SGFUZZ_ROOT}}/libsfuzzer.a")
else()
  message(STATUS "Fuzzing disabled for {component_name}")
endif()
'''
    
    cmake_path = fuzz_dir / "CMakeLists.txt"
    with open(cmake_path, 'w') as f:
        f.write(cmake_content)
    
    print(f"✅ CMakeLists.txt 생성: {cmake_path}")
    return cmake_path


def generate_fuzzer_entrypoint(fuzz_dir, component_name):
    """LibFuzzer 엔트리포인트 생성 (템플릿)"""
    
    entrypoint_content = f'''/**
 * SGFuzz 퍼징 타겟 엔트리포인트
 * Component: {component_name}
 * Generated at: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
 */

#include <cstdint>
#include <cstddef>
#include <cstring>

// F Prime 헤더
#include <Fw/Types/BasicTypes.hpp>
#include <Fw/Com/ComBuffer.hpp>
#include <Fw/Cmd/CmdString.hpp>
#include <Svc/CmdDispatcher/CommandDispatcherImpl.hpp>

// SGFuzz 헤더 (상태 추적용)
#include "FuzzerStateMachine.h"

// 전역 컴포넌트 인스턴스 (재사용)
static Svc::CommandDispatcherImpl* g_dispatcher = nullptr;
static bool g_initialized = false;

/**
 * 초기화 함수 - 퍼징 세션당 한 번만 실행
 */
static void InitializeComponent() {{
    if (g_initialized) return;
    
    // CommandDispatcher 인스턴스 생성
    g_dispatcher = new Svc::CommandDispatcherImpl("FuzzDispatcher");
    
    // TODO: 필요한 포트 연결 및 초기화
    // g_dispatcher->init(queueDepth);
    
    g_initialized = true;
}}

/**
 * LibFuzzer 엔트리포인트
 * 
 * @param Data 퍼저가 생성한 입력 바이트 배열
 * @param Size 입력 크기
 * @return 0 (정상 종료)
 */
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {{
    // 최소/최대 입력 크기 체크
    if (Size < 4 || Size > 1024) {{
        return 0;
    }}

    // 컴포넌트 초기화 (첫 실행시만)
    InitializeComponent();

    // 입력 데이터를 Fw::ComBuffer로 변환
    Fw::ComBuffer comBuffer;
    Fw::SerializeStatus status = comBuffer.setBuff(Data, Size);
    
    if (status != Fw::FW_SERIALIZE_OK) {{
        return 0;
    }}

    // TODO: 실제 퍼징 로직 구현
    // 예: seqCmdBuff 포트 호출
    // g_dispatcher->seqCmdBuff_handler(0, comBuffer);

    return 0;
}}

/**
 * (선택사항) 초기화 함수 - 퍼저 시작 시 한 번 호출
 */
extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv) {{
    // 전역 초기화 작업
    return 0;
}}
'''
    
    entrypoint_path = fuzz_dir / f"{component_name}_fuzz.cpp"
    with open(entrypoint_path, 'w') as f:
        f.write(entrypoint_content)
    
    print(f"✅ 퍼저 엔트리포인트 생성: {entrypoint_path}")
    return entrypoint_path


def patch_parent_cmake(component_path, component_name):
    """상위 CMakeLists.txt에 add_subdirectory(fuzz) 추가"""
    
    parent_cmake = component_path / "CMakeLists.txt"
    
    if not parent_cmake.exists():
        print(f"⚠️  상위 CMakeLists.txt를 찾을 수 없습니다: {parent_cmake}")
        return False
    
    # 백업 생성
    backup_path = parent_cmake.with_suffix('.txt.backup')
    shutil.copy2(parent_cmake, backup_path)
    print(f"📦 백업 생성: {backup_path}")
    
    # 기존 내용 읽기
    with open(parent_cmake, 'r') as f:
        content = f.read()
    
    # 이미 fuzz 서브디렉토리가 추가되어 있는지 확인
    if 'add_subdirectory(fuzz)' in content or 'add_subdirectory( fuzz )' in content:
        print(f"ℹ️  이미 fuzz 서브디렉토리가 등록되어 있습니다.")
        return True
    
    # 파일 끝에 조건부 추가
    fuzz_addition = f'''
# ========================================
# SGFuzz 퍼징 타겟 (자동 생성)
# Generated at: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
# ========================================
if(EXISTS "${{CMAKE_CURRENT_LIST_DIR}}/fuzz/CMakeLists.txt")
    message(STATUS "Including fuzz target for {component_name}")
    add_subdirectory(fuzz)
endif()
'''
    
    with open(parent_cmake, 'a') as f:
        f.write(fuzz_addition)
    
    print(f"✅ 상위 CMakeLists.txt 수정 완료: add_subdirectory(fuzz) 추가됨")
    return True


def create_readme(fuzz_dir, component_name):
    """퍼징 타겟 사용법 README 생성"""
    
    readme_content = f'''# {component_name} Fuzzing Target

이 디렉토리는 SGFuzz를 사용한 {component_name} 컴포넌트의 퍼징 타겟입니다.

## 빌드 방법

```bash
# F Prime 프로젝트 루트에서 실행
cd fprime
fprime-util generate
fprime-util build --target {component_name}_fuzz
```

## 실행 방법

```bash
# 빌드 디렉토리에서 실행
cd build-fprime-automatic-native
./{component_name}_fuzz -max_len=1024 -runs=10000 -artifact_prefix=./crashes/
```

## 주요 옵션

- `-max_len=<N>`: 최대 입력 크기
- `-runs=<N>`: 실행 횟수 (0 = 무한)
- `-dict=<file>`: 사전 파일 경로
- `-artifact_prefix=<dir>`: 크래시 저장 위치
- `-timeout=<N>`: 타임아웃(초)

## 파일 설명

- `{component_name}_fuzz.cpp`: LibFuzzer 엔트리포인트
- `CMakeLists.txt`: 빌드 설정
- `README.md`: 이 파일

## 생성 정보

- 생성 시각: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
- 생성 스크립트: scripts/setup_fuzz_target.py
'''
    
    readme_path = fuzz_dir / "README.md"
    with open(readme_path, 'w') as f:
        f.write(readme_content)
    
    print(f"✅ README 생성: {readme_path}")
    return readme_path


def main():
    parser = argparse.ArgumentParser(
        description='SGFuzz 퍼징 타겟 자동 생성 도구',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
예제:
  # CmdDispatcher 퍼징 타겟 생성
  python3 scripts/setup_fuzz_target.py --component CmdDispatcher
  
  # 절대 경로로 지정
  python3 scripts/setup_fuzz_target.py --path /path/to/fprime/Svc/CmdDispatcher
        '''
    )
    
    parser.add_argument(
        '--component', '-c',
        type=str,
        help='컴포넌트 이름 (예: CmdDispatcher)'
    )
    
    parser.add_argument(
        '--path', '-p',
        type=str,
        help='컴포넌트 경로 (절대/상대 경로)'
    )
    
    parser.add_argument(
        '--force', '-f',
        action='store_true',
        help='기존 fuzz 디렉토리 덮어쓰기'
    )
    
    args = parser.parse_args()
    
    # 프로젝트 루트 확인
    project_root = get_project_root()
    print(f"🚀 SGFuzz 퍼징 타겟 자동 생성 시작")
    print(f"📁 프로젝트 루트: {project_root}")
    
    # 컴포넌트 경로 결정
    if args.path:
        component_path = Path(args.path).resolve()
    elif args.component:
        # 기본적으로 fprime/Svc/ 아래에서 찾음
        component_path = project_root / "fprime" / "Svc" / args.component
    else:
        print("❌ 오류: --component 또는 --path 옵션이 필요합니다.")
        parser.print_help()
        return 1
    
    # 경로 검증
    if not component_path.exists():
        print(f"❌ 오류: 컴포넌트 경로가 존재하지 않습니다: {component_path}")
        return 1
    
    if not (component_path / "CMakeLists.txt").exists():
        print(f"❌ 오류: CMakeLists.txt를 찾을 수 없습니다: {component_path}")
        return 1
    
    component_name = component_path.name
    print(f"🎯 타겟 컴포넌트: {component_name}")
    print(f"📂 컴포넌트 경로: {component_path}")
    
    # fuzz 디렉토리 체크
    fuzz_dir = component_path / "fuzz"
    if fuzz_dir.exists() and not args.force:
        print(f"⚠️  fuzz 디렉토리가 이미 존재합니다: {fuzz_dir}")
        response = input("덮어쓰시겠습니까? (y/N): ")
        if response.lower() != 'y':
            print("❌ 작업이 취소되었습니다.")
            return 1
        print("🗑️  기존 디렉토리 삭제 중...")
        shutil.rmtree(fuzz_dir)
    
    print("\n" + "="*60)
    print("퍼징 타겟 생성 중...")
    print("="*60 + "\n")
    
    try:
        # 1. fuzz 디렉토리 생성
        fuzz_dir = create_fuzz_directory(component_path)
        
        # 2. CMakeLists.txt 생성
        generate_cmake_lists(fuzz_dir, component_name, project_root, component_path)
        
        # 3. 퍼저 엔트리포인트 생성
        generate_fuzzer_entrypoint(fuzz_dir, component_name)
        
        # 4. README 생성
        create_readme(fuzz_dir, component_name)
        
        # 5. 상위 CMakeLists.txt 수정
        patch_parent_cmake(component_path, component_name)
        
        print("\n" + "="*60)
        print("✅ 퍼징 타겟 생성 완료!")
        print("="*60)
        print(f"\n📋 다음 단계:")
        print(f"   1. {component_name}_fuzz.cpp 파일을 수정하여 실제 퍼징 로직 구현")
        print(f"   2. fprime-util generate 실행")
        print(f"   3. fprime-util build --target {component_name}_fuzz 실행")
        print(f"   4. 퍼저 실행 테스트")
        print(f"\n📖 자세한 내용: {fuzz_dir}/README.md\n")
        
        return 0
        
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())

