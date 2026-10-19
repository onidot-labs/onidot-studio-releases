# 문제 해결

명령은 결과를 JSON으로 출력합니다. 오류에는 설정 키와 파일 경로가 나오며 비밀 값은 나오지 않습니다. 오류가 나면 다음 단계로 넘어가지 말고 출력 그대로 확인합니다.

## 설치가 거부될 때

- `--replace-legacy`가 필요하다는 오류: 0.2.x 이하가 둔 `~/.local/bin/onidot-studio` 파일이 있습니다. 옛 로컬 인스턴스를 옮길 준비가 됐는지([로컬 단독 모드](local.md#3-옛-oni-local에서-옮기기)) 확인한 뒤 `sh install.sh --version <버전> --replace-legacy`로 다시 실행합니다. 옛 파일은 `~/.local/lib/onidot/studio/legacy/`에 보존됩니다.
- 체크섬 오류: 받은 파일이 손상됐거나 다른 버전입니다. 새 임시 폴더에서 다시 받습니다.
- 0.2.x의 `oni update`가 실패: 0.3.0에는 `oni`·`oni-local`이 없어 설치 스크립트가 아무것도 바꾸지 않고 끝냅니다. README의 빠른 설치를 따릅니다.

## 플러그인 설치·갱신

- AI 클라이언트용 Studio 플러그인은 공개 카탈로그 `onidot-labs/onidot-plugins`의 `onidot-studio@onidot-studio`로 설치·갱신합니다. 옛 `onidot@onidot`을 쓰고 있었다면 옛 플러그인과 마켓 `onidot`을 먼저 지운 뒤 다시 추가해 설치합니다(명령은 [onidot-plugins README](https://github.com/onidot-labs/onidot-plugins#옛-플러그인에서-옮기기)).

## macOS에서 실행이 차단될 때

배포물은 서명·공증하지 않았습니다. 받은 파일의 체크섬을 확인한 뒤 시스템 설정 → 개인정보 보호 및 보안에서 실행을 허용합니다.

## 로컬 단독 모드

- `local status`로 서비스·연결·권한 상태를 따로 확인합니다. 한 부분만 실패해도 나머지는 그대로 보고합니다.
- `import-oni-local`이 "이미 Wiki가 있다"로 거부: 새 로컬 Wiki를 이미 설치했습니다. 가져오기는 첫 설치 전에만 됩니다.
- `local backup`이 다른 소비자 때문에 거부: Orbit 등 다른 프로그램이 로컬 Wiki를 쓰는 중입니다. 그 사용을 멈춘 뒤 다시 실행합니다.
- 새 버전으로 `local install`을 다시 해도 로컬 Wiki가 옛 판 그대로(`wikiAction`이 `reuse`): 0.3.2 이하 설치 도구의 결함입니다. 0.3.3 이상을 설치해 `local install`을 다시 실행하면 새 실행 파일로 바뀝니다([새 버전으로 올리기](local.md#새-버전으로-올리기)).

## Self-host 서버

- `preflight`로 설정·권한·PostgreSQL·Docker를 먼저 확인합니다. 아무것도 바꾸지 않습니다.
- `doctor`·`status`·`logs --root …`로 실행 상태와 로그를 봅니다. 0.3.2부터 서비스 로그는 파일당 10MB, 3개까지만 보관합니다.
- 백업·update 전 백업이 Docker 때문에 거부: `docker`와 `postgres:<서버 major>-trixie` 이미지, 0600 `database.adminUrlFile`을 준비합니다. 설치기는 이미지를 자동으로 받지 않습니다.
- update가 마이그레이션 뒤 실패: DB·첨부는 그대로입니다. 원인을 고쳐 같은 명령을 다시 실행하거나, update 전 백업을 이전 배포물로 새 root·새 DB에 복원합니다([Self-host 서버](self-hosted.md#7-업데이트실패-복구제거)).

## 알려진 제한

- macOS Apple Silicon과 Linux arm64·x86_64 컨테이너만 제공합니다. Windows·Intel Mac은 지원하지 않습니다.
- 로컬 단독 모드의 백업은 Wiki만 담습니다. Knowledge는 Orbit 쪽 백업을 씁니다.
- PostgreSQL 역할 이름이 클러스터 전역 고정이라 PostgreSQL 클러스터 하나에 Self-host 하나만 설치할 수 있습니다.
