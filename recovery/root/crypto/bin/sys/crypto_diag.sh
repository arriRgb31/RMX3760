#!/system/bin/sh
# crypto_diag.sh - capture TWRP boot diag to EXTERNAL SD (/external_sd)
# Each snapshot is flushed to the vfat immediately (user may pull logs early).

R=/dev/block/mmcblk1p1
T=/tmp/diag
mkdir -p $T

# ---- ftrace: trace signal_generate (sender PID -> target PID) ASAP, before
# the first crash. NO "segfault at" and NO "Fatal signal 11" in #253 dmesg,
# so the triple SIGSEGV is likely INJECTED via kill() - kernel's own signal
# view will name the sender.
mount -t tracefs tracefs /sys/kernel/debug/tracing 2>/dev/null ||
  mount -t tracefs tracefs /sys/kernel/tracing 2>/dev/null
TR=
for P in /sys/kernel/debug/tracing /sys/kernel/tracing; do
  [ -d $P ] && TR=$P
done
if [ -n "$TR" ]; then
  echo 0 > $TR/tracing_on
  echo > $TR/trace
  echo signal_generate > $TR/set_event
  echo 1 > $TR/tracing_on
else
  echo "no tracefs" > $T/no_tracefs.txt
fi

snapshot() {
  local N=$1
  {
    echo "=== snapshot$N $(date) ==="
    echo "--- getprop ---"
    getprop
    echo "--- /proc/mounts ---"
    cat /proc/mounts
    echo "--- ps ---"
    ps
  } > $T/s$N.txt 2>&1
  dmesg > $T/dmesg$N.log 2>&1
  logcat -d > $T/logcat$N.log 2>&1
  cp /tmp/sigcatch.log $T/ 2>/dev/null
  cp /tmp/maps.log $T/ 2>/dev/null
  if [ -n "$TR" ] && [ -r $TR/trace ]; then
    cat $TR/trace > $T/ftrace$N.log 2>/dev/null
  fi
  # flush to FAT immediately
  if ! grep -q " /external_sd " /proc/mounts; then
    mkdir -p /external_sd 2>/dev/null
    mount -t vfat -o rw $R /external_sd 2>/dev/null
  fi
  if grep -q " /external_sd " /proc/mounts; then
    mkdir -p /external_sd/crypto_diag
    cp -rf $T/. /external_sd/crypto_diag/ 2>/dev/null
    sync
  fi
}

# snapshot 0: immediate (services crash within the first ~100ms of boot)
snapshot 0

# snapshot 1: after TWRP super/metadata mounts (~20s)
sleep 20
snapshot 1

# snapshot 2: settled state (~40s)
sleep 20
snapshot 2

# snapshot 3: confirm the crash loop is steady (~60s)
sleep 20
snapshot 3
sync
exit 0