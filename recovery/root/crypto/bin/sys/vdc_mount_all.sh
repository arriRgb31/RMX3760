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
i=0
while [ "$i" -lt 120 ]; do
    /crypto/bin/sys/vdc cryptfs mountFstab /dev/block/by-name/userdata /data false ""
    rc=$?
    [ "$rc" -eq 0 ] && exit 0
    i=$((i + 1))
    sleep 1
done
exit 1