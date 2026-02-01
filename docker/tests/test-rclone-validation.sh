#!/bin/sh
# ╔═══════════════════════════════════════════════════════════╗
# ║       Rclone Mount Options Validation Test Suite         ║
# ╚═══════════════════════════════════════════════════════════╝
# Tests for command injection prevention in rclone mount options

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

# Test function
test_mount_options() {
    local test_name="$1"
    local mount_opts="$2"
    local expected_result="$3"  # "valid" or "invalid"

    # Simulate the validation logic from entrypoint.sh
    VALIDATED_OPTS=""
    is_valid="true"

    if [ -n "$mount_opts" ]; then
        for opt in $mount_opts; do
            # Check for path traversal
            if echo "$opt" | grep -qE '\.\./|^\.\.|/\.\.|\./$'; then
                is_valid="false"
                break
            fi
            if ! echo "$opt" | grep -qE '^--[a-z][a-z0-9-]+(=[a-zA-Z0-9._/:-]+)?$'; then
                is_valid="false"
                break
            fi

            flag_name="${opt%%=*}"
            case "$flag_name" in
                --vfs-cache-mode|--vfs-cache-max-age|--vfs-cache-max-size|\
                --vfs-read-chunk-size|--vfs-read-chunk-size-limit|\
                --buffer-size|--dir-cache-time|--poll-interval|\
                --read-only|--allow-non-empty|--default-permissions|\
                --log-level|--cache-dir|--attr-timeout|--timeout)
                    VALIDATED_OPTS="${VALIDATED_OPTS} ${opt}"
                    ;;
                *)
                    is_valid="false"
                    break
                    ;;
            esac
        done
    fi

    # Check result
    if [ "$is_valid" = "$expected_result" ]; then
        printf "${GREEN}✓ PASS${NC}: %s\n" "$test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}✗ FAIL${NC}: %s (expected %s, got %s)\n" "$test_name" "$expected_result" "$is_valid"
        printf "  Input: %s\n" "$mount_opts"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║      Rclone Mount Options Security Tests                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Valid mount options
echo "Testing VALID mount options:"
test_mount_options "VFS cache mode" "--vfs-cache-mode=writes" "true"
test_mount_options "VFS cache settings" "--vfs-cache-mode=full --vfs-cache-max-age=1h" "true"
test_mount_options "Read only flag" "--read-only" "true"
test_mount_options "Buffer size" "--buffer-size=128M" "true"
test_mount_options "Dir cache time" "--dir-cache-time=5m" "true"
test_mount_options "Multiple safe flags" "--vfs-cache-mode=writes --buffer-size=64M" "true"
test_mount_options "Timeout setting" "--timeout=30s" "true"
echo ""

# Invalid/malicious mount options
echo "Testing INVALID/MALICIOUS mount options:"
test_mount_options "Command injection semicolon" "--vfs-cache-mode=writes; rm -rf /" "false"
test_mount_options "Command injection backtick" "--vfs-cache-mode=\`whoami\`" "false"
test_mount_options "Command injection dollar" "--vfs-cache-mode=\$(whoami)" "false"
test_mount_options "Pipe injection" "--vfs-cache-mode=writes|sh" "false"
test_mount_options "Ampersand background" "--vfs-cache-mode=writes&" "false"
test_mount_options "Unknown flag" "--dangerous-flag=value" "false"
test_mount_options "No double dash" "-vfs-cache-mode=writes" "false"
test_mount_options "Special characters" "--vfs-cache-mode=writes@#" "false"
test_mount_options "Newline injection" "--vfs-cache-mode=writes
rm -rf /" "false"
test_mount_options "Quote escape attempt" "--vfs-cache-mode='\$(whoami)'" "false"
test_mount_options "Path traversal in value" "--cache-dir=../../etc" "false"
test_mount_options "Null byte injection" "--vfs-cache-mode=writes\x00" "false"
echo ""

# Summary
echo "════════════════════════════════════════════════════════════"
printf "Results: ${GREEN}%d PASSED${NC}, ${RED}%d FAILED${NC}\n" "$PASS_COUNT" "$FAIL_COUNT"
echo "════════════════════════════════════════════════════════════"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi

echo ""
echo "✅ All rclone mount options security tests passed!"
exit 0
