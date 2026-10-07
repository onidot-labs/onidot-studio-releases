# onidot-studio 사용 가이드

onidot-studio는 문서와 AI 작업의 맥락을 자신이 선택한 인스턴스에 보관하는 개인 작업 플랫폼입니다. 패키지 하나에 사용자 명령 `oni`와 서버 명령 `onidot-studio`가 들어 있습니다. 두 명령은 같은 버전을 같은 디렉터리에 설치합니다.

현재 공개 버전은 **0.1.2**입니다(첫 공개 0.1.0). 설치 파일은 [공개 릴리스](https://github.com/onidot-labs/onidot-studio-releases/releases/tag/v0.1.2)에서 받습니다. 0.1.2는 AI가 일하며 알게 된 것을 쌓고 찾는 AI 기록(`remember`·`recall`)과 관리 화면, 여러 단계 일의 작업 체크리스트와 사람의 멈춤·지시 메모, 앞으로 추가될 모듈까지 포함하는 연결 권한, 로그인 없는 로컬 인스턴스, 연결 화면 필터·마지막 사용 시각을 더합니다.

## 사용 방법을 고르세요

| 사용 방법 | 저장 위치와 준비물 | 안내 |
| --- | --- | --- |
| 이 기기에서만 사용 | 로컬 SQLite·첨부, PostgreSQL·Docker·JVM·Node 불필요 | [로컬 전용](local.md) |
| 서버를 운영하고 여러 기기에서 접속 | 셀프호스팅 PostgreSQL·첨부, 도메인·TLS·자체 계정 | [셀프호스팅](self-hosted.md) |
| 둘을 함께 사용 | 서로 독립된 두 인스턴스, 원격 READ·로컬 WRITE | [병행 사용](hybrid.md) |

공통 오류는 [문제 해결](troubleshooting.md)을 확인하세요. 설치·백업·복원을 AI에 맡길 때도 실제 비밀 입력, 선택한 onidot 계정 로그인의 client 등록, 셀프호스팅 연결 동의의 Space·읽기/쓰기 선택은 사용자가 직접 확인합니다.

## 빠른 설치(로컬 인스턴스)

이 PC에서 혼자 쓰는 로컬 인스턴스를 설치하고 Claude Code·Codex에 연결하는 순서입니다. 사람이 그대로 따라 해도 되고, AI 클라이언트에 이 문서 링크를 주고 "이 README대로 onidot을 설치하고 설정해 줘"라고 해도 됩니다.

따라 하는 사람·AI 모두 다음을 지킵니다.

- 단계마다 **기대 결과**를 확인하고, 다르면 다음 단계로 가지 말고 출력 그대로 멈춰서 [문제 해결](troubleshooting.md)을 봅니다.
- `sudo`를 쓰지 않습니다. 설치는 `~/.local/bin`에만 합니다.
- 셸 설정 파일(`~/.zshrc` 등)이나 AI 클라이언트 설정을 고치기 전에는 사용자에게 확인합니다. `oni register`가 고치는 AI 연결 등록은 예외입니다.
- 토큰·로그인 링크 같은 값을 대화나 로그에 옮기지 않습니다.

### 1. 지원 환경 확인

```sh
uname -s
uname -m
```

기대 결과: `Darwin`과 `arm64`(macOS Apple Silicon), 또는 `Linux`와 `x86_64`·`aarch64`. Windows와 Intel Mac(`Darwin`·`x86_64`)은 아직 지원하지 않으므로 여기서 멈춥니다.

### 2. 내려받아 설치

```sh
version=0.1.2
base="https://github.com/onidot-labs/onidot-studio-releases/releases/download/v$version"
work=$(mktemp -d) && cd "$work"
curl -fsSLO "$base/install.sh"
bash install.sh --base-url "$base" --version "$version"
export PATH="$HOME/.local/bin:$PATH"
oni version
onidot-studio version
```

기대 결과: `설치 완료: 0.1.2 (<os>_<arch>)`, `oni 0.1.2`, `onidot-studio 0.1.2`. 설치 스크립트가 압축 파일을 `SHA256SUMS`로 검증합니다. 토큰·관리자 권한은 필요 없습니다.

새 터미널에서 `oni`를 찾지 못하면, 사용자에게 확인한 뒤 셸 설정 파일에 `export PATH="$HOME/.local/bin:$PATH"` 한 줄을 더합니다.

### 3. 로컬 인스턴스를 만들고 시작

```sh
oni init --alias local --port 18181
oni daemon start
oni daemon status
curl -fsS http://127.0.0.1:18181/ready
```

기대 결과: `로컬 인스턴스를 만들었습니다.`, `started pid=<숫자>`, `running pid=<숫자>`, `/ready` 응답. `이미 초기화`가 나오면 이미 만든 인스턴스이므로 `oni daemon start`부터 합니다. 18181 포트를 다른 프로그램이 쓰면 다른 포트로 `oni init`합니다.

### 4. 웹 열기

```sh
oni open
```

기대 결과: 브라우저가 열리고 로그인 화면 없이 onidot이 보입니다. 로컬 인스턴스에는 로그인이 없습니다.

### 5. AI 클라이언트에 연결

설치된 클라이언트의 줄만 실행합니다.

```sh
oni register claude
oni register codex
oni doctor --connection local
```

기대 결과: `registered claude onidot-local`(또는 `unchanged …`), `registered codex onidot-local`, doctor의 `문제가 없습니다`. 브라우저 동의는 필요 없습니다. 연결 이름은 `onidot-local`이며, 별칭이 다른 onidot 인스턴스 연결과 겹치지 않습니다.

### 6. onidot 플러그인 설치

플러그인은 AI가 onidot 기본 지침을 스스로 읽고 따르게 하는 스킬과 시작 안내를 줍니다.

```sh
claude plugin marketplace add onidot-labs/onidot-plugins
claude plugin install onidot@onidot
```

```sh
codex plugin marketplace add https://github.com/onidot-labs/onidot-plugins.git
codex plugin add onidot@onidot
```

기대 결과: 각각 설치 완료 메시지. 이미 설치되어 있으면 Claude Code는 `claude plugin update onidot@onidot`, Codex는 `codex plugin marketplace upgrade onidot` 뒤 `codex plugin add onidot@onidot`로 갱신합니다.

### 7. 확인

AI 클라이언트를 **새 세션**으로 열고 이렇게 묻습니다.

> onidot에서 접근 가능한 Space를 조회하고, 지금 적용 중인 onidot 지침을 알려 줘.

기대 결과: Space 목록과 onidot 기본 지침이 나옵니다. 여기까지 되면 설치가 끝났습니다.

### 그다음

- 재부팅 뒤에도 자동으로 켜려면(선택): 설치 폴더에서 `bash install.sh --autostart enable`
- 업데이트·백업·제거: [로컬 인스턴스 안내](local.md)
- 다른 PC나 서버의 onidot에도 연결하려면: [셀프호스팅](self-hosted.md), [둘 다 쓰기](hybrid.md)

## 지원 대상과 첫 설치

- macOS Apple Silicon, 최근 3개 메이저 버전 / Linux x86_64·ARM64가 지원 대상입니다. Intel Mac·Windows는 현재 대상이 아닙니다. 최소 메모리 목표는 8GB이며, 8GB 실기 검증은 아직 완료하지 않았습니다. 지원 대상과 실제 확인 범위는 아래에서 구분합니다.
- 파일 이름은 `onidot-studio_0.1.2_darwin_arm64.tar.gz`, `onidot-studio_0.1.2_linux_amd64.tar.gz`, `onidot-studio_0.1.2_linux_arm64.tar.gz` 형식입니다. 같은 릴리스의 `SHA256SUMS`를 함께 받습니다.
- 로컬은 `oni init` → `oni daemon start` → `oni open`으로 로그인 화면 없이 시작하고 `oni register claude` 또는 `oni register codex`로 브라우저 동의 없이 AI를 연결합니다. 이 흐름을 지원하는 버전으로 업데이트한 뒤 사용하세요. 셀프호스팅은 설정 코드로 비밀번호 계정을 만들며, onidot 계정 로그인은 선택입니다.
- AI 클라이언트는 별도 제품입니다. 사용할 Claude Code 또는 Codex가 설치되어 있고 실행되는지 먼저 확인하세요. `oni register`는 MCP 연결을 등록하며 AI 클라이언트나 플러그인을 설치하지 않습니다.
- onidot은 연결한 AI에 기본 지침을 전달합니다. 지식을 먼저 찾고, 정해진 결정은 적용하고, 사용자가 골라야 할 것만 묻고, 배운 것을 남기는 방식입니다. 연결 안내문이 AI를 `get_assistant_context`로 안내하고 그 응답의 `defaultGuide`에 지침 본문이 담깁니다. 기본 지침은 우선순위가 가장 낮아서 이번 대화의 지시, AI 도구의 로컬 지침, Space 지침이 모두 그보다 우선합니다.

### 확인한 환경과 성능

| 대상 | 확인한 범위 | 아직 확인하지 않은 범위 |
| --- | --- | --- |
| macOS Apple Silicon | macOS 26.5.1 실기에서 터미널 설치·웹·MCP·백업·복원, launchd 기동·프로세스 재시작·해제 | 다른 지원 macOS 메이저, 로그아웃·로그인/재부팅 지속성, 브라우저 다운로드·Gatekeeper |
| Linux ARM64 | Docker Desktop ARM64 VM의 Debian 12 컨테이너에서 설치·웹·MCP·백업·복원 | Linux 실기, systemd user 자동 시작·재로그인/재부팅 |
| Linux x86_64 | 같은 VM의 Rosetta AMD64 에뮬레이션 컨테이너에서 같은 기능 흐름 | Linux 실기, systemd user 자동 시작·재로그인/재부팅, 실제 QEMU 실행 |

0.1.0 최종 바이너리로 위 세 환경의 설치·새 로컬 로그인·문서·첨부·READ/WRITE MCP·재시작·백업·새 root 복원·재인가 11단계를 확인했습니다. Linux는 정상 OS 계정이 있는 격리 컨테이너에서 실행했으며 실기 검증은 아닙니다. 별도로 macOS에서 `oni open` 브라우저 로그인과 Claude Code 2.1.284·Codex 0.159.2 실제 대화의 페이지 작성·재조회, READ 쓰기 도구 비노출·작성 거부, 데몬 재시작 후 같은 인스턴스 재연결을 확인했습니다. 0.1.2는 macOS Apple Silicon에서 설치·초기화·기동, 로그인 없는 웹 열기, Claude Code·Codex 연결 등록과 MCP 확인(`oni doctor`)을 다시 확인했습니다. 새 기능의 서버 동작은 같은 소스의 셀프호스팅 인스턴스에서 확인했습니다.

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
version=0.1.2
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

기대 결과는 각각 `oni 0.1.2`, `onidot-studio 0.1.2`입니다. 한 명령이 실패하거나 버전이 다르면 초기화·기동하지 말고 두 파일을 같은 압축 파일에서 다시 설치하세요. 심볼릭 링크로 연결하지 않습니다. macOS 실행 제한이 나오면 [문제 해결](troubleshooting.md#macos에서-실행이-차단될-때)을 따릅니다.

새 터미널에서도 찾도록 사용하는 셸의 시작 설정에 `export PATH="$HOME/.local/bin:$PATH"`를 한 번 추가하고 `command -v oni`를 확인하세요. 설치 명령은 두 실행 파일만 복사합니다. 오프라인에서도 읽으려면 압축 파일 또는 `README.md`·`LICENSE`·`docs/`를 함께 보관하세요. 임시 압축 해제 폴더는 두 명령 설치와 문서 보관이 확인된 뒤 그 폴더만 지워도 됩니다. 사용자 데이터 경로와 혼동하지 마세요.

### 설치 스크립트 경로

공개 릴리스의 `install.sh`를 내려받아 내용을 확인한 뒤 실행합니다. Bash·curl·tar와 SHA-256 도구(`shasum` 또는 `sha256sum`)가 필요합니다. 자동 OS/CPU 판별·다운로드·검증·두 명령 설치를 수행합니다. `release_base`에는 **그 버전의 archive와 SHA256SUMS가 있는 HTTPS 디렉터리 주소**를 넣습니다. 아래 주소는 0.1.0 공개 릴리스의 다운로드 경로입니다.

```sh
release_base=https://github.com/onidot-labs/onidot-studio-releases/releases/download/v0.1.2
bash install.sh --help
bash install.sh --base-url "$release_base" --version 0.1.2
export PATH="$HOME/.local/bin:$PATH"
oni version
onidot-studio version
```

기대 결과는 `설치 완료: 0.1.2 (<os>_<arch>)`, 설치 경로·PATH·init/start 안내입니다. 토큰·sudo는 필요하지 않습니다. 스크립트는 셸 설정이나 OS 자동 시작을 기본으로 바꾸지 않습니다. 지원하지 않는 OS/CPU·혼합 버전·checksum 불일치·부분 다운로드는 거부합니다. 같은 버전 재설치도 먼저 데몬을 멈추고, 자동 시작을 등록했다면 해제해야 합니다. 다른 버전 업데이트에는 [업데이트](local.md#업데이트와-되돌리기)의 백업·정지 후 `--restart`를 사용합니다. 버전 내림은 자동 수행하지 않습니다.

## 데이터와 사용 조건

문서·첨부는 선택한 인스턴스에 저장됩니다. 로컬 인스턴스와 셀프호스팅 인스턴스 사이의 자동 동기화·복제·연결 실패 시 다른 인스턴스로 자동 저장은 제공하지 않습니다. 백업 묶음과 비밀 설정은 함께 복구할 수 있도록 별도로 안전하게 보관하세요.

실행 파일 제거는 데이터 삭제와 다릅니다. 설치 스크립트나 업데이트 안내가 데이터 삭제를 기본 동작으로 삼아서는 안 됩니다. 사용 조건 초안은 [TERMS.md](TERMS.md)에 있으며, 공개 준비 묶음의 `LICENSE`에도 같은 내용을 담습니다. 배포자가 이 초안을 그대로 포함한 0.1.0 공개 배포를 승인했습니다. 초안은 별도의 사용 허락이나 확정된 법적 조항을 제공하지 않으며, 소스 공개나 오픈소스 라이선스 채택을 뜻하지 않습니다.
