# onidot-studio 사용 가이드

onidot-studio는 문서와 AI 작업의 맥락을 자신이 선택한 인스턴스에 보관하는 개인 작업 플랫폼입니다. 패키지 하나에 사용자 명령 `oni`와 서버 명령 `onidot-studio`가 들어 있습니다. 두 명령은 같은 버전을 같은 디렉터리에 설치합니다.

첫 공개 버전은 **0.1.0**입니다. 설치 파일은 [공개 릴리스](https://github.com/onidot-labs/onidot-studio-releases/releases/tag/v0.1.0)에서 받습니다. 이 저장소는 바이너리와 사용자 문서를 배포하며 구현 소스는 포함하지 않습니다. 설치·복원과 OS별 확인 범위는 아래를 참고하세요.

## 사용 방법을 고르세요

| 사용 방법 | 저장 위치와 준비물 | 안내 |
| --- | --- | --- |
| 이 기기에서만 사용 | 로컬 SQLite·첨부, PostgreSQL·Docker·JVM·Node 불필요 | [로컬 전용](local.md) |
| 서버를 운영하고 여러 기기에서 접속 | 셀프호스팅 PostgreSQL·첨부, 도메인·TLS·자체 계정 | [셀프호스팅](self-hosted.md) |
| 둘을 함께 사용 | 서로 독립된 두 인스턴스, 원격 READ·로컬 WRITE | [병행 사용](hybrid.md) |

공통 오류는 [문제 해결](troubleshooting.md)을 확인하세요. 설치·백업·복원을 AI에 맡길 때도 실제 비밀 입력, 선택한 onidot 계정 로그인의 client 등록, 연결 동의의 Space·읽기/쓰기 선택은 사용자가 직접 확인합니다.

## 지원 대상과 첫 설치

- macOS Apple Silicon, 최근 3개 메이저 버전 / Linux x86_64·ARM64가 지원 대상입니다. Intel Mac·Windows는 현재 대상이 아닙니다. 최소 메모리 목표는 8GB이며, 8GB 실기 검증은 아직 완료하지 않았습니다. 지원 대상과 실제 확인 범위는 아래에서 구분합니다.
- 파일 이름은 `onidot-studio_0.1.0_darwin_arm64.tar.gz`, `onidot-studio_0.1.0_linux_amd64.tar.gz`, `onidot-studio_0.1.0_linux_arm64.tar.gz` 형식입니다. 같은 릴리스의 `SHA256SUMS`를 함께 받습니다.
- 로컬은 `oni init` → `oni daemon start` → `oni open`으로 시작합니다. 셀프호스팅은 설정 코드로 비밀번호 계정을 만들며, onidot 계정 로그인은 선택입니다.
- AI 클라이언트는 별도 제품입니다. 사용할 Claude Code 또는 Codex가 설치되어 있고 실행되는지 먼저 확인하세요. `oni register`는 MCP 연결을 등록하며 AI 클라이언트나 플러그인을 설치하지 않습니다.

### 확인한 환경과 성능

| 대상 | 확인한 범위 | 아직 확인하지 않은 범위 |
| --- | --- | --- |
| macOS Apple Silicon | macOS 26.5.1 실기에서 터미널 설치·웹·MCP·백업·복원, launchd 기동·프로세스 재시작·해제 | 다른 지원 macOS 메이저, 로그아웃·로그인/재부팅 지속성, 브라우저 다운로드·Gatekeeper |
| Linux ARM64 | Docker Desktop ARM64 VM의 Debian 12 컨테이너에서 설치·웹·MCP·백업·복원 | Linux 실기, systemd user 자동 시작·재로그인/재부팅 |
| Linux x86_64 | 같은 VM의 Rosetta AMD64 에뮬레이션 컨테이너에서 같은 기능 흐름 | Linux 실기, systemd user 자동 시작·재로그인/재부팅, 실제 QEMU 실행 |

0.1.0 최종 바이너리로 위 세 환경의 설치·새 로컬 로그인·문서·첨부·READ/WRITE MCP·재시작·백업·새 root 복원·재인가 11단계를 확인했습니다. Linux는 정상 OS 계정이 있는 격리 컨테이너에서 실행했으며 실기 검증은 아닙니다. 별도로 macOS에서 `oni open` 브라우저 로그인과 Claude Code 2.1.284·Codex 0.159.2 실제 대화의 페이지 작성·재조회, READ 쓰기 도구 비노출·작성 거부, 데몬 재시작 후 같은 인스턴스 재연결을 확인했습니다.

다음은 `0.1.0` 최종 바이너리를 Apple M5 Pro·macOS 26.5.1·RAM 48GiB에서 측정한 값입니다. 8GB 기기나 모든 작업의 자원 상한을 보장하는 수치가 아닙니다. MB는 1,000,000 bytes입니다.

| 항목 | 목표 | 측정값 |
| --- | --- | --- |
| 설치 크기 | 100MB 이하 | 약 64.3MB — macOS 두 명령과 공개 문서 합계 |
| 기동 | 2초 이내 | 3회 최대 0.101757초 — 1만 문서 DB에서 ready·PID 확인까지 |
| 유휴 메모리 | 100MB 이하 | 최대 RSS 79.643MB |
| 작업 메모리 | 300MB 이하 | 최대 표본 RSS 256.868MB |
| 유휴 CPU | 거의 0% | 30초 평균 0.099%, 최대 0.988% |
| 1만 문서 검색 | p95 0.3초 이하 | 예열 후 가장 느린 질의의 p95 0.237740초 |

메모리·CPU는 서버와 MCP bridge 2개의 합계입니다. 검색은 한글·영문 혼합 1만 문서, 7종 질의, 동시성 1, 질의별 예열 3회·측정 30회 기준입니다. 서버를 다시 시작한 첫 검색은 질의별 3회 중 최대 0.236634초였으나 OS 파일 캐시는 비우지 않았습니다. 작업 RSS는 100ms 간격 표본으로 순간 최대를 놓칠 수 있습니다. 다른 앱이 실행 중인 개발 기기 측정이며, 대형 첨부·백업·동시 요청의 상한과 신규 초기화·인증 시간은 포함하지 않습니다. 공개 문서 포함 설치 크기는 세 플랫폼 모두 100MB 아래이며, Linux x86_64 패키지가 약 66.7MB로 가장 큽니다.

전체 [알려진 제한](troubleshooting.md#알려진-제한)을 확인한 뒤 설치하세요.

### 압축 파일로 설치하기

출시 공지의 공개 릴리스에서 자신의 OS·CPU에 맞는 압축 파일과 `SHA256SUMS`를 **새 빈 다운로드 폴더**에 받으세요. 주소를 임의로 추정하지 마세요. 아래는 macOS ARM64 예시이며 Linux에서는 파일명을 자신의 대상에 맞춥니다. 공개 준비 묶음의 archive에는 `oni`, `onidot-studio`, `README.md`, `LICENSE`와 `docs/`의 가이드 6개(`README`, `local`, `self-hosted`, `hybrid`, `troubleshooting`, `TERMS`)가 들어 있습니다. `install.sh`는 archive 밖의 별도 릴리스 파일입니다. 기존 설치가 있으면 먼저 [업데이트](local.md#업데이트와-되돌리기)를 따르세요.

```sh
version=0.1.0
target=darwin_arm64
archive="onidot-studio_${version}_${target}.tar.gz"
# macOS: 현재 폴더에 받은 파일만 검증합니다.
awk -v f="$archive" '$2 == f { print }' SHA256SUMS > selected.sha256
test "$(wc -l < selected.sha256 | tr -d ' ')" = 1 &&
  shasum -a 256 -c selected.sha256
```

Linux에서는 마지막 `shasum -a 256 -c selected.sha256` 대신 `sha256sum -c selected.sha256`를 실행합니다. 결과가 `<파일명>: OK`이고 종료 코드가 0일 때만 다음 단계로 갑니다. 목록 0개·해시 불일치·다운로드 중단이면 설치하지 말고 같은 릴리스의 파일을 다시 받으세요. SHA-256 검사는 다운로드 손상을 확인하며 코드 서명·공증을 의미하지 않습니다.

```sh
package_dir=$(mktemp -d)
tar -xzf "$archive" -C "$package_dir"
"$package_dir/oni" version
"$package_dir/onidot-studio" version
mkdir -p "$HOME/.local/bin"
install -m 0755 "$package_dir/oni" "$HOME/.local/bin/oni"
install -m 0755 "$package_dir/onidot-studio" "$HOME/.local/bin/onidot-studio"
export PATH="$HOME/.local/bin:$PATH"
oni version
onidot-studio version
```

기대 결과는 각각 `oni 0.1.0`, `onidot-studio 0.1.0`입니다. 한 명령이 실패하거나 버전이 다르면 초기화·기동하지 말고 두 파일을 같은 압축 파일에서 다시 설치하세요. 심볼릭 링크로 연결하지 않습니다. macOS 실행 제한이 나오면 [문제 해결](troubleshooting.md#macos에서-실행이-차단될-때)을 따릅니다.

새 터미널에서도 찾도록 사용하는 셸의 시작 설정에 `export PATH="$HOME/.local/bin:$PATH"`를 한 번 추가하고 `command -v oni`를 확인하세요. 설치 명령은 두 실행 파일만 복사합니다. 오프라인에서도 읽으려면 압축 파일 또는 `README.md`·`LICENSE`·`docs/`를 함께 보관하세요. 임시 압축 해제 폴더는 두 명령 설치와 문서 보관이 확인된 뒤 그 폴더만 지워도 됩니다. 사용자 데이터 경로와 혼동하지 마세요.

### 설치 스크립트 경로

공개 릴리스의 `install.sh`를 내려받아 내용을 확인한 뒤 실행합니다. Bash·curl·tar와 SHA-256 도구(`shasum` 또는 `sha256sum`)가 필요합니다. 자동 OS/CPU 판별·다운로드·검증·두 명령 설치를 수행합니다. `release_base`에는 **그 버전의 archive와 SHA256SUMS가 있는 HTTPS 디렉터리 주소**를 넣습니다. 아래 주소는 0.1.0 공개 릴리스의 다운로드 경로입니다.

```sh
release_base=https://github.com/onidot-labs/onidot-studio-releases/releases/download/v0.1.0
bash install.sh --help
bash install.sh --base-url "$release_base" --version 0.1.0
export PATH="$HOME/.local/bin:$PATH"
oni version
onidot-studio version
```

기대 결과는 `설치 완료: 0.1.0 (<os>_<arch>)`, 설치 경로·PATH·init/start 안내입니다. 토큰·sudo는 필요하지 않습니다. 스크립트는 셸 설정이나 OS 자동 시작을 기본으로 바꾸지 않습니다. 지원하지 않는 OS/CPU·혼합 버전·checksum 불일치·부분 다운로드는 거부합니다. 같은 버전 재설치도 먼저 데몬을 멈추고, 자동 시작을 등록했다면 해제해야 합니다. 다른 버전 업데이트에는 [업데이트](local.md#업데이트와-되돌리기)의 백업·정지 후 `--restart`를 사용합니다. 버전 내림은 자동 수행하지 않습니다.

## 데이터와 사용 조건

문서·첨부는 선택한 인스턴스에 저장됩니다. 로컬 인스턴스와 셀프호스팅 인스턴스 사이의 자동 동기화·복제·연결 실패 시 다른 인스턴스로 자동 저장은 제공하지 않습니다. 백업 묶음과 비밀 설정은 함께 복구할 수 있도록 별도로 안전하게 보관하세요.

실행 파일 제거는 데이터 삭제와 다릅니다. 설치 스크립트나 업데이트 안내가 데이터 삭제를 기본 동작으로 삼아서는 안 됩니다. 사용 조건 초안은 [TERMS.md](TERMS.md)에 있으며, 공개 준비 묶음의 `LICENSE`에도 같은 내용을 담습니다. 배포자가 이 초안을 그대로 포함한 0.1.0 공개 배포를 승인했습니다. 초안은 별도의 사용 허락이나 확정된 법적 조항을 제공하지 않으며, 소스 공개나 오픈소스 라이선스 채택을 뜻하지 않습니다.
