# 셀프호스팅 인스턴스를 여러 기기에서 사용하기

서버 기기에 PostgreSQL·첨부를 두고 다른 기기의 웹·AI 도구에서 접속하는 경로입니다. 이 가이드는 **Docker로 전용 PostgreSQL을 실행하고 네이티브 `onidot-studio` 서버를 실행**하는 구성을 기준으로 합니다. SQLite의 loopback 서버를 외부에 노출하는 방식은 아닙니다. 물리적인 설치 장소는 자유롭게 선택하세요.

## 1. 준비할 것

- [설치 안내](README.md)의 지원 OS에 같은 버전 `oni`·`onidot-studio`를 설치합니다. 서버 기기의 터미널·파일·Docker 관리 권한이 필요합니다. 로컬 설치형의 OS별 검증 결과가 이 PostgreSQL·TLS 배치 전체를 검증한 결과는 아닙니다. 아래 구성으로 실제 로그인·문서·첨부·MCP·복구를 확인하세요.
- PostgreSQL용 Docker와, 공개 HTTPS를 제공할 역프록시를 준비합니다. 기존 DB와 역할을 공유하지 않는 전용 PostgreSQL을 사용합니다.
- 예시 공개 주소 `https://studio.example.com` 대신 실제 도메인을 정하고 DNS를 서버로 연결합니다. 외부에는 역프록시의 HTTPS만 공개하고 DB 포트와 서버 내부 포트는 공개하지 않습니다.
- 첫 주인은 서버의 설정 코드로 비밀번호 계정을 만듭니다. onidot 계정 로그인은 필요할 때 [선택 설정](#선택-onidot-계정-로그인)을 추가합니다.

## 2. 전용 PostgreSQL과 저장 폴더

사용자 관리 경로에 새 폴더를 만들고 그곳에서 실행합니다. 예시 포트 `55432`가 이미 사용 중이면 새 빈 포트를 선택하고 아래 DATABASE_URL도 함께 바꾸세요. 실제 운영 DB를 가리키지 않습니다.

```sh
mkdir -p "$HOME/onidot-server/secrets" "$HOME/onidot-server/storage"
chmod 700 "$HOME/onidot-server" "$HOME/onidot-server/secrets" "$HOME/onidot-server/storage"
cd "$HOME/onidot-server"
```

사용자가 비밀 관리 도구로 `secrets/postgres-password`를 만들고 권한 `0600`으로 보호합니다. 비밀번호를 아래 YAML에 쓰지 않습니다. `compose.yaml`을 다음 내용으로 만드세요.

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres-password
    secrets:
      - postgres-password
    ports:
      - "127.0.0.1:55432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 20
secrets:
  postgres-password:
    file: ./secrets/postgres-password
volumes:
  postgres-data:
```

```sh
docker compose up -d --wait db
docker compose exec db createdb -U postgres onidot_studio
onidot-studio bootstrap-sql modules > bootstrap-modules.sql
onidot-studio bootstrap-sql gate > bootstrap-gate.sql
docker compose exec -T db psql -X -U postgres -v ON_ERROR_STOP=1 \
  -d onidot_studio < bootstrap-modules.sql
docker compose exec -T db psql -X -U postgres -v ON_ERROR_STOP=1 \
  -d onidot_studio < bootstrap-gate.sql
```

기대 결과는 DB 서비스 healthy, DB 생성, 두 SQL 실행의 종료 코드 0·COMMIT입니다. createdb가 이미 존재한다고 하면 빈 신규 설치인지 확인하고 기존 DB를 삭제하지 마세요. bootstrap은 역할·스키마·권한을 준비하며 문서 테이블 migration은 서버 기동 때 실행합니다. 고정된 역할 이름의 기존 `doraft_` 접두어는 호환 계약이므로 임의로 바꾸지 않습니다. 다른 제품이 쓰는 클러스터에 이 bootstrap을 실행하지 마세요.

역할 비밀번호는 bootstrap이 만들지 않습니다. 사용자만 볼 수 있는 대화형 psql에서 각 비밀번호를 설정합니다.

```sh
docker compose exec db psql -X -U postgres -d onidot_studio
```

```text
\password doraft_platform
\password doraft_workspace
\password doraft_wiki
\password studio_gate
\q
```

각 값을 `secrets/platform-password`, `workspace-password`, `wiki-password`, `gate-password`에 따로 보관합니다. 파일은 한 줄·현재 사용자 소유·`0600`으로 보호합니다. 비밀값을 SQL 문자열·셸 히스토리에 남기지 않습니다.

```sh
umask 077
openssl rand -hex 32 > secrets/receipt-secret
```

receipt-secret은 최초 설치 때 한 번 생성하고 백업·재기동·업데이트 시 보존합니다. 이 파일을 매번 새로 만들지 않습니다.

## 3. 서버 환경과 TLS

같은 폴더에 `server.env`를 만듭니다. 아래의 도메인·경로는 실제 값으로 바꿉니다. 파일에는 **값이 아닌 비밀 파일 경로**만 둡니다.

```sh
ONIDOT_STUDIO_LISTEN=127.0.0.1:18081
ONIDOT_STUDIO_PUBLIC_ORIGIN=https://studio.example.com
ONIDOT_STUDIO_DATABASE_ENGINE=postgres
ONIDOT_STUDIO_DATABASE_URL='postgres://127.0.0.1:55432/onidot_studio?sslmode=disable'
ONIDOT_STUDIO_INSTANCE_ALIAS=remote
ONIDOT_STUDIO_DEPLOYMENT_MODE=self-hosted
ONIDOT_STUDIO_STORAGE_ROOT="$HOME/onidot-server/storage"
ONIDOT_STUDIO_DB_PLATFORM_PASSWORD_FILE="$HOME/onidot-server/secrets/platform-password"
ONIDOT_STUDIO_DB_WORKSPACE_PASSWORD_FILE="$HOME/onidot-server/secrets/workspace-password"
ONIDOT_STUDIO_DB_WIKI_PASSWORD_FILE="$HOME/onidot-server/secrets/wiki-password"
ONIDOT_STUDIO_DB_GATE_PASSWORD_FILE="$HOME/onidot-server/secrets/gate-password"
ONIDOT_STUDIO_RECEIPT_SECRET_FILE="$HOME/onidot-server/secrets/receipt-secret"
ONIDOT_STUDIO_TRUSTED_PROXIES=127.0.0.1/32,::1/128
```

DATABASE_URL에는 사용자·비밀번호를 넣지 않습니다. `sslmode=disable`은 위의 같은 기기 loopback DB 전용 예시입니다. 원격 DB라면 DB 관리자의 TLS 설정을 적용하세요. PUBLIC_ORIGIN은 경로와 끝 `/` 없는 HTTPS origin입니다. SHARE_SECRET을 별도로 주지 않으면 RECEIPT_SECRET을 사용합니다. 값과 같은 이름의 `_FILE`을 동시에 설정하지 않습니다.

서버는 HTTP listener이며 직접 인증서를 받는 명령이 없습니다. 같은 기기의 역프록시를 `127.0.0.1:18081`로 연결하고 다음 조건을 적용합니다.

- 실제 도메인의 유효한 TLS 인증서와 443 listener를 사용합니다. 도메인 소유 확인·인증서 발급·갱신은 역프록시 운영자가 수행합니다.
- `/`, `/auth/*`, `/setup`·`/setup/*`, `/invite`·`/invite/*`, `/reset`·`/reset/*`, `/mcp`, `/.well-known/*`의 경로·메서드·쿼리를 그대로 전달합니다. Authorization 헤더와 MCP 세션 헤더, 장시간 MCP 응답을 보존합니다.
- 전달 헤더 `X-Forwarded-For`, `X-Forwarded-Proto`, `X-Forwarded-Host`는 프록시가 설정합니다. `TRUSTED_PROXIES`는 서버가 실제로 보는 프록시 IP/CIDR만 지정합니다.
- MCP 응답을 버퍼링하거나 짧은 timeout으로 잘라서는 안 됩니다. 일반 웹과 같은 host의 `/mcp`를 사용하면 별도 MCP 도메인이 필요하지 않습니다.

이미 설치한 nginx의 HTTPS `server` 안에 둘 upstream 예시입니다. 인증서 경로와 `server_name`은 자신의 nginx 설정에서 준비하세요.

```nginx
location / {
    proxy_pass http://127.0.0.1:18081;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_buffering off;
    proxy_read_timeout 3600s;
}
```

전체 TLS/DNS 설정은 운영 환경마다 다릅니다. 이 예시만 붙여 넣으면 인증서가 자동 발급되는 것은 아닙니다. 역프록시 설정 검사를 통과하고 도메인에서 인증서 오류가 없는지 확인한 뒤 주인 로그인을 진행합니다.

## 4. 기동과 첫 로그인

서버 기기에서 자신이 작성한 환경 파일을 읽고 전경으로 시작합니다.

```sh
cd "$HOME/onidot-server"
set -a
. ./server.env
set +a
onidot-studio serve
```

다른 터미널에서도 아래와 같이 같은 환경 파일을 읽은 뒤 확인합니다. 앞 터미널에서 설정한 환경은 새 터미널로 자동 전달되지 않습니다.

```sh
cd "$HOME/onidot-server"
set -a
. ./server.env
set +a
onidot-studio healthcheck
curl -fsS http://127.0.0.1:18081/ready
curl -fsS https://studio.example.com/ready
onidot-studio setup-code
```

healthcheck 종료 0과 `/ready` HTTP 200은 DB·migration 준비를 뜻합니다. setup-code는 코드와 공개 `/setup` 주소를 출력합니다. 비밀 출력은 사용자만 보고 기록하지 않습니다. 접속할 기기의 브라우저로 `https://studio.example.com/setup`을 열어 24시간·1회용 코드와 이메일·표시 이름·비밀번호·비밀번호 확인을 입력해 첫 주인 계정을 만드세요. 비밀번호는 12~128자이며 계정 이메일과 같으면 사용할 수 없습니다. Space와 문서를 만들고 다시 읽으면 첫 사용 확인이 끝납니다.

기동 시 설정 오류는 누락된 키를 고쳐 다시 실행합니다. 역할 인증 실패는 역할별 비밀번호와 파일을, storage 오류는 실제 절대경로·권한을 확인합니다. 이미 주인가 있으면 기존 계정으로 로그인합니다. 긴급 복구는 동일 환경의 서버 기기에서 `onidot-studio emergency-login`을 실행하고 출력 링크를 10분 안에 열어 확인합니다.

일상 운영에서는 자신의 서비스 관리자에 동일 사용자·환경·절대 바이너리 경로를 등록해 SIGTERM 정상 종료와 재시작을 관리하세요. 전경 예시는 터미널을 닫으면 상시 운영을 보장하지 않습니다. 로컬용 `oni daemon`은 이 PostgreSQL 서버의 서비스 관리 명령이 아닙니다.

### 계정·로그인 수단·구성원 관리

`/settings/account`에서 이메일·표시 이름과 비밀번호, onidot 계정 연결, 복구 코드, 로그인 세션을 관리합니다. 민감한 변경은 로그인한 지 15분 이내인 세션이 필요하며, 다시 인증하라는 안내가 나오면 같은 계정으로 다시 로그인하세요. 로그인을 마친 뒤 원래 설정 화면으로 돌아옵니다.

- 복구 코드는 10개를 한 번만 보여 줍니다. 본인만 접근할 수 있는 곳에 보관하세요. 다시 만들면 이전 코드는 모두 폐기됩니다. 비밀번호 로그인이 허용된 환경에서는 로그인 화면의 복구 코드 링크(`/auth/recovery`)로 이메일·코드를 입력할 수 있습니다. 성공한 코드는 한 번만 쓰며, 계정 화면에서 남은 수를 확인하고 새 로그인 수단을 등록하세요.
- 세션 목록에서 로그인 시각·마지막 사용·로그인 수단·브라우저·현재 세션을 확인하고 하나를 종료하거나 현재 세션을 제외한 나머지를 종료할 수 있습니다.
- 사용할 수 있는 마지막 로그인 수단은 삭제할 수 없습니다. 복구 코드는 마지막 수단 계산에 포함되지 않습니다.

주인은 `/settings/instance/login`에서 비밀번호·onidot 계정 로그인 수단 정책을 정합니다. 적어도 한 수단을 유지해야 하며, 주인이나 기존 계정이 사용할 수단을 잃는 정책 변경은 거부됩니다. 비밀번호를 끄기 전에 해당 계정에 사용할 수 있는 onidot 연결을 준비하세요. onidot만 허용하면 복구 코드 로그인도 닫힙니다.

주인은 `/settings/instance/people`에서 구성원 초대 링크를 만들고 복사해 전달합니다. 받은 사람은 링크를 열어 이메일·이름·비밀번호로 계정을 만듭니다. onidot 계정 로그인을 켰으면 그 방식으로도 가입할 수 있으며, 이메일을 지정한 초대는 검증된 onidot 이메일이 일치해야 합니다. 초대는 만료·일회용이며 메일 서버 없이 직접 전달할 수 있습니다. 기존 구성원의 비밀번호 복구에는 같은 관리 화면에서 24시간·일회용 재설정 링크를 만들어 전달합니다. 재설정을 마치면 그 계정의 기존 브라우저 세션을 끝내고 새 세션으로 로그인합니다. AI 연결·PAT는 유지되며, 필요하면 별도로 회수하세요.

주인 계정에 접근할 수 없으면 서버 기기에서 같은 환경 설정을 읽고 `onidot-studio emergency-login`을 실행합니다. 출력된 10분·일회용 링크를 직접 열어 확인한 뒤 계정 설정에서 수단을 복구하세요. 비밀번호 수단이 꺼져 있으면 최근 비상 로그인한 주인에게 표시되는 **비밀번호 로그인 복구**에서 새 비밀번호 등록과 수단 활성화를 함께 확인합니다. 링크는 주인 계정에 접근하는 비밀이며 공유하거나 로그에 남기지 않습니다.

### 선택: onidot 계정 로그인

자체 비밀번호 계정으로 사용할 수 있으므로 이 설정은 선택입니다. 운영자가 onidot 로그인 서비스 `https://accounts.onidot.com/clients`에 로그인해 다음 순서로 인스턴스용 client를 등록합니다.

1. 새 client의 이름과 redirect URI `https://studio.example.com/auth/oidc/callback`을 입력합니다. 실제 공개 주소의 scheme·host·port·path가 정확히 일치해야 합니다.
2. 표시된 client ID·secret을 보관합니다. secret은 본인 소유 `0600` 파일 `secrets/oidc-client-secret`에 넣으며 비밀값을 명령 인자·로그·대화에 붙여 넣지 않습니다.
3. `server.env`에 다음 설정을 함께 추가합니다. client ID는 발급받은 값으로 바꿉니다.

```sh
ONIDOT_STUDIO_OIDC_ISSUER=https://accounts.onidot.com
ONIDOT_STUDIO_OIDC_CLIENT_ID=발급받은-client-id
ONIDOT_STUDIO_OIDC_CLIENT_SECRET_FILE="$HOME/onidot-server/secrets/oidc-client-secret"
```

4. 새 환경으로 서버를 재시작하고 주인이 `/settings/instance/login`에서 onidot 계정 로그인을 켭니다. 설정 상태와 client 등록 바로가기를 확인하세요. 각 사용자는 `/settings/account`에서 최근 인증 후 자기 onidot 계정을 연결합니다.
5. 로그인 화면에서 onidot 계정 로그인과 인스턴스로 돌아오는 흐름을 확인합니다. 이메일이 같다는 이유로 기존 인스턴스 계정에 자동 연결하지 않습니다.

client 목록에서는 redirect URI 변경, secret 재발급, client 삭제를 관리합니다. secret을 재발급하면 서버의 비밀 파일도 교체하고 재시작하세요. client를 삭제하거나 연결을 끊기 전에 사용할 비밀번호 등 남은 수단을 확인합니다. 공개 주소는 HTTPS로 운영하며, 서버 설정만 성공했다고 실제 로그인이 검증된 것은 아닙니다.

### 문서·Space를 다른 사람과 공유하기

문서의 공유 화면에서 일반 액세스를 **제한됨** 또는 **인스턴스 구성원**으로 정합니다. 인스턴스 구성원을 선택하면 이 인스턴스의 활성 주인·구성원이 링크로 문서를 열고, 선택한 보기·편집 권한을 사용합니다. 게스트에게는 이 일반 액세스가 적용되지 않습니다. 제한됨으로 바꾸어도 상위 문서에서 받은 권한은 그대로일 수 있으므로 적용 전에 영향 미리보기를 확인하세요.

기존 계정은 이름·이메일 앞부분으로 찾아 문서에 직접 추가합니다. 새 사람은 이메일과 보기·편집 권한을 정해 게스트 초대 링크를 만들고 복사해 전달합니다. Space 전체를 공유하려면 Space 구성원 관리에서 VIEWER(보기) 또는 MEMBER(편집)를 지정합니다. 게스트는 `/shared`의 공유받은 항목에서 허용된 문서·Space만 사용하며 새 Space·공개 링크·초대를 만들 수 없습니다. 문서만 공유된 사람에게는 Space 전체 가이드·원장이 열리지 않습니다.

초대 수락 뒤 권한 부여가 완료되지 않으면 초대 목록의 재적용으로 다시 시도할 수 있습니다. 대상이 삭제되면 수락할 수 없습니다. 문서 권한은 웹과 AI 도구에 같이 적용되고 AI 연결의 READ/WRITE·허용 Space 범위도 유지됩니다. 문서만 공유된 사용자가 읽을 수 없는 활성 Space 지침이 있으면 문서 변경이 거부될 수 있습니다. 로컬 인스턴스에는 게스트 초대와 인스턴스 구성원 공유 화면을 제공하지 않습니다.

## 5. 다른 기기의 AI 연결

접속할 기기에도 [패키지](README.md)를 설치하고 사용할 Claude Code 또는 Codex가 설치·실행되는지 확인합니다. 원격 접속만 한다면 그 기기에서 `oni init`이나 로컬 daemon을 만들 필요가 없습니다.

```sh
oni connection add --alias remote --url https://studio.example.com/mcp --mode WRITE
oni login --connection remote
oni register claude --connection remote
oni register codex --connection remote
oni doctor --connection remote
```

사용하는 AI 클라이언트의 register만 실행하세요. 사용자 동의 화면에서 remote 인스턴스·대상 Space·WRITE를 확인합니다. 읽기만 할 기기는 `--mode READ`로 등록하고 동의도 READ로 승인합니다. 기대 결과는 등록 이름 `onidot-remote`, doctor의 서버 정체·모드·승인 Space, 해당 모드의 도구 목록입니다. 새 AI 대화에서 승인 Space를 조회하고, WRITE 연결이라면 사용자가 지정한 Space에 확인용 문서를 저장·발행·재조회하세요.

claude.ai처럼 외부에서 접속하는 커넥터에는 **공개 HTTPS MCP URL** `https://studio.example.com/mcp`를 등록하고 브라우저 OAuth 동의를 완료합니다. 커넥터 제공 여부·추가 UI는 클라이언트 계정에 따라 확인해야 합니다. `127.0.0.1` 주소는 외부 서비스가 접속할 수 없습니다. 토큰이나 client secret을 MCP URL에 붙이지 마세요. 커넥터 설정 성공 뒤 실제 Space 조회까지 확인합니다.

## 6. 백업과 복구

`oni backup/restore`와 `onidot-studio local backup/restore`는 로컬 SQLite 전용입니다. PostgreSQL 서버에는 같은 의미의 top-level backup/restore 명령이 없습니다. DB와 첨부의 일관성을 위해 아래 수동 경로에서는 **서버·worker를 완전히 중지한 동안 둘을 복사**합니다. 사용하는 서비스 관리자의 자동 재시작도 먼저 중지하세요.

1. 전경 서버라면 그 터미널에서 Ctrl-C로 정상 종료하고 프로세스 종료를 기다립니다. `/ready`가 더 이상 응답하지 않으며 서버가 storage를 쓰지 않는지 확인합니다. DB는 계속 실행합니다.
2. 서버 폴더에서 새 백업 디렉터리를 만들고 덤프와 첨부를 보관합니다.

```sh
cd "$HOME/onidot-server"
backup_dir="$HOME/onidot-backups/remote-before-update-0.1.0"
umask 077
mkdir -p "$HOME/onidot-backups"
mkdir "$backup_dir"
docker compose exec -T db pg_dump -U postgres -Fc -d onidot_studio \
  > "$backup_dir/database.dump"
tar -czf "$backup_dir/storage.tar.gz" -C "$HOME/onidot-server/storage" .
docker compose exec -T db pg_restore --list < "$backup_dir/database.dump" > /dev/null
tar -tzf "$backup_dir/storage.tar.gz" > /dev/null
```

**각 명령 종료 코드가 0인지 하나씩 확인**하세요. 실패한 덤프를 정상 백업으로 쓰지 않습니다. 추가로 사용자만 접근하는 암호화 보관소에 `server.env`, `compose.yaml`, 역할 비밀번호·설정한 경우의 onidot client secret·receipt/share secret, 두 바이너리 버전·이전 패키지를 보관합니다. 비밀 폴더를 공개 자료에 포함하지 않습니다. DB와 첨부에 같은 백업 시점을 표시한 뒤 서버를 다시 시작합니다. 목록 읽기 성공은 복원 리허설을 대신하지 않습니다.

복구는 원본 DB·storage를 보존하고 새 DB `onidot_restore`·새 storage 경로에 수행합니다. 다음은 같은 전용 PostgreSQL 클러스터에서 역할과 비밀번호가 유지된 경우입니다. 새 클러스터이면 2절의 bootstrap과 역할 비밀번호 설정부터 별도로 완료하세요.

```sh
docker compose exec db createdb -U postgres onidot_restore
docker compose exec -T db psql -X -U postgres -v ON_ERROR_STOP=1 \
  -d onidot_restore < bootstrap-modules.sql
docker compose exec -T db psql -X -U postgres -v ON_ERROR_STOP=1 \
  -d onidot_restore < bootstrap-gate.sql
docker compose exec -T db pg_restore --exit-on-error --clean --if-exists \
  -U postgres -d onidot_restore < "$backup_dir/database.dump"
mkdir "$HOME/onidot-server/storage-restored"
tar -xzf "$backup_dir/storage.tar.gz" -C "$HOME/onidot-server/storage-restored"
```

`--clean`은 **새로 만든 onidot_restore** 안의 초기 schema를 덤프 내용으로 교체합니다. 원래 DB에 이 명령을 실행하지 않습니다. 덤프에서 복구한 DB에 대해 bootstrap 두 명령을 다시 실행해 DB별 CONNECT·search_path 설정을 확인합니다. 같은 버전·보관한 비밀 설정으로 DATABASE_URL의 DB 이름과 STORAGE_ROOT만 새 대상으로 바꾸고, 동시에 두 서버가 같은 공개 주소로 동작하지 않도록 기존 서버를 중지한 상태에서 기동합니다.

`/ready`, 주인 로그인, Space·문서·첨부 다운로드, AI의 실제 조회를 확인합니다. **PG의 수동 덤프 복원은 로컬 복원처럼 세션·PAT·grant를 자동 폐기하지 않습니다.** 유출 대응이나 자격증명 초기화가 필요한 경우 별도 회수·재인가가 필요하며 비밀 설정을 임의로 재생성하는 것으로 대체하지 않습니다. 이 경로의 실제 복원 리허설을 완료하기 전에는 복구 검증 완료로 보지 않습니다.

## 7. 업데이트·실패 복구·제거

업데이트 전 위 백업과 별도 환경·비밀 보관을 끝내고 이전 패키지를 남깁니다. 새 archive·checksum을 검증하고 서버를 정상 중지한 뒤 두 바이너리를 같은 버전으로 바꿉니다. 같은 설정으로 serve를 시작하면 migration이 실행됩니다. `/ready` 외에도 웹 로그인·문서·첨부·MCP 읽기/쓰기를 확인합니다.

실패하면 새 서버를 멈추고 이전 바이너리와 **업데이트 전 백업**을 새 DB·storage에 복구합니다. 새 버전이 migration한 DB를 이전 바이너리로 바로 열지 마세요. 이전 DB·storage·이미지·패키지를 성공 확인 전 삭제하지 않습니다.

컨테이너 서버를 쓰려면 해당 공개 릴리스가 제공하는 검증된 이미지 주소·digest를 사용합니다. 이미지 안 명령은 `/usr/local/bin/onidot-studio serve`, listener는 `0.0.0.0:8080`, 실행 UID/GID는 `10001:10001`, 기본 storage는 `/data/storage`입니다. volume과 secret 파일을 그 UID가 읽고 필요한 storage에 쓰도록 준비해야 합니다. 현재 문서의 네이티브 서버 예시를 그대로 Docker env·파일 경로에 복사하면 안 됩니다. 공개 이미지 주소는 출시 공지에서 확인하며 아직 없는 registry 주소를 추정하지 않습니다.

제거할 때는 서버 서비스를 중지·해제하고 클라이언트에서 해당 연결만 로그아웃·등록 해제합니다. 서버 실행 파일 제거와 DB·storage·secret·백업 삭제를 분리하세요. `docker compose down -v`는 DB volume을 삭제하므로 일반 제거 절차에 포함하지 않습니다. 다시 쓸 수 있도록 데이터를 기본 보존하고 삭제는 사용자가 별도로 결정합니다.

### 작업 원장과 가이드 모듈

선택적으로 원장·가이드를 설치할 때는 서버 바이너리에 포함된 bootstrap을 사용합니다. 소스 checkout은 필요하지 않습니다.

```sh
ONIDOT_STUDIO_INSTALLED_MODULES=core,wiki,guide,ledger \
  onidot-studio bootstrap-sql p2 > bootstrap-p2.sql
docker compose exec -T db psql -X -U postgres -v ON_ERROR_STOP=1 \
  -d onidot_studio < bootstrap-p2.sql
```

추가 역할 `onidot_guide`·`onidot_ledger`에 각기 다른 비밀번호를 설정하고 `0600` 파일로 보관합니다. 서버 환경에 `ONIDOT_STUDIO_DB_GUIDE_PASSWORD_FILE`·`ONIDOT_STUDIO_DB_LEDGER_PASSWORD_FILE`을 지정하고 `ONIDOT_STUDIO_INSTALLED_MODULES=core,wiki,guide,ledger`로 설정합니다. `ONIDOT_STUDIO_MODULES`에는 활성화할 모듈을 넣습니다. 비밀번호를 명령 인자나 로그에 넣지 마세요.

기능을 꺼도 설치 로스터와 역할 비밀번호는 보존해야 기존 정본을 계속 읽을 수 있습니다. 기존 Wiki 연결에 추가 모듈 권한이 자동 부여되지 않으므로 원장·가이드를 사용할 때는 OAuth 동의에서 필요한 권한을 선택합니다.

첫 공개 버전의 신규 설치에는 과거 assistant 기록 전환이 필요하지 않습니다. 비공개 시험 버전에서 데이터를 이전하는 운영자는 해당 버전의 전환 절차와 호환 바이너리를 별도로 확보해야 합니다. 공개 패키지는 개발자용 전환 실행기나 비공개 소스를 포함하지 않습니다. 이미 CANONICAL로 전환한 데이터를 옛 writer로 다시 열지 말고, 검증한 호환 바이너리와 백업을 보존하세요.
