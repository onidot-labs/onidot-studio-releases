# 셀프호스팅 인스턴스와 로컬 인스턴스 함께 사용하기

원격의 허용된 자료를 참고하면서 이 기기에서 만든 문서는 로컬에만 저장하는 경로입니다. 두 인스턴스는 서로 다른 DB·첨부·주인 계정과 인스턴스 설정을 가집니다. 이 연결은 AI가 두 서버에 각각 접근하는 것이며, 서버끼리 내용을 자동 동기화하거나 복제하지 않습니다.

## 1. 각각 설치하고 로그인하기

먼저 [셀프호스팅 가이드](self-hosted.md)의 설치·TLS·비밀번호로 첫 주인 계정 만들기와 [로컬 가이드](local.md)의 설치·init·`oni open` 로그인을 끝냅니다. 셀프호스팅의 onidot 계정 로그인은 선택입니다. 두 인스턴스를 같은 사람이 사용하더라도 인스턴스 ID·저장소·접근 승인은 별개입니다.

예시에서는 셀프호스팅 MCP가 `https://studio.example.com/mcp`, 로컬 MCP가 `http://127.0.0.1:18181/mcp`입니다. 실제 셀프호스팅 주소로 바꾸세요. 인스턴스를 물리적으로 어디에 놓았는지는 가정하지 않습니다.

| 연결 별칭 | AI 도구 등록 이름 | 연결 모드 | 허용 목적 |
| --- | --- | --- | --- |
| `remote` | `onidot-remote` | READ | 사용자가 승인한 셀프호스팅 Space 참고 |
| `local` | `onidot-local` | WRITE | 로컬에서 만든 문서 저장·수정 |

## 2. 서로 다른 승인으로 연결하기

AI를 실행할 기기·사용자 계정에서 다음을 실행합니다. 먼저 `oni connection list`로 기존 설정을 확인합니다. 앞의 셀프호스팅 가이드를 WRITE로 따라왔다면 remote 연결도 WRITE인 상태입니다. 이 경우 `oni login --connection remote --logout`으로 기존 승인을 해제한 뒤 `oni connection remove --alias remote`로 그 연결만 제거하고 아래 READ 설정을 추가합니다. 서버 회수가 실패했다면 웹의 연결된 앱에서도 기존 WRITE 승인을 해제하세요. 같은 별칭의 다른 연결이나 다른 AI 등록은 지우지 않습니다. 이미 아래와 같은 URL·mode라면 connection add는 생략합니다.

```sh
oni connection add --alias remote --url https://studio.example.com/mcp --mode READ
oni login --connection remote
oni connection add --alias local --url http://127.0.0.1:18181/mcp --mode WRITE
oni login --connection local
oni connection list
```

**사용자 승인 단계:** remote 동의 화면에서는 필요한 Space만 선택하고 READ를 승인합니다. 전체 Space 접근을 무심코 선택하지 마세요. local에서는 문서를 저장할 Space와 WRITE를 승인합니다. 결과에는 `remote READ`, `local WRITE`가 표시되어야 합니다. 모드가 다르면 진행하지 말고 해당 연결을 로그아웃·제거한 뒤 올바른 모드로 추가하고 재인가하세요.

```sh
oni register claude --connection remote
oni register claude --connection local
oni register codex --connection remote
oni register codex --connection local
oni doctor --connection remote
oni doctor --connection local
```

사용하는 AI 클라이언트의 register만 실행합니다. 기대 등록 이름은 `onidot-remote`와 `onidot-local`입니다. 이미 같은 이름으로 등록돼 있으면 `unchanged`가 정상입니다. doctor의 remote 결과는 서버가 알리는 모드 READ·승인 Space 목록·쓰기 도구 비노출, local 결과는 WRITE·쓰기 가능 도구 표시입니다. 연결 이름만으로 권한이 바뀌지는 않으며 서버의 credential 모드와 Space 승인도 일치해야 합니다.

## 3. 처음 한 번 직접 확인하기

AI의 새 대화에서 다음 순서로 확인합니다.

1. `onidot-remote`와 `onidot-local` 각각의 인스턴스 별칭·모드와 `list_spaces` 결과를 요청합니다. remote에는 승인한 Space만 보여야 합니다. Space 이름이 같아도 인스턴스와 ID로 구별하세요.
2. remote의 도구 목록에서 `save_page` 같은 쓰기 도구가 보이지 않는지 확인합니다. `oni doctor --connection remote`도 실제 tools/list를 점검합니다. 목록이 일부만 조회되었다는 안내가 있으면 전체를 확인한 것으로 판단하지 마세요.
3. remote에서 사용자에게 읽기 권한이 있는 페이지 하나를 조회하고, **사용자가 복사를 허용한 내용만** local의 선택한 Space에 짧은 “연결 확인” 문서로 저장·발행·재조회합니다. 결과 링크와 로컬 웹을 대조하세요. 원격 문서를 읽는 승인이 대량 복사 승인은 아닙니다.
4. 서버 수준 검증이 필요한 운영자는 별도의 폐기 가능한 검증 인스턴스에서 READ credential로 `tools/call`의 쓰기 도구를 직접 호출해 거부를 확인합니다. 예상 결과는 `isError=true` 및 권한 거부이며 변경은 없어야 합니다. 실제 소중한 Space에서 성공할 수도 있는 생성 요청을 시험 삼아 보내지 마세요. 일반 AI가 숨겨진 도구를 선택하지 못하는 것만으로 직접 호출 거부를 검증했다고 기록하지 않습니다.

READ에서 쓰기 도구가 보이거나 직접 호출이 성공하면 정상으로 쓰지 말고 [문제 해결](troubleshooting.md#readwrite나-인스턴스가-맞지-않을-때)로 이동하세요. 모드를 임의로 WRITE로 올려 해결하지 않습니다.

## 4. 매번 저장 대상을 분명히 하기

AI에 다음처럼 요청하세요.

> onidot-remote의 승인된 Space에서 관련 문서를 읽어 참고해 주세요. 이번 작업 결과는 onidot-local의 제가 선택한 Space에만 저장하고 발행본을 재조회해 주세요. 저장 전에 인스턴스와 Space를 확인해 주세요.

기대 결과는 remote 조회 근거와 local 발행 페이지 링크가 분리되어 있는 것입니다. 원격이 연결되지 않으면 조회 실패 범위를 알리고, 로컬이 연결되지 않으면 저장 실패로 알려야 합니다. 다른 인스턴스로 우회 저장하거나 자동 복제·fallback하지 않습니다. 자료의 회사·개인 구분과 이동 허용 여부는 사용자가 결정합니다.

## 5. 백업·업데이트·복원·연결 해제

- 로컬 데이터는 [로컬 백업과 복원](local.md#5-백업과-복원)을 사용합니다. 로컬의 `oni backup`이 remote 서버를 백업하지는 않습니다.
- 셀프호스팅 데이터는 [서버 백업](self-hosted.md#6-백업과-복구)을 사용합니다. 인스턴스마다 DB·첨부·비밀 설정·버전을 따로 보관합니다.
- 두 서버의 업데이트는 각각 진행합니다. 클라이언트의 `oni`와 그 옆 로컬 `onidot-studio`는 같은 패키지 버전을 유지합니다. 원격 서버 업데이트 후에는 `oni doctor --connection remote`로 다시 확인합니다.
- 로컬 복원 후 local 연결을 재인가하고 remote가 여전히 READ인지 확인합니다. 서버 복구 후에는 해당 서버의 자격증명 처리 결과에 따라 재인가합니다. 한 인스턴스의 토큰 파일을 다른 인스턴스에 복사하지 않습니다.

remote 연결만 해제하는 예시입니다.

```sh
oni login --connection remote --logout
oni connection remove --alias remote
```

그 뒤 AI 클라이언트에서 `onidot-remote` 등록만 제거합니다. `onidot-local`·다른 등록·원격 문서·로컬 데이터는 삭제하지 않습니다. 로그아웃 때 서버 회수를 확인하지 못했다는 메시지가 나오면 해당 인스턴스 웹의 연결된 앱에서도 해제하세요.
