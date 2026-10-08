#!/usr/bin/env bash
# Standalone public installer. Requires bash, curl, tar and SHA-256 utilities.
set -euo pipefail
umask 077

fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'EOF'
사용법:
  bash install.sh --base-url <공개 릴리스 자산 URL> --version <0.x.y>
  bash install.sh --base-url <공개 릴리스 자산 URL> --version <0.x.y> --restart
  bash install.sh --autostart enable|disable
  bash install.sh --autostart enable --no-start (정지 유지, 다음 로그인 자동 시작)
  bash install.sh --uninstall
  oni update 관리 전환: --update --no-restart (재기동은 CLI에서 수행)
  모든 작업: --bin-dir <현재 설치 디렉터리> (기본 ~/.local/bin)

URL은 해당 버전의 tar.gz와 SHA256SUMS가 있는 디렉터리입니다. 인증 토큰은 필요하지 않습니다.
업데이트 전 oni backup으로 백업하고 oni daemon stop으로 정지하세요.
자동 시작을 등록했다면 --autostart disable로 먼저 해제하세요.
다른 버전으로 업데이트할 때 --restart로 재기동·doctor까지 확인합니다.
자동 시작 등록은 oni init 뒤 별도로 선택하며, 기본 설치는 서비스나 셸 설정을 바꾸지 않습니다.
제거는 두 실행 파일만 지웁니다. 데이터·설정·백업은 보존합니다.
SHA-256은 다운로드 손상 검사이며 코드 서명이 아닙니다.
EOF
}
version= base_url= bin_dir_override= action=install restart=0 no_restart=0 managed_update=0 no_start=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --version|--base-url|--autostart|--bin-dir)
            [ "$#" -ge 2 ] || fail '옵션 값이 필요합니다.'
            case "$1" in
                --version) version=$2;;
                --base-url) base_url=$2;;
                --bin-dir) bin_dir_override=$2;;
                --autostart) [ "$action" = install ] || fail '작업 옵션을 하나만 선택하세요.'; action=$2
                    case "$action" in enable|disable) ;; *) fail '자동 시작은 enable 또는 disable을 선택하세요.';; esac;;
            esac
            shift 2;;
        --restart) restart=1; shift;;
        --no-restart) no_restart=1; shift;;
        --update) managed_update=1; shift;;
        --no-start) no_start=1; shift;;
        --uninstall) [ "$action" = install ] || fail '작업 옵션을 하나만 선택하세요.'; action=uninstall; shift;;
        --help|-h) usage; exit 0;;
        *) fail '알 수 없는 옵션입니다. --help로 사용법을 확인하세요.';;
    esac
done
[ "$no_start" = 0 ] || [ "$action" = enable ] || fail '--no-start는 --autostart enable에만 사용할 수 있습니다.'
[ "$restart" = 0 ] || [ "$no_restart" = 0 ] || fail '--restart와 --no-restart는 함께 사용할 수 없습니다.'
case "$(uname -s)/$(uname -m)" in
    Darwin/arm64) os=darwin; arch=arm64;;
    Linux/x86_64|Linux/amd64) os=linux; arch=amd64;;
    Linux/aarch64|Linux/arm64) os=linux; arch=arm64;;
    *) fail '지원하지 않는 OS/CPU입니다. macOS Apple Silicon, Linux amd64/arm64만 지원합니다.';;
esac
case "${HOME:-}" in /*) ;; *) fail 'HOME은 절대경로여야 합니다.';; esac
home_dir=$(cd -- "$HOME" && pwd -P)
# Freeze the same home/root in every command and service invocation.
export HOME="$home_dir"
bin_dir=${bin_dir_override:-"$home_dir/.local/bin"}
case "$os" in
    darwin)
        root="$home_dir/Library/Application Support/onidot"
        config_dir=${ONI_CONFIG_DIR:-$root/config}; data_dir=${ONI_DATA_DIR:-$root/data}
        state_dir=${ONI_STATE_DIR:-$root/state}; runtime_dir=${ONI_RUNTIME_DIR:-$root/runtime}
        service_file="$home_dir/Library/LaunchAgents/com.onidot.studio.local.plist";;
    linux)
        config_dir=${ONI_CONFIG_DIR:-${XDG_CONFIG_HOME:-$home_dir/.config}/onidot}
        data_dir=${ONI_DATA_DIR:-${XDG_DATA_HOME:-$home_dir/.local/share}/onidot}
        state_dir=${ONI_STATE_DIR:-${XDG_STATE_HOME:-$home_dir/.local/state}/onidot}
        runtime_dir=${ONI_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-$state_dir}/onidot}
        if [ -z "${ONI_RUNTIME_DIR:-}" ] && [ -z "${XDG_RUNTIME_DIR:-}" ]; then runtime_dir="$state_dir/runtime"; fi
        service_file="${XDG_CONFIG_HOME:-$home_dir/.config}/systemd/user/onidot-studio.service";;
esac
for path in "$bin_dir" "$config_dir" "$data_dir" "$state_dir" "$runtime_dir" "$service_file"; do
    case "$path" in /*) ;; *) fail '설치·인스턴스 경로는 절대경로여야 합니다.';; esac
    case "$path" in *$'\n'*|*$'\r'*|*$'\t'*|*/../*|*/./*|*/..|*/.|/) fail '정규화된 경로를 사용하세요.';; esac
done
path_args=(--config-dir "$config_dir" --data-dir "$data_dir" --state-dir "$state_dir" --runtime-dir "$runtime_dir")
update_check_file="$state_dir/autostart-update-check"

# Do not follow a writable destination symlink, including parent components.
safe_dir() {
    local remaining=${1#/} current= part
    while [ -n "$remaining" ]; do
        part=${remaining%%/*}
        if [ "$remaining" = "$part" ]; then remaining=; else remaining=${remaining#*/}; fi
        [ -n "$part" ] || continue
        current="$current/$part"
        [ ! -L "$current" ] || fail '설치 경로에 심볼릭 링크가 있습니다.'
        if [ ! -d "$current" ]; then mkdir "$current" || fail '디렉터리를 만들 수 없습니다.'; fi
    done
}
check_pair() {
    local dir=$1 cli server
    for name in oni onidot-studio; do
        [ -f "$dir/$name" ] && [ ! -L "$dir/$name" ] && [ -x "$dir/$name" ] || fail '두 명령은 같은 디렉터리의 일반 실행 파일이어야 합니다.'
    done
    cli=$(ONIDOT_UPDATE_CHECK=off "$dir/oni" version) || fail 'oni 버전 확인에 실패했습니다.'
    server=$(ONIDOT_UPDATE_CHECK=off "$dir/onidot-studio" version) || fail '서버 버전 확인에 실패했습니다.'
    pair_version=${cli#oni }
    [ "$cli" = "oni $pair_version" ] && [ "$server" = "onidot-studio $pair_version" ] || fail '혼합 버전 설치를 거부합니다. 두 명령을 함께 복구하세요.'
    [[ "$pair_version" =~ ^0\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || fail '설치된 버전은 유효한 0.x 버전이어야 합니다.'
}
require_stopped() {
    local status
    status=$(ONIDOT_UPDATE_CHECK=off "$bin_dir/oni" "${path_args[@]}" daemon status) || fail '데몬 상태를 확인할 수 없습니다. oni doctor로 확인하세요.'
    [ "$status" = stopped ] || fail '실행 중이거나 상태를 확인할 수 없습니다. oni backup으로 백업한 뒤 oni daemon stop으로 정지하세요.'
}
service_absent() {
    [ ! -e "$service_file" ] && [ ! -L "$service_file" ] || fail '자동 시작 등록이 있습니다. --autostart disable로 해제한 뒤 다시 실행하세요.'
}

stage= backup= locked=0 transaction=0 restart_attempt=0 installed_oni=0 installed_server=0
cleanup() {
    local code=$? recovery_failed=0
    trap - EXIT HUP INT TERM
    if [ "$transaction" = 1 ]; then
        if [ "$restart_attempt" = 1 ] && ! "$bin_dir/oni" "${path_args[@]}" daemon stop >/dev/null 2>&1; then
            printf '%s\n' "재기동 후 정지 확인 실패: 현재 파일을 유지합니다. 이전 파일: $backup" >&2
            recovery_failed=1
        else
            [ "$installed_oni" = 0 ] || rm -f "$bin_dir/oni" || recovery_failed=1
            [ "$installed_server" = 0 ] || rm -f "$bin_dir/onidot-studio" || recovery_failed=1
            for name in oni onidot-studio; do
                if [ -n "$backup" ] && [ -f "$backup/$name" ]; then
                    mv -f "$backup/$name" "$bin_dir/$name" || recovery_failed=1
                fi
            done
        fi
        printf '%s\n' '전환 실패: 실행 파일 복구를 시도했습니다. 데이터를 자동으로 되돌리거나 구버전 서버를 시작하지 않습니다. DB 호환성을 확인하고 필요하면 검증된 백업을 별도 root에 복원하세요.' >&2
        [ "$recovery_failed" = 0 ] || printf '%s\n' "복구 확인이 필요합니다. 보존 경로: $backup" >&2
    fi
    [ -z "$stage" ] || rm -rf "$stage"
    [ "$locked" = 0 ] || rmdir "$bin_dir/.onidot-install.lock"
    exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

if [ "$action" = install ]; then
    version=${version#v}
    [[ "$version" =~ ^0\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || fail '명시적인 0.x 버전이 필요합니다. 1.0.0 이상은 설치하지 않습니다.'
    case "$base_url" in https://*|file:///*) ;; *) fail '공개 HTTPS 자산 URL(--base-url)이 필요합니다. 로컬 fixture는 file:/// 경로를 사용할 수 있습니다.';; esac
else
    [ -z "$version$base_url" ] && [ "$restart" = 0 ] && [ "$no_restart" = 0 ] || fail '설치 옵션과 관리 옵션은 함께 사용할 수 없습니다.'
fi
safe_dir "$bin_dir"
[ -w "$bin_dir" ] || fail '실행 파일 디렉터리에 쓰기 권한이 없습니다.'
mkdir "$bin_dir/.onidot-install.lock" 2>/dev/null || fail '다른 설치가 진행 중이거나 설치 잠금이 남았습니다. 실행 여부를 확인하세요.'
locked=1
old_version=
if [ -e "$bin_dir/oni" ] || [ -L "$bin_dir/oni" ] || [ -e "$bin_dir/onidot-studio" ] || [ -L "$bin_dir/onidot-studio" ]; then
    check_pair "$bin_dir"
    old_version=$pair_version
elif [ "$action" != install ]; then
    fail '먼저 두 명령을 설치하세요.'
fi

# Embedded copies of deploy/local templates keep the downloaded script standalone.
launchd_template() {
cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.onidot.studio.local</string>
<key>ProgramArguments</key><array>
<string>@SERVER@</string><string>local</string>
<string>--config-dir</string><string>@CONFIG@</string>
<string>--data-dir</string><string>@DATA@</string>
<string>--state-dir</string><string>@STATE@</string>
<string>--runtime-dir</string><string>@RUNTIME@</string>
<string>daemon</string><string>run</string>
</array>
<key>EnvironmentVariables</key><dict><key>HOME</key><string>@HOME@</string></dict>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>ThrottleInterval</key><integer>10</integer>
<key>ExitTimeOut</key><integer>40</integer>
<key>StandardOutPath</key><string>@STATE@/autostart.log</string>
<key>StandardErrorPath</key><string>@STATE@/autostart.log</string>
</dict></plist>
EOF
}
systemd_template() {
cat <<'EOF'
[Unit]
Description=onidot-studio local instance
[Service]
Type=simple
ExecStart="@SERVER@" local --config-dir "@CONFIG@" --data-dir "@DATA@" --state-dir "@STATE@" --runtime-dir "@RUNTIME@" daemon run
Environment="HOME=@HOME@"
Restart=on-failure
RestartSec=10
TimeoutStopSec=40
UMask=0077
[Install]
WantedBy=default.target
EOF
}
render_service() {
    local line value key
    while IFS= read -r line; do
        for key in SERVER CONFIG DATA STATE RUNTIME HOME; do
            case "$key" in SERVER) value="$bin_dir/onidot-studio";; CONFIG) value=$config_dir;; DATA) value=$data_dir;; STATE) value=$state_dir;; RUNTIME) value=$runtime_dir;; HOME) value=$home_dir;; esac
            if [ "$os" = darwin ]; then
                value=$(printf '%s' "$value" | sed 's/\&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&apos;/g')
            else
                value=$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g; s/%/%%/g; s/\$/$$/g')
            fi
            # sed replacement syntax differs from XML/systemd escaping.
            value=$(printf '%s' "$value" | sed 's/[\\&|]/\\&/g')
            line=$(printf '%s' "$line" | sed "s|@$key@|$value|g")
        done
        if [ "$os" = darwin ]; then
            line=${line//<key>HOME<\/key>/<key>ONIDOT_UPDATE_CHECK<\/key><string>$service_update_check<\/string><key>HOME<\/key>}
        fi
        printf '%s\n' "$line"
        if [ "$os" = linux ] && [[ "$line" == Environment=* ]]; then
            printf 'Environment="ONIDOT_UPDATE_CHECK=%s"\n' "$service_update_check"
        fi
    done
}
normalize_update_check() {
    local value
    value=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    case "$value" in
        off|false|0) service_update_check=off;;
        ''|on|true|1) service_update_check=on;;
        *) service_update_check=on; printf '%s\n' '자동 확인 설정(ONIDOT_UPDATE_CHECK)이 올바르지 않아 자동 확인을 켭니다. on/off, true/false 또는 1/0을 사용하세요.' >&2;;
    esac
}
read_update_check() {
    service_update_check=on
    if [ -e "$update_check_file" ] || [ -L "$update_check_file" ]; then
        [ -f "$update_check_file" ] && [ ! -L "$update_check_file" ] || fail '자동 확인 설정이 일반 파일이 아닙니다.'
        normalize_update_check "$(cat "$update_check_file")"
    fi
}
save_update_check() {
    safe_dir "$state_dir"
    [ ! -L "$update_check_file" ] || fail '자동 확인 설정에 심볼릭 링크가 있습니다.'
    printf '%s\n' "$service_update_check" > "$update_check_file"
    chmod 600 "$update_check_file"
}
case "$action" in
    enable)
        service_absent
        require_stopped
        [ -f "$config_dir/instance.json" ] && [ ! -L "$config_dir/instance.json" ] || fail 'oni init을 먼저 완료하세요.'
        safe_dir "$(dirname "$service_file")"
        safe_dir "$state_dir"
        read_update_check
        if [ "${ONIDOT_UPDATE_CHECK+x}" = x ]; then
            normalize_update_check "$ONIDOT_UPDATE_CHECK"
        fi
        stage=$(mktemp -d "$bin_dir/.onidot-stage.XXXXXX")
        if [ "$os" = darwin ]; then launchd_template | render_service > "$stage/service"; else systemd_template | render_service > "$stage/service"; fi
        cp "$stage/service" "$service_file"
        save_update_check
        if [ "$os" = darwin ]; then
            if [ "$no_start" = 0 ]; then
                launchctl bootstrap "gui/$(id -u)" "$service_file" || fail 'launchd 등록에 실패했습니다. 등록 파일을 보존했으므로 --autostart disable로 정리하세요.'
            fi
        else
            systemctl --user daemon-reload || fail 'systemd user 등록에 실패했습니다. --autostart disable로 정리하세요.'
            if [ "$no_start" = 1 ]; then
                systemctl --user enable onidot-studio.service || fail 'systemd user 등록에 실패했습니다. --autostart disable로 정리하세요.'
            else
                systemctl --user enable --now onidot-studio.service || fail 'systemd user 등록에 실패했습니다. --autostart disable로 정리하세요.'
            fi
        fi
        if [ "$no_start" = 1 ]; then
            printf '%s\n' '자동 시작을 등록했습니다. 정지 상태를 유지하며 다음 로그인 때 자동 시작합니다.'
        else
            printf '%s\n' '자동 시작을 등록했습니다. oni daemon status와 oni doctor로 기동 상태를 확인하세요.'
        fi
        exit 0;;
    disable)
        if [ -e "$service_file" ] || [ -L "$service_file" ]; then
            [ -f "$service_file" ] && [ ! -L "$service_file" ] || fail '등록 파일이 일반 파일이 아닙니다.'
            # Keep the service's setting before removing its definition for an update.
            read_update_check
            if [ "$os" = darwin ]; then
                if grep -q '<key>ONIDOT_UPDATE_CHECK</key><string>off</string>' "$service_file"; then service_update_check=off;
                elif grep -q '<key>ONIDOT_UPDATE_CHECK</key><string>on</string>' "$service_file"; then service_update_check=on; fi
            else
                if grep -q '^Environment="ONIDOT_UPDATE_CHECK=off"$' "$service_file"; then service_update_check=off;
                elif grep -q '^Environment="ONIDOT_UPDATE_CHECK=on"$' "$service_file"; then service_update_check=on; fi
            fi
            save_update_check
            if [ "$os" = darwin ]; then
                domain="gui/$(id -u)"
                if ! launchctl bootout "$domain" "$service_file"; then
                    # A failed bootstrap (or a manually unloaded job) leaves only the plist.
                    launchctl print "$domain" >/dev/null 2>&1 || fail 'launchd 상태 조회 실패: 등록 파일을 보존했습니다.'
                    if launchctl print "$domain/com.onidot.studio.local" >/dev/null 2>&1; then
                        fail 'launchd 해제 실패: 등록 파일을 보존했습니다.'
                    fi
                fi
            else
                systemctl --user disable --now onidot-studio.service || fail 'systemd user 해제 실패: 등록 파일을 보존했습니다.'
            fi
            rm "$service_file"
            if [ "$os" = linux ]; then systemctl --user daemon-reload; fi
        fi
        printf '%s\n' '자동 시작을 해제했습니다. 데이터는 보존했습니다.'
        exit 0;;
    uninstall)
        service_absent; require_stopped
        # Report a malformed value without making this unused setting a prerequisite.
        if [ -f "$update_check_file" ] && [ ! -L "$update_check_file" ]; then
            normalize_update_check "$(cat "$update_check_file")"
        fi
        rm "$bin_dir/oni" "$bin_dir/onidot-studio"
        printf '%s\n' '두 실행 파일을 제거했습니다. 데이터·설정·이전 실행 파일 백업은 보존했습니다.'
        exit 0;;
esac
service_absent
if [ -n "$old_version" ]; then
    require_stopped
    # A successful old binary launch cannot prove a newer database is safe to downgrade.
    awk -v old="$old_version" -v new="$version" 'BEGIN {
        split(old,o,/[.-]/); split(new,n,/[.-]/)
        if (n[2]+0 < o[2]+0 || (n[2]+0 == o[2]+0 && n[3]+0 < o[3]+0)) exit 1
        if (n[2]+0 == o[2]+0 && n[3]+0 == o[3]+0 && old !~ /-/ && new ~ /-/) exit 1
    }' || fail '버전 내림은 자동 수행하지 않습니다. 검증된 백업을 별도 root에 복원하는 절차를 사용하세요.'
    if [ "$old_version" != "$version" ] && [ "$restart" = 0 ] && [ "$no_restart" = 0 ]; then
        fail '업데이트 전 oni backup·oni daemon stop을 완료하고 --restart로 재기동 검증을 선택하세요.'
    fi
fi
stage=$(mktemp -d "$bin_dir/.onidot-stage.XXXXXX")
mkdir "$stage/new"
asset="onidot-studio_${version}_${os}_${arch}.tar.gz"
fetch() { curl --fail --silent --show-error --location --proto '=https,file' --proto-redir '=https' --connect-timeout 15 --max-time 180 "$1" -o "$2"; }
fetch "${base_url%/}/SHA256SUMS" "$stage/SHA256SUMS" || fail '체크섬 다운로드에 실패했습니다.'
fetch "${base_url%/}/$asset" "$stage/archive" || fail '배포 파일 다운로드에 실패했습니다.'
expected=$(awk -v file="$asset" '$2 == file {n++; value=$1} END {if(n!=1) exit 1; print value}' "$stage/SHA256SUMS") || fail '체크섬 항목이 없거나 중복입니다.'
[[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || fail 'SHA256SUMS 형식이 올바르지 않습니다.'
if command -v sha256sum >/dev/null 2>&1; then actual=$(sha256sum "$stage/archive"); else actual=$(shasum -a 256 "$stage/archive"); fi
[ "$(printf '%s' "$expected" | tr A-F a-f)" = "${actual%% *}" ] || fail 'SHA-256 불일치: 기존 설치를 보존했습니다.'
tar -tzf "$stage/archive" > "$stage/entries" || fail '압축 파일이 손상되었습니다.'
for name in oni onidot-studio; do
    [ "$(awk -v name="$name" '$0==name {n++} END {print n+0}' "$stage/entries")" = 1 ] || fail '배포 파일에 두 명령이 정확히 한 개씩 있어야 합니다.'
    # Stream only named regular files; never extract archive paths/links to disk.
    kind=$(tar -tvzf "$stage/archive" "$name") || fail '배포 파일 정보를 읽을 수 없습니다.'
    case "$kind" in -*) ;; *) fail '배포 명령은 일반 파일이어야 합니다.';; esac
    tar -xOzf "$stage/archive" "$name" > "$stage/new/$name" || fail '배포 파일을 읽을 수 없습니다.'
    chmod 755 "$stage/new/$name"
done
check_pair "$stage/new"
[ "$pair_version" = "$version" ] || fail '요청한 버전과 다운로드한 버전이 다릅니다.'
# Recheck after downloading, immediately before the two-file transition.
if [ -n "$old_version" ]; then require_stopped; fi
backup=$(mktemp -d "$bin_dir/.onidot-backup.XXXXXX")
printf '%s\n' "전환 복구 경로: $backup"
transaction=1
for name in oni onidot-studio; do
    if [ -n "$old_version" ]; then mv "$bin_dir/$name" "$backup/$name"; fi
done
mv "$stage/new/oni" "$bin_dir/oni"; installed_oni=1
mv "$stage/new/onidot-studio" "$bin_dir/onidot-studio"; installed_server=1
check_pair "$bin_dir"
[ "$pair_version" = "$version" ] || fail '설치 후 버전이 일치하지 않습니다.'
if [ "$restart" = 1 ]; then
    restart_attempt=1
    "$bin_dir/oni" "${path_args[@]}" daemon start || fail '재기동에 실패했습니다.'
    status=$("$bin_dir/oni" "${path_args[@]}" daemon status) || fail '재기동 상태 확인에 실패했습니다.'
    case "$status" in 'running pid='*) ;; *) fail '재기동 후 실행 상태가 아닙니다.';; esac
    "$bin_dir/oni" "${path_args[@]}" doctor >/dev/null || fail '재기동 후 doctor가 실패했습니다.'
fi
transaction=0
if [ -z "$old_version" ]; then rmdir "$backup"; backup=; fi
if [ "$managed_update" = 1 ] && [ -n "$backup" ]; then
    # Keep this pair until at least the next successful binary transition.
    # Only prune earlier backups created by this managed-update policy.
    printf '%s\n' 'managed-update-v1' > "$backup/.managed-update"
    for previous in "$bin_dir"/.onidot-backup.*; do
        [ "$previous" != "$backup" ] && [ -d "$previous" ] && [ ! -L "$previous" ] || continue
        [ -f "$previous/.managed-update" ] && [ ! -L "$previous/.managed-update" ] || continue
        [ "$(cat "$previous/.managed-update")" = managed-update-v1 ] || continue
        if ! rm -f "$previous/oni" "$previous/onidot-studio" "$previous/.managed-update" || ! rmdir "$previous"; then
            printf '%s\n' "이전 실행 파일 백업 정리를 완료하지 못했습니다: $previous" >&2
        fi
    done
    printf '%s\n' "이전 실행 파일 보존 경로: $backup" '데이터 마이그레이션 전이고 데몬이 정지된 경우에만 이 경로의 oni·onidot-studio 두 파일을 함께 설치 경로로 복구할 수 있습니다. 마이그레이션 후에는 업데이트 전 데이터 백업을 별도 root에 복원하세요.'
fi
printf '%s\n' "설치 완료: $version (${os}_${arch})" "설치 경로: $bin_dir"
if [ "$managed_update" = 0 ]; then
    printf 'PATH에 추가하세요: export PATH=%q:"$PATH"\n' "$bin_dir"
    printf '%s\n' '최초 사용: oni init → oni daemon start → oni open → oni doctor' '자동 시작은 init 후 bash install.sh --autostart enable로 선택하세요.'
fi
