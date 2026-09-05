#!/system/bin/sh
# crypto_diag.sh - capture TWRP boot diag to EXTERNAL SD (/external_sd)
# Written to /tmp (ramfs) first, then copied to the vfat once it is mounted.

R=/dev/block/mmcblk1p1
T=/tmp/diag
mkdir -p $T

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