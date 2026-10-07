# 로컬 인스턴스만 사용하기

이 기기의 SQLite·첨부에 저장하고 브라우저와 AI 도구로 사용하는 경로입니다. 서버는 `127.0.0.1`에서만 받습니다. 다른 기기에서 접속하려면 [셀프호스팅](self-hosted.md)을 선택하세요.

## 1. 두 명령 설치와 초기화

[설치 안내](README.md#압축-파일로-설치하기)를 마친 뒤 `oni version`, `onidot-studio version`의 버전이 같은지 확인합니다. 예시는 로컬 별칭 `local`, 포트 `18181`을 사용합니다. 이 기기의 OS 사용자가 주인이며, onidot 계정이나 외부 로그인 client를 준비할 필요가 없습니다.

```sh
oni init --alias local --port 18181
```

성공하면 `로컬 인스턴스를 만들었습니다.`와 주소·MCP·설정·데이터 경로가 나옵니다. 주소는 `http://127.0.0.1:18181`, MCP는 `http://127.0.0.1:18181/mcp`입니다. `이미 초기화`라면 기존 설정을 지우지 말고 다음 기동 단계로 가세요. 포트 충돌이면 [문제 해결](troubleshooting.md)을 봅니다.

## 2. 시작하고 웹 열기

```sh
oni daemon start
oni daemon status
curl -fsS http://127.0.0.1:18181/ready
oni open
```

기대 결과는 `started pid=<숫자>`, `running pid=<숫자>`, `/ready` HTTP 200입니다. `starting pid=…`이면 아직 준비 중이므로 잠시 뒤 `/ready`를 다시 확인하세요. `oni open`은 실행 중인 데몬에서 2분·1회용 링크를 받아 로그인 화면 없이 주인의 웹 화면을 엽니다. 데몬이 꺼져 있으면 먼저 `oni daemon start`를 실행합니다.

기본 동작은 본인만 읽는 runtime 폴더에 `0600` HTML 파일을 만들고, 브라우저가 그 파일에서 로그인 링크로 이동하는 방식입니다. 로그인 토큰을 OS 열기 명령의 인자에 넣지 않습니다. 이전에 만든 5분 지난 파일은 다음 실행 때 정리합니다. 로컬 웹 세션의 수명은 365일이며 사용하면 만료 시각이 갱신됩니다. 데몬 재시작과 바이너리 업데이트 뒤에도 유지됩니다. 세션이 만료되거나 브라우저 쿠키를 지웠다면 `oni open`을 다시 실행합니다. Wiki 화면에서 Space를 만들거나 사용할 Space를 선택하고 문서 하나를 저장·재조회하여 첫 사용을 확인하세요.

다른 화면으로 바로 가려면 `oni open /settings/account`처럼 인스턴스 안의 `/`로 시작하는 경로를 줍니다. 전체 외부 URL은 받지 않습니다. 브라우저가 숨김 폴더의 파일에 접근할 수 없는 경우(예: Linux snap 브라우저)에는 다음처럼 링크를 직접 넘깁니다.

```sh
oni open --direct
# 브라우저를 직접 열 기기에서만 사용하며 출력 링크를 다른 사람에게 보내지 않습니다.
oni open --print
```

`--direct`는 로그인 링크가 OS 열기 명령의 인자에 들어갑니다. `--print`는 링크를 표준 출력에 보여 주므로 본인이 즉시 직접 열고, 대화·스크린샷·로그에 복사하지 마세요. 두 옵션을 함께 쓰지 않습니다. 링크가 만료되거나 이미 사용되었으면 `oni open`을 다시 실행합니다.

여러 사람이 같은 PC를 쓰면 OS 사용자와 브라우저 프로필을 분리하세요. loopback 주소만으로 다른 로컬 프로세스와 브라우저를 신뢰할 수 있는 것은 아닙니다. 공유 OS 계정이나 신뢰하지 않는 프로세스가 있는 환경에서 주인 세션을 함께 사용하지 않습니다.

## 3. Claude Code·Codex 연결

설정 파일은 사용자별입니다. AI 클라이언트를 실행할 것과 같은 OS 사용자·HOME에서 진행하세요. init만으로 AI 연결이 등록되지는 않습니다.

```sh
oni register claude
oni register codex
oni doctor --connection local
```

설치한 AI 클라이언트의 register 줄만 실행합니다. 별칭을 생략하면 초기화한 로컬 인스턴스의 별칭을 사용합니다. 예시와 다른 별칭으로 초기화했다면 doctor의 `--connection`에도 그 별칭을 사용하세요. 초기화한 로컬 인스턴스에 연결을 자동으로 만들므로 `oni connection add`나 `oni login`, 브라우저 동의가 필요하지 않습니다. OS 사용자만 읽을 수 있는 `0600` 로컬 토큰으로 WRITE 연결을 만들며, 모든 모듈의 읽기·쓰기(앞으로 추가될 모듈 포함)를 허용합니다. 관리 행동은 이 범위에 포함되지 않으며 Space 구성원·권한 검사는 유지됩니다. 사용 중 토큰 갱신은 자동으로 처리합니다. 토큰 파일이 없을 때만 자격 증명을 자동 발급합니다. 폐기된 연결, 갱신이 거절된 연결, 갱신 결과가 확정되지 않은 연결은 자동으로 되살리지 않습니다. 새 자격 증명을 발급하려면 데몬을 실행하고 `oni register claude --reissue` 또는 `oni register codex --reissue`를 명시합니다. 재발급 여부는 출력으로 확인할 수 있으며, 같은 별칭의 기존 자격 증명은 폐기됩니다. 브라우저 동의는 필요하지 않습니다. 이미 설정된 연결을 `--connection local`처럼 명시하면 데몬이 꺼져 있어도 클라이언트 등록은 유지할 수 있으나, 실제 연결 확인에는 데몬이 필요합니다.

register는 `registered claude onidot-local` 또는 `registered codex onidot-local`을 출력하며, 같은 등록이면 `unchanged …`입니다. 같은 이름에 다른 연결이 있으면 덮어쓰지 않으므로 충돌을 먼저 해결합니다. 공식 AI 클라이언트 명령은 자체 캐시나 빈 설정 배열을 정규화할 수 있습니다. 등록 과정에서 기존 설정 보존 확인 오류가 나오면 항목을 무작정 다시 추가하지 말고 실제 등록과 백업 차이를 먼저 확인하세요.

doctor는 OAuth 메타데이터·MCP initialize·tools/list·list_spaces를 확인합니다. WRITE 도구와 접근 가능한 Space가 보여야 합니다. 등록 전에 연결이나 토큰이 없으면 먼저 위 register 명령을 실행합니다. 등록 성공만으로 AI가 실제 도구를 호출했다고 보지는 마세요.

AI 클라이언트에서 새 대화를 열어 다음처럼 요청합니다.

> onidot-local에서 접근 가능한 Space를 조회하고 인스턴스 별칭과 모드를 알려 주세요. 제가 선택한 Space에 “연결 확인” 문서를 저장하고 발행본을 다시 읽어 주세요.

목록을 보고 저장할 Space를 사용자가 선택합니다. 재조회한 페이지가 로컬 웹에도 보이는지 확인하세요. 플러그인의 문서 사용 절차가 필요하면 해당 클라이언트용 onidot 플러그인을 별도로 설치합니다. 플러그인과 MCP 연결은 별개이며 플러그인 설치가 저장 대상·승인 Space를 대신 정하지 않습니다.

## 4. 저장 위치와 일상 사용

| 항목 | macOS | Linux 기본값 |
| --- | --- | --- |
| config | `~/Library/Application Support/onidot/config` | `~/.config/onidot` |
| data | `~/Library/Application Support/onidot/data` | `~/.local/share/onidot` |
| state | `~/Library/Application Support/onidot/state` | `~/.local/state/onidot` |
| runtime | `~/Library/Application Support/onidot/runtime` | `$XDG_RUNTIME_DIR/onidot` 또는 state 아래 `runtime` |

Linux에서는 XDG 경로 설정이 우선합니다. 실제 값은 `oni doctor`에서 확인하세요. config의 `instance.json`에는 비밀이 포함되므로 출력·공유하지 않습니다. data의 `instance/`에 `database.sqlite`와 `blobs/`가 있고 복원 후에는 새 root로 바뀝니다. state에는 `server.log`가 있습니다. DB 파일만 복사하면 첨부가 빠질 수 있으므로 아래 백업 명령을 사용합니다.

```sh
oni daemon status
oni doctor
oni daemon stop
oni daemon start
```

stop의 성공 출력은 `stopped`입니다. start는 같은 설치 디렉터리의 `onidot-studio`를 실행합니다. 실행 파일을 옮기면 연결에 기록된 절대경로가 달라지므로 register를 다시 실행하세요. 기본 경로 대신 `ONI_*_DIR`나 경로 옵션을 쓰면 AI가 실행하는 `oni mcp`에도 같은 환경을 전달해야 합니다. 처음 사용하는 경우 기본 경로를 권장합니다.

**자동 시작은 선택 사항입니다.** init을 끝낸 뒤 같은 릴리스의 설치 스크립트로 등록합니다. 이미 수동 기동 중이면 먼저 멈춥니다.

```sh
oni daemon stop
bash install.sh --autostart enable
oni daemon status
oni doctor
```

기대 결과는 `자동 시작을 등록했습니다.`로 시작하는 안내와 `running pid=…`입니다. macOS 26.5.1의 launchd 기동·프로세스 재시작·해제는 확인했으며, Linux systemd user와 재로그인·재부팅 지속성은 아직 미확인입니다. macOS는 `~/Library/LaunchAgents/com.onidot.studio.local.plist`, Linux는 `${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/onidot-studio.service`를 사용합니다. 절대 서버 경로·인스턴스 경로·HOME을 고정한 사용자 서비스로 실행하며 root 서비스로 등록하지 않습니다. Linux에는 동작하는 systemd user 세션이, macOS에는 launchd GUI 사용자 세션이 필요합니다. 컨테이너나 SSH 전용 세션에서 동일한 서비스 동작을 가정하지 마세요.

등록 뒤 실제 로그아웃·로그인 후 status와 웹 접속을 확인하세요. OS·세션별 자동 시작 검증은 별도이며 등록 파일 생성만으로 재시작 성공을 판단하지 않습니다. 해제는 다음과 같습니다.

```sh
bash install.sh --autostart disable
oni daemon status
```

기대 출력은 `자동 시작을 해제했습니다. 데이터는 보존했습니다.`입니다. 실패하면 등록 파일을 임의로 지우지 말고 오류를 확인하세요. 다시 수동 사용하려면 `oni daemon start`를 실행합니다. 자동 시작이 활성일 때 단순 daemon stop만으로 서비스가 계속 멈춰 있을 것이라 가정하지 않습니다.

로컬 웹과 AI 연결은 계정 로그인·브라우저 동의 없이 사용할 수 있습니다. 설치 파일 다운로드와 AI 서비스 이용에 필요한 네트워크는 별도입니다. 네트워크가 끊겼다고 원격이나 다른 인스턴스에 자동 저장하지 않습니다.

## 5. 백업과 복원

자동 백업 일정·보존 정책은 제공하지 않습니다. 필요한 시점마다 수동으로 백업하고 별도 보관·복원 확인을 수행하세요. 백업은 실행 중인 데몬에 요청합니다. 목적지 상위 폴더를 먼저 만들고 **아직 존재하지 않는 경로**, 현재 instance root 밖을 지정하세요. 가능하면 다른 디스크에도 보관하세요.

```sh
mkdir -p "$HOME/onidot-backups"
oni backup "$HOME/onidot-backups/before-update-0.1.0"
```

성공하면 `백업을 만들었습니다:`와 DB·첨부 수, 정지 시간이 출력되고 목적지에 `COMPLETE` 표식이 생깁니다. 잠시 쓰기·GC가 정지될 수 있습니다. 목적지가 이미 있거나 공간이 부족하면 기존 백업을 지우지 말고 새 경로·여유 공간을 확보하세요. 백업·복원 전 충분한 디스크 여유를 직접 확인하며, 모든 공간 부족을 시작 전에 검출한다고 가정하지 마세요. `COMPLETE`만으로 복원 검증을 대신할 수는 없습니다.

**사용자 비밀 보관:** doctor로 찾은 config의 `instance.json`도 암호화된 별도 보관소에 복사하세요. 백업 묶음은 그 비밀 설정을 포함하지 않습니다. 아래 복원은 동일 설정이 남아 있는 기기에서 실행합니다.

자동 시작을 사용한다면 **먼저 `bash install.sh --autostart disable`로 서비스를 해제**하세요. 등록을 둔 채 daemon stop만 실행하면 서비스 관리자가 재기동하여 복원 잠금을 다시 잡을 수 있습니다. 해제 성공을 확인한 뒤 아래를 실행합니다.

```sh
oni daemon stop
oni restore "$HOME/onidot-backups/before-update-0.1.0"
oni daemon start
oni doctor
oni open
```

기대 결과는 `복원했습니다.`와 새 root·그대로 보존한 이전 root 안내입니다. 기본 새 root는 data 아래 `instance-restored-<백업 ID>`입니다. 다른 빈 root를 원하면 restore에 `--target /절대경로/새-root`를 줍니다. 살아 있는 데몬·다른 인스턴스 백업·불완전한 백업·빈 경로가 아닌 대상·지원하지 않는 migration 버전은 거부합니다. 정상 `restore.lock`은 실행 후 남아도 되므로 지우지 않습니다.

이전 버전의 백업을 새 버전에서 복원할 때는 `oni restore /절대경로/백업 --upgrade`를 명시합니다. 원본의 파일 hash·migration checksum·instance ID를 먼저 검사하고 별도 staging root에서 순서대로 migration한 뒤 후보 이력을 다시 검사하여 활성화합니다. 기본 복원은 이력이 정확히 같은 백업만 받으며, `--upgrade`도 모르는 모듈·미래 버전·checksum 불일치를 허용하지 않습니다. 백업 원본과 이전 root는 보존합니다. guide·ledger 이력이 들어간 DB·백업은 이 모듈을 모르는 구 바이너리로 열거나 복원할 수 없습니다. 새 이력을 이해하는 호환 바이너리와 그 버전에 맞는 백업을 함께 보관하세요.

복원은 주인·문서·권한·instance ID를 유지하고 기존 세션·MCP grant·PAT·미사용 일회 코드를 폐기합니다. `oni open`으로 기존 주인의 웹 화면을 여세요. 새 주인 생성 절차가 아닙니다. 문서·첨부를 확인하고 3절의 명시적 재발급으로 AI 연결을 복구합니다.

```sh
oni register claude --reissue
# Codex를 사용하면 oni register codex --reissue
oni doctor --connection local
```

문서·첨부와 재인가 확인까지 마친 뒤 자동 시작을 다시 원하면 `oni daemon stop` → `bash install.sh --autostart enable` → status·doctor 확인 순서로 재등록합니다.

이전 PAT를 사용하는 클라이언트에는 새 PAT를 발급해 교체합니다. 폐기된 자격증명을 복사해서 복구하지 않습니다. 새 기기처럼 config가 없을 때는 동일 버전 두 명령을 설치한 뒤 다음을 사용합니다.

```sh
oni restore /절대경로/백업묶음 \
  --instance-config /절대경로/안전하게-보관한-instance.json
```

새 기기에서는 `oni init`으로 다른 인스턴스를 만들지 않고 위 복원부터 실행합니다. 이어서 `oni daemon start`·`oni doctor`·`oni open`으로 기존 주인과 문서·첨부를 확인한 뒤, 3절의 register로 그 기기의 AI 연결을 새로 구성합니다. 설정 사본은 원본 인스턴스의 비밀과 ID를 유지해야 합니다. 기존 config가 있는 기기에 `--instance-config`를 주어 덮어쓰지 않습니다. 복구 확인 후에도 이전 root·백업은 필요 기간 동안 보관합니다.

## 업데이트와 되돌리기

1. 대상 릴리스의 변경·migration·사용 조건을 읽고 현재 두 버전을 적어 둡니다. 새 archive와 SHA256SUMS를 [설치 안내](README.md#압축-파일로-설치하기)대로 검증·별도 압축 해제합니다.
2. 위 백업과 `instance.json` 별도 보관을 끝내고 성공 여부를 확인합니다. 자동 시작을 설정했다면 먼저 그 사용자 서비스를 중지하여 재기동을 막습니다. `oni daemon stop` 후 `stopped`를 확인합니다.
3. 기존 `oni`·`onidot-studio`를 함께 별도 복구 폴더에 복사합니다. 새 두 파일을 같은 `~/.local/bin`에 설치합니다. 설치기를 쓰면 아래 `--restart` 경로로 두 파일 교체·재기동·doctor를 확인합니다. 수동 설치 중 어느 한 파일 설치가 실패하면 기동하지 않고 이전 두 파일을 함께 되돌립니다.
4. `oni version`, `onidot-studio version`이 같은 새 0.x 버전인지 확인하고 `oni daemon start`, `/ready`, 웹의 문서·첨부, `oni doctor --connection local`을 확인합니다. 등록 경로가 같으면 다시 로그인하거나 register를 새로 할 필요가 없습니다.
5. 업데이트가 실패하면 새 데몬을 멈추고 로그를 확인합니다. DB가 이미 migration되었을 수 있으므로 옛 바이너리만 덮어서 새 DB를 열지 마세요. 이전 두 바이너리와 그 버전에 맞는 **업데이트 전 백업**·설정 사본으로 위 복원 절차를 수행한 뒤 `oni open`과 register로 웹·AI 연결을 복구합니다. 복원 전후 root를 지우지 않습니다.

이미 로그인·등록한 로컬 사용자도 기존 인스턴스 설정·DB·토큰 파일과 설치 경로를 보존한 채 두 바이너리를 함께 업데이트합니다. 기존 연결은 계속 사용하며 재등록하지 않습니다. 기존 Wiki 전용 연결의 권한을 자동으로 넓히지는 않습니다. guide·ledger 등 새 모듈도 사용하려면 웹 설정 → 연결에서 해당 연결을 선택하고 **모든 모듈로 넓히기**를 누른 뒤 추가되는 권한과 줄어드는 권한을 확인하고 저장합니다. 기존 읽기·쓰기와 Wiki 관리 권한, 별도로 선택한 모듈 권한은 유지됩니다. 읽기 전용 연결에는 쓰기·관리를 추가하지 않으며, 모든 모듈 범위는 현재와 미래 모듈의 읽기·쓰기에만 적용됩니다. 새 모듈의 관리는 개별 모듈에서 별도로 선택합니다. 토큰을 재발급할 필요는 없습니다. 처음 등록하는 로컬 연결은 모든 모듈 읽기·쓰기를 사용합니다.

설치기 업데이트 예시입니다. 위의 백업과 설정 보관을 완료한 뒤 실행하며, `0.6.1`과 URL은 실제 목표 릴리스로 바꿉니다.

```sh
bash install.sh --autostart disable
oni daemon stop
release_base=https://downloads.example/onidot-studio/0.6.1
bash install.sh --base-url "$release_base" --version 0.6.1 --restart
oni doctor --connection local
```

설치기는 이전 파일을 `~/.local/bin/.onidot-backup.*`에 보존하고 경로를 출력합니다. 전환 실패 시 실행 파일 복구를 시도하지만 DB를 자동 복원하거나 옛 서버를 자동 시작하지 않습니다. doctor가 미로그인 연결 때문에 실패한 경우에도 성공으로 처리하지 않으므로 오류 이유와 실제 파일 버전을 먼저 확인하세요. 복구 경로·업데이트 전 백업을 지우지 않습니다. 자동 시작을 다시 원하면 새 서버 점검 후 `oni daemon stop` → `bash install.sh --autostart enable`로 재등록합니다.

## 제거할 때 데이터 보존

AI 연결을 더 쓰지 않을 때는 서버가 살아 있을 때 `oni login --connection local --logout`한 뒤 클라이언트에서 `onidot-local` 등록만 해제합니다. 다른 서버 등록은 보존하세요. 그 다음 자동 시작을 해제하고 데몬을 멈춥니다.

```sh
oni connection remove --alias local
bash install.sh --autostart disable
oni daemon stop
bash install.sh --uninstall
```

기대 결과는 `두 실행 파일을 제거했습니다. 데이터·설정·이전 실행 파일 백업은 보존했습니다.`입니다. 수동 설치만 사용했고 설치 스크립트가 없다면 자동 시작 미등록·데몬 정지를 확인한 뒤 `~/.local/bin/oni`와 `~/.local/bin/onidot-studio` 두 파일만 제거합니다. 문서·첨부·`instance.json`·이전 root·백업 삭제는 복구할 수 있음을 확인한 뒤 사용자가 별도로 결정합니다. 재설치 후 데이터가 남아 있으면 init 대신 start부터 진행하세요.

### 작업 원장·가이드 CLI 연결

새 원장·가이드 명령은 연결에 REST 주소와 인스턴스 ID가 필요합니다.
로컬 register가 새로 만드는 연결에는 초기화한 인스턴스의 두 값이 자동으로 들어갑니다.
기존 연결에 이 값이 없다면 `oni connection add`의 `--rest-url`·`--instance-id`로
명시합니다. 기존 Wiki 전용 연결의 권한은 자동으로 확대되지 않으므로 웹 설정 → 연결에서
필요한 모듈 권한을 변경하세요. 셀프호스팅 연결은 기존 OAuth 동의 절차를 사용합니다.
명령별 입력은 `oni <명령> --help`에서 확인합니다.

- `oni work …`, `oni handoff …`, `oni session context|bind`는 명시한
  `--connection`, `--instance`, `--space`를 사용합니다.
- `oni guide snapshot`은 입력 JSON의 현재 정책 pin과 멱등 키로 고정판을 만듭니다.
  조회만으로 고정판이나 작업 담당이 생성되지 않습니다.
- `oni session start`는 명시한 하네스를 foreground에서 실행하고 자신이 만든 자식과
  observer를 관리합니다(`session run`은 호환 명령입니다). `--binding-out`에 새
  private binding 경로를 지정합니다. 기존 파일을 덮어쓰지 않습니다.
  다른 터미널에서 `oni session status|stop --binding <경로>`로 조회·종료하고,
  `oni observer start|stop|status --binding <경로>`로 관측만 제어합니다.
  observer 정지는 하네스나 SQLite 서버를 종료하지 않습니다.
- `oni session resume --previous-binding <종료 세션 binding>`에 start와 같은
  등록·하네스 옵션과 새 `--binding-out`을 지정하면, 자신이 실행하고 종료를 관측한
  세션을 확인한 뒤 새 세션을 실행합니다. 새 등록 JSON에는 새 멱등 키와 하네스
  세션 키를 사용합니다. 하네스 자체의 대화 재개 인자는 `--` 뒤에 전달합니다.
  이전 세션과 새 세션은 별도 기록이며 재부팅 뒤 저장된 PID를 재연결하지 않습니다.
- 응답 유실로 결과가 불명확하면 같은 binding으로 status를 확인합니다. 등록 요청은
  같은 JSON·멱등 키로 재시도하며 이미 실행한 세션은 다시 실행하지 않습니다.
  프로세스는 종료했지만 서버 기록이 실패했다면 같은 binding으로 stop을 재시도합니다.
  결과 불명 요청은 원래 인자를 재사용하고, 확정 CAS 충돌 뒤에만 최신 값을 사용합니다.
  관리 소켓 경로가 OS 길이 제한을 넘으면 짧은 private `--runtime-dir`을 사용합니다.
- `oni hook --binding … --delivery …`는 고정판 하네스의 이벤트를 받습니다.
  서버가 오프라인이어도 기록 이벤트는 먼저 로컬 큐에 남깁니다. 기록 단계의
  상한은 200ms이고 SessionStart 문맥 조회·주입은 별도 최대 3초입니다.
  조회 시간 초과에는 주입을 생략하고 누락 상태를 남겨 다음 호출에서 재시도합니다.
  `--protect`는 현재 세션에 연결된 일의 서버 완료·승인 조건을 조회합니다. 조건
  미충족은 차단하며 3회 연속 차단 뒤 다음 요청에는 보류로 종료합니다. 시간 초과와
  인증 실패도 보류하며 완료·승인을 만들지 않습니다. 실제 상태 변경은 서버가 별도로
  검증합니다. 서버 조회 실패를 로컬 성공이나 승인으로 바꾸지 않습니다.
- `oni queue status`는 네트워크 없이 큐 상태를 확인합니다. `queue flush`는 별도
  collector 연결과 0600 Ed25519 개인키 파일을 명시하며, 확인한 인스턴스로만
  서명해 전송합니다. 권한 거부는 큐 보류로 남기고 새 요청으로 우회하지 않습니다.
- `oni ledger doctor --binding …`는 원장·guide freshness·지원 이벤트와 큐 진단을
  제공합니다. 기존 `oni doctor`의 연결 진단과 구분됩니다.

전체 출시 판정과 실제 하네스 대화·사용자 설정 반영은 별도 확인 대상입니다.
