#!/system/bin/sh
# A15 vdc mountFstab wrapper.
# #261/262 BUG: init rc-parser does NOT honor quoting, so the inline
# `sh -c 'sleep 3; exec vdc ...'` was split into `sh -c sleep 3;...` =>
# `sleep` ran without args => exit 1 in 13ms, long before vold-unisoc had
# even "firing up". A file script avoids quoting entirely (same pattern as
# vold_mapper_wait.sh, which works).
# Retry loop: vdc returns non-zero if vold's binder service is not yet
# up; poll until it is (vold-unisoc start is async vs this trigger).
# Args mirror A15 VoldNativeService::mountFstab(blkDevice, mountPoint,
# isZoned=false, userDevices="") with the trailing empty arg.
# #274: restore the pre-vold RAM snapshot of the /metadata encryption key dir
# right after the mount attempt, on EVERY exit path. TWRP's A15 vold re-wraps
# keymaster_key_blob ("Upgrading key", recovery keymint <> stock keymint),
# which leaves a blob the next SYSTEM boot cannot read ("Rescue Party").
# Snapshot was taken by key_snapshot.sh BEFORE vold; restoring it here makes
# the session leave the on-disk keys byte-identical regardless of vold.
restore_keys() {
    [ -d /crypto/keyguard ] || return 0
    [ -d /metadata/vold/metadata_encryption/key ] || return 0
    cp -a /crypto/keyguard/. /metadata/vold/metadata_encryption/key/ && sync
}
i=0
while [ "$i" -lt 120 ]; do
    /crypto/bin/sys/vdc cryptfs mountFstab /dev/block/by-name/userdata /data false ""
    rc=$?
    # restore the snapshot after EVERY attempt: vold's first mountFstab of the
    # session does "Upgrading key" (writes a recovery-only blob). If the user
    # reboots mid-loop this keeps disk keys valid. Re-running later attempts is
    # harmless (they re-upgrade then we re-restore; /data DM uses the same DEK).
    restore_keys
    [ "$rc" -eq 0 ] && exit 0
    i=$((i + 1))
    sleep 1
done
exit 1