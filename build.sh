#!/bin/bash

# Ensure the script exits on error
set -e

SECONDS=0 # builtin bash timer

# Device configuration
DEVICE="sweet"
KERNEL_NAME="Oxygen"

TOOLCHAIN_PATH=$HOME/tc/bin
GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)

if [ ! -d $TOOLCHAIN_PATH ]; then
    echo "TOOLCHAIN_PATH [$TOOLCHAIN_PATH] does not exist."
    echo "Please ensure the toolchain is there, or change TOOLCHAIN_PATH in the script to your toolchain path."
    exit 1
fi

echo "TOOLCHAIN_PATH: [$TOOLCHAIN_PATH]"
export PATH="$TOOLCHAIN_PATH:$PATH"

MAKE_ARGS="ARCH=arm64 O=out CC=clang LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip"

# Check clang is existing.
echo "[clang --version]:"
clang --version

# Export variables
export KBUILD_BUILD_USER="aryan"
export KBUILD_BUILD_HOST="curiousnom"
export KBUILD_LAST_COMMIT=${GIT_COMMIT_ID}

# Clean option
if [[ $1 = "-c" || $1 = "--clean" ]]; then
    echo "Cleaning..."
    rm -rf out/
    rm -rf error.log
    echo "Cleaned output folder"
fi

echo "Cleaning old builds..."
rm -rf error.log

echo "Cloning AnyKernel3 for packing kernel..."
if [ -d "AnyKernel3/.git" ]; then
    echo "AnyKernel3 already cloned. Skipping."
else
    rm -rf AnyKernel3  # ensure clean state
    if ! git clone -q --depth 1 https://github.com/CuriousNom/AnyKernel3.git -b sweet AnyKernel3; then
        echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
        exit 1
    fi
fi

# ------------- Building for SWEET ---------------
echo -e "\nStarting compilation for sweet...\n"

make $MAKE_ARGS sweet_defconfig

make $MAKE_ARGS -j$(nproc --all) 2> >(tee -a error.log >&2)

kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"
dtb="out/arch/arm64/boot/dtb.img"

if [ ! -f "$kernel" ]; then
    echo -e "\nThe file [$kernel] does not exist. Build failed."
    exit 1
fi

echo -e "\nKernel compiled successfully! Zipping up...\n"

# Modify anykernel.sh to replace device names
sed -i "s/device\.name1=.*/device.name1=sweet/" AnyKernel3/anykernel.sh
sed -i "s/device\.name2=.*/device.name2=sweetin/" AnyKernel3/anykernel.sh

rm -rf AnyKernel3/kernels/
mkdir -p AnyKernel3/kernels/
cp $kernel AnyKernel3/kernels/

# Copy dtbo and dtb if they exist
if [ -f "$dtbo" ]; then
    cp $dtbo AnyKernel3/kernels/
fi

if [ -f "$dtb" ]; then
    cp $dtb AnyKernel3/kernels/
fi

cd AnyKernel3
ZIP_FILENAME="Kernel_Oxygen_sweet_anykernel3_${GIT_COMMIT_ID}.zip"
zip -r9 $ZIP_FILENAME ./* -x .git .gitignore out/ ./*.zip
mv $ZIP_FILENAME ../
cd ..

echo -e "\nBuild for sweet finished."
echo -e "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIP_FILENAME"
