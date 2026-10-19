# Self-host 서버(여러 기기에서 사용)

서버 한 대에 Wiki와 개인 Knowledge를 두고 여러 기기·AI 클라이언트에서 접속합니다. 배포물 안의 `README.md`가 모든 설정 키·명령의 정본이며, 이 문서는 순서만 안내합니다.

## 1. 준비할 것

- PostgreSQL 16 또는 18(외부 서버). 대상 DB는 미리 만들어 둡니다. 설치기는 DB를 만들지 않으며 호스트에 DB 패키지를 설치하지 않습니다. Docker Compose가 있는 호스트에서는 `database.mode: "compose"`로 전용 PostgreSQL을 새로 만들 수도 있습니다.
- 첨부 폴더(절대경로), 설치 root(현재 사용자 소유 0700).
- 비밀 파일: DB URL·관리자 URL·관리자 비밀번호를 각각 0600 파일로 두고 설정 JSON에는 경로만 적습니다.
- 다른 기기에서 쓰려면 도메인과 HTTPS reverse proxy. `publicOrigin`은 브라우저가 여는 주소와 같아야 합니다.
- 백업·복원·update 전 백업에는 Docker와 `postgres:<서버 major>-trixie` 이미지(직접 `docker pull`)가 필요합니다.

## 2. 설치 방식 고르기

| 방식 | 배포물 | 설명 |
| --- | --- | --- |
| macOS 네이티브 | `…-darwin-arm64.tar.gz` | README의 `install.sh`로 launcher를 설치하고 `onidot-studio init --start`로 기동 |
| Linux 컨테이너(compose) | `…-linux-<arch>-container.tar.gz` + 릴리스의 `Dockerfile`·`compose.example.yaml` | 이미지를 만들고 `compose.example.yaml`처럼 서비스 하나로 실행 |

### macOS 네이티브

```sh
studio="$HOME/.local/bin/onidot-studio"
"$studio" preflight --root /absolute/private/studio --config /absolute/config.json
"$studio" init --start --root /absolute/private/studio --config /absolute/config.json
"$studio" status --root /absolute/private/studio
```

`preflight`는 아무것도 바꾸지 않고 설정·권한·포트·디스크·PostgreSQL·Docker를 검사합니다. `init --start`는 초기화와 기동을 한 번에 하며 다시 실행해도 같은 설치로 수렴합니다. `init --interactive --save-config /absolute/config.json`으로 질문에 답해 설정 파일을 만들 수 있습니다. 설정 예시는 배포물의 `config.example.json`입니다.

### Linux 컨테이너

```sh
base=https://github.com/onidot-labs/onidot-studio-releases/releases/download/v0.3.3
mkdir onidot-studio-image && cd onidot-studio-image
curl -fsSLO "$base/SHA256SUMS"
curl -fsSLO "$base/onidot-studio-selfhost-0.3.3-linux-arm64-container.tar.gz"
curl -fsSLO "$base/Dockerfile"
curl -fsSLO "$base/compose.example.yaml"
sha256sum -c SHA256SUMS --ignore-missing
tar -xzf onidot-studio-selfhost-0.3.3-linux-arm64-container.tar.gz
docker buildx build --platform linux/arm64 \
  --build-context bundle=onidot-studio-selfhost-0.3.3-linux-arm64-container \
  --build-arg VERSION=0.3.3 -f Dockerfile -t onidot-studio-selfhost:0.3.3 --load .
```

설치 설정에는 `"runtime": "compose"`, `"listen": "0.0.0.0:8080"`, `publicOrigin`, `"blobRoot": "/data/storage"`를 둡니다. 서비스와 일회성 설치기 컨테이너는 같은 이미지를 쓰며, 비밀 디렉터리 배치·네트워크·외부 접근은 배포물 `README.md`의 「compose 실행 모드」를 따릅니다. x86_64 서버는 `linux-amd64-container` 배포물과 `--platform linux/amd64`를 씁니다.

## 3. 첫 로그인과 연결

- 웹: `publicOrigin`(기본 `http://127.0.0.1:18182`)을 열고 설치 때 지정한 관리자 이메일·비밀번호로 로그인합니다. onidot 계정 로그인(OIDC)은 `oidc.issuer`·`clientId`·`clientSecretFile`로 선택해 연결합니다.
- Wiki MCP: `<publicOrigin>/mcp`(OAuth). 개인 Knowledge MCP: MCP 주소 호스트의 `/knowledge`(같은 호스트면 `/mcp/knowledge`). Knowledge는 Space 없이 계정 단위 READ/WRITE입니다.
- 개인 액세스 토큰: 웹 `설정 > 연결`의 `새 개인 액세스 토큰`. 화면에 한 번만 보입니다.

## 4. 백업과 복구

```sh
"$studio" backup --root /absolute/private/studio --backup /absolute/private/new-backup
"$studio" start --root /absolute/private/studio
"$studio" restore --root /absolute/private/restored --config /absolute/restore-config.json --backup /absolute/private/new-backup
```

백업은 Studio를 정지한 상태로 만들고 정지된 채 끝납니다(결과의 `next` 안내대로 `start`). 백업 폴더 전체를 비밀 자료로 보관합니다. 복원은 새 빈 PostgreSQL 대상과 새 root로만 하며 기존 DB·첨부를 덮어쓰지 않습니다.

## 5. 기존 설치 채택

이미 운영 중인 Studio DB·첨부를 새 배포물로 넘길 때는 `adopt --check`로 읽기 전용 검사를 먼저 하고 `adopt`를 실행합니다. instance id·관리자·연결·OAuth resource를 그대로 이어받습니다. 자세한 조건은 배포물 `README.md`를 따릅니다.

## 7. 업데이트·실패 복구·제거

1. 새 배포물을 받아 검증합니다(README의 `install.sh` 또는 `SHA256SUMS`).
2. `update --check`로 바뀌는 schema·백업 위치를 확인합니다. 아무것도 바꾸지 않습니다.
3. `update`가 사전 검사 → update 전 백업 → 정지 → 마이그레이션 → 교체·기동 → ready 확인을 합니다. 짧은 중단이 있습니다.

```sh
"$studio" update --check --root /absolute/private/studio --bundle /absolute/new-bundle
"$studio" update --root /absolute/private/studio --bundle /absolute/new-bundle
```

- 실패하면 DB·첨부를 그대로 두고 멈춥니다. 원인을 고친 뒤 같은 명령을 다시 실행하면 같은 백업으로 이어 갑니다.
- schema가 그대로일 때만 `update --cancel`·`rollback`이 이전 실행물로 돌아갑니다. schema가 올라간 뒤에는 update 전 백업을 이전 배포물로 새 root·새 DB에 복원합니다.
- compose 실행 모드는 호스트가 서비스를 정지·기동하고 설치기 컨테이너가 `update --prepare`·`update --verify`를 실행합니다.
- `uninstall`은 실행물과 등록만 지우고 DB·첨부·백업·설치 기록·비밀은 남깁니다. 같은 root·설정으로 `init --start`하면 이어받습니다.

## 0.2.x 서버(oni-server)에서 옮기기

0.2.x `oni-server`의 PostgreSQL·첨부는 5절의 채택으로 이어받습니다. 옛 서버를 멈추고 DB 전체 백업을 따로 만든 뒤 `adopt --check`부터 실행합니다. 지침(guide)·작업 원장(ledger) 스키마는 채택하지 않으며 지우지도 않습니다.
