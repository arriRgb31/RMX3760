#!/system/bin/sh
# crypto_diag.sh - capture TWRP boot diag to EXTERNAL SD (/external_sd)
# Written to /tmp (ramfs) first, then copied to the vfat once it is mounted.

R=/dev/block/mmcblk1p1
T=/tmp/diag
mkdir -p $T

# ---- ftrace: trace every signal_generate (who killed whom) ASAP, BEFORE the
# first crash (~100ms after boot). The triple SIGSEGV leaves NO "segfault at"
# in dmesg and no "Fatal signal 11" from libc -> we need the kernel's own view
# of signal delivery (sender PID -> target PID -> signal number).
mount -t tracefs tracefs /sys/kernel/debug/tracing 2>/dev/null ||
  mount -t tracefs tracefs /sys/kernel/tracing 2>/dev/null
if [ -d /sys/kernel/debug/tracing ] || [ -d /sys/kernel/tracing ]; then
  TR=/sys/kernel/debug/tracing
  [ -d /sys/kernel/tracing ] && TR=/sys/kernel/tracing
  echo 0 > $TR/tracing_on
  echo > $TR/trace
  echo signal_generate > $TR/set_event
  echo 1 > $TR/tracing_on
else
  echo "no tracefs" > $T/no_tracefs.txt
fi

# ---- snapshot 0: immediate (services crash within the first ~100ms of boot)
{
  echo "=== snapshot0 $(date) ==="
  echo "--- getprop ---"
  getprop
  echo "--- /proc/mounts ---"
  cat /proc/mounts
  echo "--- ps ---"
  ps
} > $T/s0.txt 2>&1
dmesg > $T/dmesg0.log 2>&1
logcat -d > $T/logcat0.log 2>&1
cp /tmp/sigcatch.log $T/ 2>/dev/null
cp /tmp/maps.log $T/ 2>/dev/null

# copy whatever exists to the FAT as soon as it appears
sync

# ---- snapshot 1: after TWRP super/metadata mounts (~30s)
sleep 30
{
  echo "=== snapshot1 $(date) ==="
  echo "--- getprop ---"
  getprop
  echo "--- /proc/mounts ---"
  cat /proc/mounts
  echo "--- ps ---"
  ps
} > $T/s1.txt 2>&1
dmesg > $T/dmesg1.log 2>&1
logcat -d > $T/logcat1.log 2>&1
cp /tmp/sigcatch.log $T/ 2>/dev/null
cp /tmp/maps.log $T/ 2>/dev/null
sync

# ---- snapshot 2: settled state (~60s)
sleep 30
{
  echo "=== snapshot2 $(date) ==="
  echo "--- getprop ---"
  getprop
  echo "--- /proc/mounts ---"
  cat /proc/mounts
  echo "--- ps ---"
  ps
} > $T/s2.txt 2>&1
dmesg > $T/dmesg2.log 2>&1
logcat -d > $T/logcat2.log 2>&1
cp /tmp/sigcatch.log $T/ 2>/dev/null
cp /tmp/maps.log $T/ 2>/dev/null
# dump whatever ftrace captured (all signal_generate + segfault events)
for P in /sys/kernel/debug/tracing /sys/kernel/tracing; do
  if [ -r $P/trace ]; then
    cat $P/trace > $T/ftrace.log 2>/dev/null
    break
  fi
done
sync

# ---- final: copy everything to external SD (try multiple mount points)
for M in /external_sd /storage/sdcard0 /mnt/sdcard /sdcard; do
  mkdir -p $M 2>/dev/null
done
if ! grep -q vfat /proc/mounts; then
  mount -t vfat -o rw $R /external_sd 2>/dev/null
fi
if grep -q " /external_sd " /proc/mounts; then
  mkdir -p /external_sd/crypto_diag
  cp -rf $T/. /external_sd/crypto_diag/ 2>/dev/null
fi
if grep -q " /storage/sdcard0 " /proc/mounts; then
  mkdir -p /storage/sdcard0/crypto_diag
  cp -rf $T/. /storage/sdcard0/crypto_diag/ 2>/dev/null
fi
sync
exit 0