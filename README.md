# Onidot Studio 사용 가이드

Onidot Studio는 사람이 관리하는 문서(Wiki)와 연결한 AI의 개인 지식(Knowledge)을 자신이 고른 곳에 보관합니다. 0.3.0부터 하나의 실행 파일 `onidot-studio`로 두 가지 방식을 제공합니다.

| 사용 방법 | 저장 위치와 준비물 | 안내 |
| --- | --- | --- |
| 이 Mac에서만 사용(로컬 단독 모드) | 이 Mac의 로컬 Wiki, 로그인 없음 | [로컬 단독 모드](docs/local.md) |
| 서버를 운영하고 여러 기기에서 접속(Self-host) | PostgreSQL 16/18, 첨부 폴더, 도메인·TLS | [Self-host 서버](docs/self-hosted.md) |

작업 기록·지침·PC 런타임은 [Onidot Orbit](https://orbit.onidot.com)(`oni`)이 맡습니다. 공통 오류는 [문제 해결](docs/troubleshooting.md)을 보세요.

현재 공개 버전은 **0.3.2**입니다. 설치 파일은 [공개 릴리스](https://github.com/onidot-labs/onidot-studio-releases/releases/tag/v0.3.2)에서 받습니다.

## 0.2.x에서 바뀐 점

- 실행 파일 `oni`·`oni-local`·`oni-server`와 `oni update`가 없어지고 `onidot-studio` 하나가 됐습니다. `oni` 이름은 Onidot Orbit이 씁니다.
- 지침(guide)·작업 원장(ledger)·AI 기록(remember·recall)은 Studio에서 빠졌습니다. 작업 기록은 Orbit, AI 기억은 개인 Knowledge(`knowledge_*` 도구)를 씁니다.
- 옛 로컬 인스턴스(`oni local`)의 문서는 [로컬 단독 모드](docs/local.md)의 「옛 oni local에서 옮기기」로 가져옵니다. 0.2.x의 `oni update`로는 0.3.x로 올라가지 않습니다(설치 스크립트가 아무것도 바꾸지 않고 안내만 합니다).

## 빠른 설치(macOS Apple Silicon)

```sh
version=0.3.2
base="https://github.com/onidot-labs/onidot-studio-releases/releases/download/v$version"
work=$(mktemp -d) && cd "$work"
curl -fsSLO "$base/install.sh"
sh install.sh --version "$version"
"$HOME/.local/bin/onidot-studio" version
```

기대 결과: `설치 완료: onidot-studio 0.3.2 (darwin-arm64)`. 설치 스크립트는 배포물을 `SHA256SUMS`로 검증한 뒤 `~/.local/bin/onidot-studio` launcher와 `~/.local/lib/onidot/studio/releases/…` 실행물을 둡니다. `sudo`·셸 설정 변경은 하지 않습니다. 같은 prefix의 Orbit `oni`는 바꾸지 않습니다.

0.2.x 이하가 같은 폴더에 둔 `onidot-studio` 파일이 있으면 설치가 거부됩니다. 옛 설치를 정리할 준비가 됐으면 `sh install.sh --version "$version" --replace-legacy`로 옛 파일을 `~/.local/lib/onidot/studio/legacy/`에 옮겨 보존한 뒤 설치합니다.

Linux 서버는 컨테이너 배포물로 설치합니다([Self-host 서버](docs/self-hosted.md)).

## 릴리스 파일

| 파일 | 대상 |
| --- | --- |
| `onidot-studio-selfhost-<버전>-darwin-arm64.tar.gz` | macOS Apple Silicon(로컬 단독 모드, 서버 설치) |
| `onidot-studio-selfhost-<버전>-linux-arm64-container.tar.gz` | Linux arm64 컨테이너 이미지 재료 |
| `onidot-studio-selfhost-<버전>-linux-amd64-container.tar.gz` | Linux x86_64 컨테이너 이미지 재료 |
| `SHA256SUMS`, `install.sh` | 체크섬, macOS 설치 스크립트 |

모든 배포물에 개인 Knowledge용 Node 24.18 런타임이 들어 있습니다. 서명·공증은 하지 않았습니다.

## 데이터와 사용 조건

데이터는 사용자가 고른 위치(로컬 단독 모드는 이 Mac, Self-host는 지정한 PostgreSQL·첨부 폴더)에만 저장됩니다. 사용 조건은 [LICENSE](LICENSE)·[사용 조건 초안](docs/TERMS.md)을 보세요. 모든 버전은 0.x이며 정식 출시가 아닙니다.
