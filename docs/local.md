# 로컬 단독 모드(이 Mac에서만 사용)

이 Mac에 로컬 Wiki를 두고 로그인 없이 씁니다. 공통 서비스 관리자가 Wiki 서비스를 설치·기동하며, Onidot Orbit이 같은 Mac에 로컬 Knowledge를 이미 준비했다면 그것을 함께 씁니다. 모든 명령은 결과를 JSON으로 출력하며 자격 증명 값은 출력하지 않습니다.

먼저 [README](../README.md#빠른-설치macos-apple-silicon)대로 `onidot-studio`를 설치합니다. 아래에서 `studio`는 `"$HOME/.local/bin/onidot-studio"`입니다.

```sh
studio="$HOME/.local/bin/onidot-studio"
```

## 1. 설치와 웹 열기

```sh
"$studio" local install
"$studio" local status
"$studio" local open
```

- `local install`: 로컬 Wiki를 준비하고 AI 연결 프로필을 등록합니다. 다시 실행해도 같은 설치로 수렴합니다.
- `local status`: 서비스·연결·권한 준비 상태를 따로 보고합니다. 아무것도 만들거나 기동하지 않습니다.
- `local open`: 이 Mac에서만(127.0.0.1) 웹 화면을 열고 Ctrl-C로 닫습니다. 로그인 대신 60초·1회용 링크로 브라우저를 엽니다. `--no-browser`는 링크를 표준 오류로만 출력합니다. 링크를 다른 사람에게 보내지 않습니다.

## 2. AI 클라이언트 연결

로컬 Wiki의 MCP는 stdio 명령 `onidot-studio local mcp`입니다. 실행할 때마다 로컬 Wiki를 준비하고 현재 주소로 연결합니다. onidot-studio 플러그인은 `local install`이 등록한 연결 프로필을 씁니다. 직접 등록할 때는 다음처럼 합니다.

```sh
claude mcp add onidot-local -- "$HOME/.local/bin/onidot-studio" local mcp
codex mcp add onidot-local -- "$HOME/.local/bin/onidot-studio" local mcp
```

### 문서 나누기와 파일 첨부(0.3.1부터)

- **Space 여러 개**: AI에게 `create_space`로 Space를 만들게 하면 프로젝트별로 문서를 나눠 둘 수 있습니다. 혼자 쓰는 분류용이라 구성원·권한·공유는 없습니다.
- **파일 경로로 첨부**: AI가 `attach_local_file`에 이 Mac의 파일 절대경로를 주면 로컬 Wiki가 파일을 직접 읽어 페이지에 붙입니다. 큰 PDF도 curl 없이 한 번에 붙습니다.
  - 홈 폴더 안의 일반 파일만 읽습니다.
  - `~/.ssh`·키체인·브라우저 프로필·AI 에이전트 설정(`~/.claude`·`~/.codex`) 같은 비밀 위치와 onidot 저장소는 항상 거부합니다.
  - 거부되면 AI가 다른 경로로 우회하지 않고 알려 줍니다.
- 0.3.2부터 한도를 넘는 파일은 다 읽기 전에 바로 거절하고, 읽는 중 파일이 바뀌어 실패하면 업로드 자리를 바로 돌려줍니다. 같은 실패를 되풀이해도 업로드 한도가 막히지 않습니다.
- 기존 업로드 방식(`create_attachment_upload` 다음 curl)도 그대로 씁니다. 0.3.0에서 로컬 모드의 curl 업로드가 401로 막히던 문제는 0.3.1에서 고쳤습니다.

## 3. 옛 oni local에서 옮기기

0.2.x까지의 로컬 인스턴스(`oni local`, 실행 파일 `oni-local`)의 Wiki 문서·첨부를 새 로컬 Wiki로 가져옵니다. **새 로컬 Wiki를 처음 설치(`local install`)하기 전에** 한 번만 실행합니다. 이미 문서가 있는 로컬 Wiki와는 합치지 않고 거부합니다.

1. 옛 인스턴스가 켜진 상태에서 아직 없는 새 경로로 백업 패키지를 만듭니다(0.2.x 명령). 목적지에 `COMPLETE` 표식이 생겨야 합니다.

   ```sh
   mkdir -p "$HOME/onidot-backups"
   oni local backup "$HOME/onidot-backups/oni-local-final"
   ```

   0.3.x의 Orbit `oni`로 바뀌어 `oni local`이 없으면, 남아 있는 옛 `oni-local`(보통 `~/.local/bin/oni-local`) 또는 0.2.1 압축 파일의 `oni`·`oni-local`로 같은 백업을 만듭니다.

2. 새 `onidot-studio`를 설치합니다. 옛 0.1.x 설치가 남긴 `~/.local/bin/onidot-studio` 파일이 있으면 `--replace-legacy`로 보존 이동합니다([README](../README.md#빠른-설치macos-apple-silicon)).
3. 가져온 뒤 설치합니다.

   ```sh
   "$studio" local import-oni-local --backup "$HOME/onidot-backups/oni-local-final"
   "$studio" local install
   "$studio" local status
   "$studio" local open
   ```

가져오는 것은 Wiki의 Space·문서·이력·첨부와 소유자 연결입니다. 옛 계정·로그인·연결 토큰·공개 공유 링크(회수됨)와 지침(guide)·작업 원장(ledger)은 가져오지 않으며 백업 패키지에 그대로 남습니다. 문서의 소유자가 아닌 다른 사람의 흔적이 있으면 전체를 거부합니다. 실패해도 백업 패키지와 옛 인스턴스는 바뀌지 않으므로 원인을 고친 뒤 같은 명령을 다시 실행합니다. 옮긴 뒤 문서·첨부를 웹에서 확인하기 전까지 옛 인스턴스 데이터와 백업 패키지를 지우지 않습니다.

## 4. 백업과 복원

```sh
"$studio" local backup --destination "$HOME/onidot-backups/local-$(date +%Y%m%d)"
"$studio" local restore --backup "$HOME/onidot-backups/local-20261019"
```

- `local backup`은 로컬 Wiki만 담고 Knowledge는 담지 않습니다(Knowledge는 Orbit 쪽 백업을 씁니다). 실행 중인 Wiki는 잠시 정지했다 다시 시작하며, 다른 소비자가 쓰고 있으면 거부합니다. 목적지는 아직 없는 새 경로여야 합니다.
- `local restore`는 첫 설치 전에만 실행합니다. 기존 Wiki를 덮어쓰거나 합치지 않습니다. 중단되면 같은 명령으로 이어서 마무리합니다.

## 5. 멈추기와 제거

`local stop`은 Studio의 사용 등록만 해제하고, 다른 소비자(예: Orbit)가 없을 때만 로컬 Wiki를 정지합니다. 자료는 지우지 않습니다. AI 클라이언트가 `local mcp`를 실행하면 다시 뜹니다.

launcher를 지울 때도 로컬 Wiki 자료는 남습니다. 자료까지 지우려면 먼저 백업을 확인한 뒤 직접 지웁니다.
