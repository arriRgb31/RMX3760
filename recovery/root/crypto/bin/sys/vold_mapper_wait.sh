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
setprop sys.crypto.mapper.ready 1
exit 0