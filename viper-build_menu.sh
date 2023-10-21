#!/bin/bash
#
# Compile script for LOS kernel
# Copyright (C) 2023 IamCOD3X

SECONDS=0 # builtin bash timer

#Set Color
blue='\033[0;34m'
grn='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'
txtbld=$(tput bold)
txtrst=$(tput sgr0)  

echo -e " "
echo -e " "
echo -e "$red   ██▓▒­░⡷⠂𝚅𝙸𝙿𝟹𝚁-𝙺𝙴𝚁𝙽𝙴𝙻𝚜⠐⢾░▒▓██$nocol"
echo -e "$yellow██▓▒­░⡷⠂𝙱𝚞𝚒𝚕𝚍 𝙵𝚘𝚛 𝙽𝚎𝚝𝙷𝚞𝚗𝚝𝚎𝚛⠐⢾░▒▓██"
echo -e " "
echo -e " "

# cmdline options
clean=false
regen=false
do_not_send_to_tg=true
help=false
miui=false

# cmdline check flags
description_was_specified=false

for arg in "$@"; do
	case $arg in
		-c|--clean)clean=true; shift;;
		-r|--regen*)regen=true; shift;;
		-l|--local*)do_not_send_to_tg=true; shift;;
		-h|--help*)help=true; shift;;
		-d|--desc*)
			shift
			case $1 in
				-*);;
				*)
					description_was_specified=true
					DESC="$1"
					shift
					;;
			esac
			;;

		-n|--night*)TYPE=nightly; shift;;
		-s|--stab*)TYPE=stable; shift;;
		-e|--exp*)TYPE=experimental; shift;;
		-mi|--miui*)miui=true; shift;;
	esac
done
case $TYPE in nightly|stable);; *)TYPE=stable;; esac

# debug:
#echo "`date`: $clean $regen $help $do_not_send_to_tg $TYPE $DESC" >>build_sh.log

make kernelversion \
    | grep -v make > linuxver & wait $!
KERN_VER="$(head -n 1 linuxver)"
BUILD_DATE=$(date '+%Y-%m-%d  %H:%M')
DEVICE="sweet"                                                                   # Add Device Name
VERSION="1.0"
KERNELNAME="ViP3R-$TYPE"
if $miui; then
ZIPNAME="ViP3R-KERNEL-$VERSION-$(date '+%Y%m%d%H%M')-$TYPE.zip"
else
ZIPNAME="ViP3R-KERNEL-$VERSION-$(date '+%Y%m%d%H%M')-$TYPE.zip"
fi
TC_DIR="/root/Android/Kernels/ToolChains/proton-clang"
DEFCONFIG="_defconfig"                                                      # Add Defconfig


export PATH="$TC_DIR/bin:$PATH"
export KBUILD_BUILD_USER="COD3X"
export KBUILD_BUILD_HOST=Ryzen

# Builder detection
[ -n "$HOSTNAME" ] && NAME=$HOSTNAME
case $NAME in
	IgorK-*)BUILDER='@ViP3R';;
	*)BUILDER='@IamCOD3X';;
esac

echo -e "${txtbld}Type:${txtrst} $TYPE"
echo -e "${txtbld}Config:${txtrst} $DEFCONFIG"
echo -e "${txtbld}ARCH:${txtrst} arm64"
echo -e "${txtbld}Linux:${txtrst} $KERN_VER"
echo -e "${txtbld}Username:${txtrst} $KBUILD_BUILD_USER"
echo -e "${txtbld}Builder:${txtrst} $BUILDER"
echo -e "${txtbld}BuildDate:${txtrst} $BUILD_DATE"
echo -e "${txtbld}Filename::${txtrst} $ZIPNAME"
echo -e " "

if ! [ -d "$TC_DIR" ]; then
	echo -e "$grn \nProton clang not found! Cloning to $TC_DIR...\n $nocol"
	if ! git clone -q --depth=1 --single-branch https://github.com/kdrag0n/proton-clang $TC_DIR; then
		echo -e "$red \nCloning failed! Aborting...\n $nocol"
		exit 1
	fi
fi

# Help information 
if $help; then
	echo -e "Usage: ./build.sh [ -c | --clean, -d <args> | --desc <args>,
                  -h | --help, -r | --regen, -l | --local-build ]\n
These are common commands used in various situations:\n
$grn -c or --clean			$nocol Remove files in out folder for clean build.
$grn -d or --description		$nocol Adds a description for build;
				 Used with the <args> argument that contains the description.
				 Build's description is an important part, so if you do not specify it manually, you will be asked about entering it.
$grn -h or --help			$nocol List available subcommands.
$grn -r or --regenerate		$nocol Record changes to the defconfigs.
$grn -l or --local-build		$nocol Build locally, do not push the archive to Telegram. \n
Build type names:
$grn -s or --stable			$nocol Stable build
$grn -n or --nightly		$nocol Nightly build
$grn -s or --experimental		$nocol Experimental build\n"

	sleep 1.5
	exit 0
fi

# Clean 
if $clean; then
	if [  -d "./out/" ]; then
		echo -e " "
		rm -rf ./out/
	fi
	echo -e "$grn \nFull cleaning was successful succesfully!\n $nocol"
	sleep 1.5
fi


# Export defconfig
echo -e "$blue    \nMake DefConfig\n $nocol"
mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

if $regen; then
	cp out/.config arch/arm64/configs/$DEFCONFIG
	sed -i "48s/.*/CONFIG_LOCALVERSION=\"-NetHunter\"/g" arch/arm64/configs/$DEFCONFIG
	git commit -am "defconfig:" $DEVICE "Regenerate" --signoff
	echo -e "$grn \nRegened defconfig succesfully!\n $nocol"
	make mrproper
	echo -e "$grn \nCleaning was successful succesfully!\n $nocol"
	sleep 4
	exit 0
fi

# Description check
if ! $description_was_specified; then
	echo -en "\n\tYou did not specify the build's description! Do you want to set it?\n\t(Y/n): "
	read ans
	case $ans in n)echo -e "\tOK, the build will have no description...\n";;
	*)
		echo -en "\n\t\tType in the build's description: "
		read DESC
		echo -e "\n\tOK, saved!\n"
		sleep 1.5
		;;
	esac
fi

# Build start
echo -e "$blue    \nStarting kernel compilation...\n $nocol"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- CLANG_TRIPLE=aarch64-linux-gnu- Image.gz-dtb dtbo.img CONFIG_NO_ERROR_ON_MISMATCH=y 

kernel="out/arch/arm64/boot/Image.gz-dtb"
dtbo="out/arch/arm64/boot/dtbo.img"

if [ -f "$kernel" ] && [ -f "$dtbo" ]; then
	echo -e "$blue    \nKernel compiled succesfully! Zipping up...\n $nocol"
	if ! [ -d "AnyKernel3" ]; then
		echo -e "$grn \nAnyKernel3 not found! Cloning...\n $nocol"
		if ! git clone https://github.com/IamCOD3X/AnyKernel3.git; then
			echo -e "$grn \nCloning failed! Aborting...\n $nocol"
		fi
	fi

	cp $kernel $dtbo AnyKernel3
	rm -f *zip
	cd AnyKernel3
	zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
	cd ..
	echo -e "$grn \n(i)          Completed build$nocol $red$((SECONDS / 60))$nocol $grn minute(s) and$nocol $red$((SECONDS % 60))$nocol $grn second(s) !$nocol"
	echo -e "$blue    \n             Flashable zip generated $yellow$ZIPNAME.\n $nocol"


	# TEMP
	sed -i "48s/-experimental//" arch/arm64/configs/$DEFCONFIG
else
	echo -e "$red \nKernel Compilation failed! Fix the errors!\n $nocol"
		sleep 4
	exit 1
fi
