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
# #276 (generic anti-cascade, public repo - no hardcoded per-device hashes):
#   * restore_keys() NEVER clobbers the good disk keys with an empty/incomplet
#     snapshot (4 files must be non-empty in /crypto/keyguard), and only copies
#     when the on-disk files actually differ (cmp), so restores are safe no
#     matter what key state exists on the device (stock / factory new / other).
#   * final_restore() adds a delayed 3-pass restore after the loop (and on the
#     success path) because keystore2/keymint finish "Upgrading key" a beat
#     AFTER mountFstab returns - an async write landing after our last restore
#     was the root cause of the #274 cascade.
restore_keys() {
    [ -d /crypto/keyguard ] || return 0
    [ -d /metadata/vold/metadata_encryption/key ] || return 0
    for f in encrypted_key keymaster_key_blob secdiscardable version; do
        [ -s "/crypto/keyguard/$f" ] || return 0
    done
    changed=0
    for f in encrypted_key keymaster_key_blob secdiscardable version; do
        if [ ! -s "/metadata/vold/metadata_encryption/key/$f" ] ||
           ! cmp -s "/crypto/keyguard/$f" "/metadata/vold/metadata_encryption/key/$f"; then
            changed=1
            break
        fi
    done
    [ "$changed" -eq 0 ] && return 0
    cp -a /crypto/keyguard/. /metadata/vold/metadata_encryption/key/ && sync
}
final_restore() {
    restore_keys
    sleep 2
    restore_keys
    sleep 2
    restore_keys
    sync
}
# #279: pin dm-default-key options_format=2 right before vold computes the
# table (covers any path where the rc-only setprop was missed; ro.* set-once
# semantics make this safe - the first set wins, value is always 2).
setprop ro.crypto.dm_default_key.options_format.version 2
i=0
while [ "$i" -lt 120 ]; do
    /crypto/bin/sys/vdc cryptfs mountFstab /dev/block/by-name/userdata /data false ""
    rc=$?
    # restore the snapshot after EVERY attempt: vold's first mountFstab of the
    # session does "Upgrading key" (writes a recovery-only blob). If the user
    # reboots mid-loop this keeps disk keys valid. Re-running later attempts is
    # harmless (they re-upgrade then we re-restore; /data DM uses the same DEK).
    restore_keys
    [ "$rc" -eq 0 ] && { final_restore; exit 0; }
    i=$((i + 1))
    sleep 1
done
# exhausted retries: still run the delayed passes so an in-flight async
# "Upgrading key" write cannot be left on disk before we reboot to system.
final_restore
exit 1