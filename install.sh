#!/bin/sh
# Onidot Studio(0.3.0부터) 설치 스크립트.
# 이 기기용 Self-host 배포물(bundle)을 내려받아 SHA256SUMS로 검증한 뒤, 그 배포물에 든 install.sh로
# launcher(onidot-studio)를 설치합니다. 데이터 폴더·DB·셸 설정은 바꾸지 않습니다.
#
#   sh install.sh --version 0.3.1 [--base-url URL] [--prefix DIR] [--replace-legacy]
#
# 0.2.x까지의 oni·oni-local·oni-server는 0.3.0부터 없습니다. 옛 설치 인자(--local·--server·--bin-dir·
# --update·--no-restart)로 부르면 아무것도 바꾸지 않고 안내한 뒤 끝냅니다.
set -eu

REPO_URL=https://github.com/onidot-labs/onidot-studio-releases
VERSION=
BASE_URL=
PREFIX=${HOME:?HOME이 필요합니다}/.local
REPLACE_LEGACY=

die() { printf '%s\n' "$*" >&2; exit 1; }
legacy() {
  cat >&2 <<EOF
0.3.0부터 oni·oni-local·oni-server 실행 파일과 'oni update'는 없습니다. 이 스크립트는 아무것도 바꾸지 않았습니다.
- 이 PC의 옛 로컬 인스턴스(oni local)를 쓰고 있었다면 $REPO_URL/blob/main/docs/local.md 의 「옛 oni local에서 옮기기」를 따르세요.
- 작업 기록·지침은 Onidot Orbit(oni)이 맡습니다: https://orbit.onidot.com
EOF
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) [ "$#" -ge 2 ] || die '--version 값이 필요합니다'; VERSION=$2; shift 2;;
    --version=*) VERSION=${1#*=}; shift;;
    --base-url) [ "$#" -ge 2 ] || die '--base-url 값이 필요합니다'; BASE_URL=$2; shift 2;;
    --base-url=*) BASE_URL=${1#*=}; shift;;
    --prefix) [ "$#" -ge 2 ] || die '--prefix 값이 필요합니다'; PREFIX=$2; shift 2;;
    --prefix=*) PREFIX=${1#*=}; shift;;
    --replace-legacy) REPLACE_LEGACY=--replace-legacy; shift;;
    --local|--server|--bin-dir|--bin-dir=*|--update|--no-restart) legacy;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "알 수 없는 인자: $1 (--help 참고)";;
  esac
done

case "$VERSION" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) die '--version x.y.z가 필요합니다(예: --version 0.3.1)';;
esac
case "$VERSION" in *[!0-9.]*) die "버전 형식이 아닙니다: $VERSION";; esac
[ -n "$BASE_URL" ] || BASE_URL="$REPO_URL/releases/download/v$VERSION"
case "$PREFIX" in /*) ;; *) die "--prefix는 절대경로여야 합니다: $PREFIX";; esac

os=$(uname -s); arch=$(uname -m)
case "$os/$arch" in
  Darwin/arm64) target=darwin-arm64;;
  Linux/*) die "Linux 서버는 컨테이너(compose) 설치를 사용합니다. $REPO_URL/blob/main/docs/self-hosted.md 를 따르세요.";;
  *) die "지원하지 않는 환경입니다: $os/$arch (macOS Apple Silicon만 이 스크립트로 설치합니다)";;
esac
command -v curl >/dev/null 2>&1 || die 'curl이 필요합니다'
command -v tar >/dev/null 2>&1 || die 'tar가 필요합니다'
if command -v shasum >/dev/null 2>&1; then sum() { shasum -a 256 "$1" | cut -d' ' -f1; }
elif command -v sha256sum >/dev/null 2>&1; then sum() { sha256sum "$1" | cut -d' ' -f1; }
else die 'shasum 또는 sha256sum이 필요합니다'; fi

name="onidot-studio-selfhost-$VERSION-$target"
work=$(mktemp -d "${TMPDIR:-/tmp}/onidot-studio-install.XXXXXX")
trap 'rm -rf "$work"' EXIT INT TERM
curl -fsSL -o "$work/SHA256SUMS" "$BASE_URL/SHA256SUMS" || die "SHA256SUMS를 받지 못했습니다: $BASE_URL"
curl -fsSL -o "$work/$name.tar.gz" "$BASE_URL/$name.tar.gz" || die "배포물을 받지 못했습니다: $BASE_URL/$name.tar.gz"
want=$(awk -v n="$name.tar.gz" '$2==n || $2=="*"n {print $1}' "$work/SHA256SUMS")
[ -n "$want" ] || die "SHA256SUMS에 $name.tar.gz가 없습니다"
got=$(sum "$work/$name.tar.gz")
[ "$got" = "$want" ] || die "체크섬이 다릅니다: $name.tar.gz (설치하지 않았습니다)"
tar -xzf "$work/$name.tar.gz" -C "$work"
[ -x "$work/$name/install.sh" ] || die "배포물에 install.sh가 없습니다: $name"
sh "$work/$name/install.sh" --prefix "$PREFIX" $REPLACE_LEGACY
printf '설치 완료: onidot-studio %s (%s). launcher: %s/bin/onidot-studio\n' "$VERSION" "$target" "$PREFIX"
