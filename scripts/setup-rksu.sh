#!/bin/sh
# Setup RKSU (rsuntk/KernelSU) pinned to a Feb-2026 commit (constantq-era,
# with kprobe hook for non-GKI 4.19) + externally provided susfs 1.5.x (already
# in tree from ksu_susfs-v15). SUS_MOUNT enabled via ruby_defconfig.
set -eu

GKI_ROOT=$(pwd)
REPO_URL="https://github.com/rsuntk/KernelSU"
BRANCH="main"
COMMIT="9f68f239f62c242964311aeec3080ced9cda4d29"

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

echo "[+] Setting up RKSU ($COMMIT)..."
test -d "$GKI_ROOT/KernelSU" || git clone --branch "$BRANCH" "$REPO_URL" KernelSU
cd "$GKI_ROOT/KernelSU"
git fetch origin "$COMMIT"
git checkout "$COMMIT"

# --- 4.19 non-GKI porting fixes (RKSU targets 5.x+/6.x) ---
# 1) MODULE_IMPORT_NS() does not exist before 5.x; drop it from ksu.c tail.
if grep -q "MODULE_IMPORT_NS" kernel/ksu.c 2>/dev/null; then
    sed -i '/MODULE_IMPORT_NS/d' kernel/ksu.c
    echo "[+] Patched kernel/ksu.c: removed MODULE_IMPORT_NS (4.19)"
fi
# 2) task_work_add() 3rd arg is 'bool' on 4.19 (not TWA_*); fix callers.
if grep -rq "TWA_RESUME" kernel/ 2>/dev/null; then
    grep -rl "TWA_RESUME" kernel/ 2>/dev/null | xargs -r sed -i 's/TWA_RESUME/true/g'
    echo "[+] Patched kernel/*: TWA_RESUME -> true (4.19 task_work_add bool)"
fi
# 3) put_task_struct needs <linux/sched/task.h>
if grep -q "put_task_struct" kernel/allowlist.c 2>/dev/null; then
    sed -i 's|#include <linux/version.h>|#include <linux/version.h>\n#include <linux/sched/task.h>|' kernel/allowlist.c
    echo "[+] Patched kernel/allowlist.c: added sched/task.h"
fi

cd "$DRIVER_DIR"
ln -sf "$(realpath --relative-to=$DRIVER_DIR $GKI_ROOT/KernelSU/kernel)" kernelsu
echo "[+] Symlink created."
grep -q "kernelsu" $DRIVER_MAKEFILE || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> $DRIVER_MAKEFILE
grep -q 'source "drivers/kernelsu/Kconfig"' $DRIVER_KCONFIG || printf 'source "drivers/kernelsu/Kconfig"\n' >> $DRIVER_KCONFIG
echo '[+] Done.'
