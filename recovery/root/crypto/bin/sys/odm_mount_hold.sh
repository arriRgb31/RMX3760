#!/system/bin/sh
# WATCHDOG: keep the real erofs /odm mounted for the whole session.
# Sesi #261-262: TWRP mounts /odm right after boot, then "Unmounting main
# partitions..." drops it again (only /vendor stayed, because it was busy).
# With /odm gone, servicemanager resolves the ramdisk symlink /odm/etc ->
# /vendor/odm/etc onto the LIVE vendor mount (whose own odm -> /vendor/odm)
# => ELOOP => NULL VINTF MANIFEST => keymint/keystore2 crash loops (#262).
# Why the original one-shot mount+cwd wasn't enough (#264):
#   * a plain `cd /odm` NEVER fails even when /odm is not mounted (the
#     ramdisk directory always exists), so a failed mount silently parked the
#     cwd on nothing and TWRP unmounted the erofs cleanly (no EBUSY);
#   * the odm logical partition (dm-*) can be dropped/re-created by TWRP's
#     partition management, making a single boot-time mountpoint stale.
# This loop re-checks /proc/mounts every 2s and remounts + cds into /odm when
# it is gone, converging within one cycle no matter who unmounted it.
# Non-blocking (#253), never oneshot.

odm_mount() {
    grep -q ' /odm ' /proc/mounts 2>/dev/null && return 0
    (mount -t erofs -o ro /dev/block/by-name/odm /odm \
        || mount -t erofs -o ro /dev/block/mapper/odm_b /odm \
        || mount -t erofs -o ro /dev/block/dm-4 /odm) 2>/dev/null
    return $?
}

# Wait for any /odm device node to appear (TWRP maps logical partitions after
# late-init begins; poll here instead of blocking init's action queue).
i=0
while [ ! -e /dev/block/by-name/odm ] && [ ! -e /dev/block/dm-4 ]; do
    i=$((i + 1))
    # 300 * 0.2s = 60s hard cap, then run the watchdog anyway (it keeps retrying).
    [ "$i" -ge 300 ] && break
    sleep 0.2
done

while :; do
    if ! grep -q ' /odm ' /proc/mounts; then
        odm_mount && cd /odm 2>/dev/null
    fi
    sleep 2
done