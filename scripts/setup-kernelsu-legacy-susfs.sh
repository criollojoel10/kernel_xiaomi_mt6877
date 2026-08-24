#!/bin/sh
# Setup KernelSU-Next @ DXRN-MoonWake branch legacy-susfs for Aeron v15 susfs tree
set -eu

GKI_ROOT=$(pwd)
REPO_URL="https://github.com/DXRN-MoonWake/KernelSU-Next"
BRANCH="legacy-susfs"

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

echo "[+] Setting up KernelSU-Next ($BRANCH)..."
test -d "$GKI_ROOT/KernelSU-Next" || git clone --branch "$BRANCH" "$REPO_URL" KernelSU-Next

cd "$GKI_ROOT/KernelSU-Next"
git checkout "$BRANCH"
git pull

cd "$DRIVER_DIR"
ln -sf "$(realpath --relative-to=$DRIVER_DIR $GKI_ROOT/KernelSU-Next/kernel)" kernelsu
echo "[+] Symlink created."

grep -q "kernelsu" $DRIVER_MAKEFILE || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> $DRIVER_MAKEFILE
grep -q 'source "drivers/kernelsu/Kconfig"' $DRIVER_KCONFIG || printf 'source "drivers/kernelsu/Kconfig"\n' >> $DRIVER_KCONFIG
echo '[+] Done.'
