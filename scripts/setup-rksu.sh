#!/bin/sh
# Setup KernelSU-Next driver from Constantq/xiaomi_fog_caf-kernel_ksun_susfs
# (proven on msm-4.19 non-GKI: full pre-5.x compat layer built-in).
# Paired with our in-tree susfs v2.0.0 all_procs variant (proven on ruby).
# Driver adaptations below bridge the small API delta of the older susfs.
set -eu

GKI_ROOT=$(pwd)
REPO_URL="https://github.com/Constantq/xiaomi_fog_caf-kernel_ksun_susfs"
PIN_SHA="dcd534ae759a3333b55febbd53347de1174963bb"

if test -d "$GKI_ROOT/common/drivers"; then
     DRIVER_DIR="$GKI_ROOT/common/drivers"
elif test -d "$GKI_ROOT/drivers"; then
     DRIVER_DIR="$GKI_ROOT/drivers"
else
     echo '[ERROR] "drivers/" directory not found.'
     exit 127
fi

DRIVER_MAKEFILE=$DRIVER_DIR/Makefile
DRIVER_KCONFIG=$DRIVER_DIR/Kconfig

echo "[+] Setting up KernelSU-Next ($PIN_SHA)..."
if ! test -d "$GKI_ROOT/KernelSU-Next-src"; then
    git clone --depth 1 --filter=blob:none --sparse "$REPO_URL" KernelSU-Next-src
fi
cd "$GKI_ROOT/KernelSU-Next-src"
CUR=$(git rev-parse HEAD)
if [ "$CUR" != "$PIN_SHA" ]; then
    echo "[!] main moved ($CUR), fetching pinned $PIN_SHA"
    git fetch --depth 1 --filter=blob:none origin "$PIN_SHA"
    git checkout --detach "$PIN_SHA"
fi
git sparse-checkout set KernelSU-Next
test -f KernelSU-Next/kernel/Kbuild || { echo '[ERROR] KernelSU-Next/kernel missing'; exit 127; }

K=KernelSU-Next/kernel

# --- ruby adaptations: older in-tree susfs v2.0.0 (all_procs variant) ---
# 1) all-procs naming (CMD number 0x55561 identical on both sides).
sed -i 's/susfs_set_hide_sus_mnts_for_non_su_procs/susfs_set_hide_sus_mnts_for_all_procs/g' $K/supercalls.c
sed -i 's/CMD_SUSFS_HIDE_SUS_MNTS_FOR_NON_SU_PROCS/CMD_SUSFS_HIDE_SUS_MNTS_FOR_ALL_PROCS/g' $K/supercalls.c
echo "[+] Patched supercalls.c: non_su_procs -> all_procs (fn + CMD)"
# 2) sdcard monitor kthread only exists in newer upstream susfs; drop the call.
sed -i '/susfs_start_sdcard_monitor_fn();/d' $K/supercalls.c
echo "[+] Patched supercalls.c: removed sdcard monitor call"
# 3) per-proc umounted tracking already exists in our susfs_def.h (TIF_PROC_UMOUNTED).
echo "[+] susfs_def.h provides proc-umounted helpers; no stub needed"

# 6) pkg_observer.c: fsnotify 4.19 usa handle_event, no handle_inode_event.
if grep -q "handle_inode_event" kernel/pkg_observer.c 2>/dev/null; then
    echo "[+] AVISO: pkg_observer.c requiere porte fsnotify manual para 4.19"
fi

# 7) Manager detection fix (SukiSU-Ultra issue #799 / ref OnePlus 6):
#    O_CLOEXEC en ksu_install_fd() rompe el handshake del manager
#    (kernel bootea y corona al manager, pero este no lo detecta).
if grep -q "get_unused_fd_flags(O_CLOEXEC)" kernel/supercalls.c 2>/dev/null; then
    sed -i 's/fd = get_unused_fd_flags(O_CLOEXEC);/fd = get_unused_fd_flags(0);/' kernel/supercalls.c
    sed -i 's/O_RDWR | O_CLOEXEC);/O_RDWR);/' kernel/supercalls.c
    echo "[+] Patched kernel/supercalls.c: O_CLOEXEC removed (manager detect fix)"
fi

cd "$DRIVER_DIR"
ln -sf "$(realpath --relative-to=$DRIVER_DIR $GKI_ROOT/KernelSU-Next-src/KernelSU-Next/kernel)" kernelsu
echo "[+] Symlink created."
grep -q "kernelsu" $DRIVER_MAKEFILE || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> $DRIVER_MAKEFILE
grep -q 'source "drivers/kernelsu/Kconfig"' $DRIVER_KCONFIG || printf 'source "drivers/kernelsu/Kconfig"\n' >> $DRIVER_KCONFIG
echo '[+] Done.'
