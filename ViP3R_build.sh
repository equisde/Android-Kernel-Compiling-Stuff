#! /bin/bash

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2020 Panchajanya1999 <rsk52959@gmail.com>
 # Copyright (c) 2019-2020 iamsaalim <saalimquadri1@gmail.com>
 # Copyright (c) 2021 Amol Amrit <amol.amrit03@outlook.com>
 #
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

#Kernel building script

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
    exit 1
}

sendInfo() {
  "${TELEGRAM}" -c "${CHANNEL_ID}" -H \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}
$LINKER=ld.lld

# Constants
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
cyan='\033[0;36m'
yellow='\033[0;33m'
blue='\033[0;34m'
default='\033[0m'
DATE=$(date +"%Y%m%d-%H%M")
TELEGRAM=Telegram/telegram
CHANNEL_ID=-xx

##--------------------------------------------------------##
##----------Basic Informations and Variables--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR=$PWD

# Kernel Version
VERSION="1.0"

# The name of the device for which the kernel is built
#MODEL="OnePlus Nord"

# The codename of the device
DEVICE="sweet"

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=sweet_nethunter_defconfig

# Specify compiler.
# 'clang' or 'gcc'
COMPILER=clang

# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=0

# Generate a full DEFCONFIG prior building. 1 is YES | 0 is NO(default)
DEF_REG=0

# Build dtbo.img (select this only if your source has support to building dtbo.img)
# 1 is YES | 0 is NO(default)
BUILD_DTBO=1

# Silence the compilation
# 1 is YES(default) | 0 is NO
SILENCE=0

# The name of the Kernel, to name the ZIP
ZIPNAME="ViP3R-BY-PARALLAX-$VERSION"

# Set Date and Time Zone
DATE=$(TZ=Asia/Kolkata date +"%Y%m%d-%T")


##----------------------------------------------------------------------------------##
##----------Now Its time for other stuffs like cloning, exporting, etc--------------##

 clone() {
	echo " "
	if [ $COMPILER = "clang" ]
	then
		msg "|| Cloning Clang ||"
		git clone --depth=1 https://github.com/sohamxda7/llvm-stable.git -b aosp-13.0.3 /root/Android/Kernels/ToolChains/clang-llvm
        git clone https://github.com/sohamxda7/llvm-stable -b gcc64 --depth=1 /root/Android/Kernels/ToolChains/gcc
        git clone https://github.com/sohamxda7/llvm-stable -b gcc32  --depth=1 /root/Android/Kernels/ToolChains/gcc32

		# Toolchain Directory defaults to clang-llvm
		TC_DIR=/root/Android/Kernels/ToolChains/clang-llvm
		GC_DIR=/root/Android/Kernels/ToolChains/gcc
		GC2_DIR=/root/Android/Kernels/ToolChains/gcc32
	elif [ $COMPILER = "gcc" ]
	then
		msg "|| Cloning GCC 9.3.0 baremetal ||"
		git clone --depth=1 https://github.com/arter97/arm64-gcc.git gcc64
		git clone --depth=1 https://github.com/arter97/arm32-gcc.git gcc32
		GCC64_DIR=$KERNEL_DIR/root/Android/Kernels/ToolChains/gcc
		GCC32_DIR=$KERNEL_DIR/root/Android/Kernels/ToolChains/gcc32
	fi

	msg "|| Cloning libufdt ||"
	git clone https://android.googlesource.com/platform/system/libufdt /root/Android/Kernels/ToolChains/scripts/ufdt/libufdt
	
	msg "|| Cloning Anykernel3 ||"
	git clone https://github.com/IamCOD3X/AnyKernel3.git AnyKernel3
}


##----------------------------------------------------------------------------##
##----------Export more variables --------------------------------------------##

exports() {
	export KBUILD_BUILD_USER="COD3X"
        export KBUILD_BUILD_HOST="COD3X"
	export ARCH=arm64
	export SUBARCH=arm64

	if [ $COMPILER = "clang" ]
	then
		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin:$GC_DIR/bin:$GC2_DIR/bin:$PATH
	elif [ $COMPILER = "gcc" ]
	then
		KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
		PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH
	fi

	export PATH KBUILD_COMPILER_STRING
	PROCS=$(nproc --all)
	export PROCS
}


##---------------------------------------------------------##
##--------------------Now Build it-------------------------##

build_kernel() {
	if [ $INCREMENTAL = 0 ]
	then
		msg "|| Cleaning Sources ||"
		rm -rf out && rm -rf AnyKernel3/Image && rm -rf AnyKernel3/*.zip
	fi

	sendInfo        "<b>===============================</b>" \
                "<b>Start Building :</b> <code>Preserver Kernel 4.19</code>" \
                "<b>Source Branch :</b> <code>$(git rev-parse --abbrev-ref HEAD)</code>" \
                "<b>Toolchain :</b> <code>$KBUILD_COMPILER_STRING</code>" \
                "<b>===============================</b>"

	make O=out $DEFCONFIG

        BUILD_START=$(date +"%s")

	if [ $COMPILER = "clang" ]
	then
		MAKE+=(
                        CLANG_TRIPLE=aarch64-linux-gnu- \
                        CROSS_COMPILE=aarch64-linux-android- \
                        CROSS_COMPILE_ARM32=arm-linux-androideabi-
			CC="ccache clang" \
			LD=$LINKER \
			AR=llvm-ar \
			OBJDUMP=llvm-objdump \
			STRIP=llvm-strip \
                        DTC_EXT=$KERNEL_DIR/dtc
		)
	elif [ $COMPILER = "gcc" ]
	then
		MAKE+=(
			CROSS_COMPILE_ARM32=arm-eabi- \
			CROSS_COMPILE=aarch64-elf- \
			LD=$LINKER \
			AR=aarch64-elf-ar \
			OBJDUMP=aarch64-elf-objdump \
			STRIP=aarch64-elf-strip
		)
	fi

	if [ $SILENCE = "1" ]
	then
		MAKE+=( -s )
	fi

	msg "|| Started Compilation ||"
	export PATH="/usr/lib/ccache:$PATH"
	make -j"$PROCS" O=out \
		NM=llvm-nm \
		OBJCOPY=llvm-objcopy \
		LD=ld.lld "${MAKE[@]}" 2>&1

		if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/Image ]
	    then
	    	msg "|| Kernel successfully compiled ||"
	    	if [ $BUILD_DTBO = 1 ]
			then
				msg "|| Building DTBO ||"
				python2 "/root/Android/Kernel/ToolChains/scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
				create "$KERNEL_DIR/out/arch/arm64/boot/dtbo.img" --page_size=4096 "$KERNEL_DIR/out/arch/arm64/boot/dts/vendor/qcom/avicii-overlay.dtbo"
			fi
				gen_zip

		fi

}
##-----------------------------------------------------------##
##--------------Compile AnyKernel Zip------------------------##


gen_zip() {
	msg "|| Zipping into a flashable zip ||"
	mv "$KERNEL_DIR"/out/arch/arm64/boot/Image AnyKernel3
        mv "$KERNEL_DIR"/out/arch/arm64/boot/dtbo.img AnyKernel3

	cd AnyKernel3 || exit
	zip -r9 $ZIPNAME-AOSP-$DEVICE-$DATE.zip * -x .git README.md

##-----------------Uploading-------------------------------##

msg "|| Uploading ||"
	cd ..
	DATE=$(date +"%Y%m%d-%H%M")
	TELEGRAM=Telegram/telegram
	CHANNEL_ID=-xxxx
	"${TELEGRAM}" -f "$(echo "$(pwd)"/AnyKernel3/*.zip)" -c "${CHANNEL_ID}" -H "nacho bc"
	sendInfo "<b>BUILD took $((DIFF / 60))m:$((DIFF % 60))s </b>" \
	         "=================================" \
			 "<b>Linux Version :</b> <code>$(cat < out/.config | grep Linux/arm64 | cut -d " " -f3)</code>" \
             "<b>Build Date :</b> <code>$(date +"%A, %d %b %Y, %H:%M:%S")</code>" \
	         " <b>Most recent changes are:</b> $(git log --pretty=format:'%h : %s' -15 --abbrev=7 --first-parent)"
	sendInfo "================================="		 
	print "$blue BUILD took $((DIFF / 60))m:$((DIFF % 60))s | Most recent changes are : \n $(git log --pretty=format:'%h : %s' -15 --abbrev=7 --first-parent)"
}

clone
exports
build_kernel

# Build complete
BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "$green Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$default"

##----------------*****-----------------------------##
