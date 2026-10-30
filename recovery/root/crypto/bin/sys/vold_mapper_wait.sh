#!/system/bin/sh
# Poll for the TWRP-created super logical partition node, then release
# vold-unisoc via sys.crypto.mapper.ready=1. Non-blocking to init (#253:
# the previous `wait` stalled late-init 30s -> stuck at logo, and timed out
# 77ms BEFORE TWRP mapped system_b anyway).
i=0
while [ ! -e /dev/block/mapper/system_b ]; do
    i=$((i + 1))
    # 300 * 0.2s = 60s hard cap, then release anyway (vold will report cleanly)
    if [ "$i" -ge 300 ]; then
        break
    fi
    sleep 0.2
done
# #266: cold-boot race - keymint SIGABRTs if /dev/trusty-ipc-dev0 isn't
# ready yet (crypto stack crash cascade on first boot). Bounded wait; then
# release regardless so we never block init (oneshot, parallel).
i=0
while [ ! -e /dev/trusty-ipc-dev0 ]; do
    i=$((i + 1))
    if [ "$i" -ge 50 ]; then
        break
    fi
    sleep 0.2
done
# small settle for ueventd to finish labeling the node
sleep 0.5
setprop sys.crypto.mapper.ready 1
exit 0