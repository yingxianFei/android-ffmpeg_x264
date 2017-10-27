#!/bin/bash
BUILD_PROCESSOR_NUM=`cat /proc/cpuinfo| grep "processor"| wc -l`
echo -e "\033[32;49;1m [INFO:Build with $BUILD_PROCESSOR_NUM Cpu processor(s).] \033[39;49;0m"

# usage
function usage() {
cat << EOF
usage: $0 options

OPTIONS:
   -n [gcc base] 	base path to gcc
   -p [profile] 	the profile to use
EOF
exit 1
}

# checks to ensure an exit code is 0
check_exit() {
	if [[ "$1" != "0" ]];
	then
		echo ""
		echo "********************************"
		echo "* EXITING FOR ERROR CODE: $1"
		echo "********************************"
		echo ""
		exit $1
	fi
}

# builds for a particular profile
build_for_profile() {
	profile=$1
	ndk_base=$2

	# bring in settings
	. profiles/$profile.profile
	check_exit $?

	# setup ndk
	HOST_PROCESSOR=x86
	if [[ $(uname -m) == "x86_64" ]];
	then
	    HOST_PROCESSOR=x86_64
	fi
	# the rest
	PREFIX="$(pwd)/build/$profile"
	NDK_UNAME=`uname -s | tr '[A-Z]' '[a-z]'`
	NDK_TOOLCHAIN_BASE=$ndk_base
	echo ""
	echo "##"
	echo "# NDK_BASE: $NDK_BASE"
	echo "# PROFILE: $profile"
	echo "# NDK_TOOLCHAIN_BASE: $NDK_TOOLCHAIN_BASE"
	echo "# NDK_SYSROOT: $NDK_SYSROOT"
	echo "##"
	echo ""

	# configure
	cd x264 && \
		./configure --cross-prefix=$NDK_TOOLCHAIN_BASE/bin/$FG_NDK_CROSS_PREFIX \
			--extra-cflags="$FG_X264_EXTRA_CFLAGS" \
			--prefix=$PREFIX \
			--host=$FG_X264_HOST \
			--enable-pic \
			--enable-shared  \
			--enable-static \
			--disable-asm \
			--disable-cli && \
		make -j$BUILD_PROCESSOR_NUM && \
		make -j$BUILD_PROCESSOR_NUM prefix=$PREFIX install && \
		cd ..
	check_exit $?
	
	# configure
	cd ffmpeg && \
		./configure --cross-prefix=$NDK_TOOLCHAIN_BASE/bin/$FG_NDK_CROSS_PREFIX \
			--arch=$FG_NDK_ARCH \
			--cpu=$FG_FFMPEG_CPU \
			--target-os=linux \
			--enable-runtime-cpudetect \
			--prefix=$PREFIX \
			--enable-pic \
			--disable-shared  \
			--enable-static \
			--extra-cflags="-I$PREFIX/include $FG_FFMPEG_EXTRA_CFLAGS" \
			--extra-ldflags="-L$PREFIX/lib" \
			--enable-nonfree \
			--enable-version3 \
			--enable-gpl \
			--disable-yasm \
			--disable-asm \
			--enable-encoders \
			--enable-parsers \
			--enable-protocols \
			--enable-filters \
			--enable-avresample \
			--disable-indevs \
			--disable-outdevs \
			--enable-hwaccels \
			--enable-ffmpeg \
			--enable-ffplay \
			--enable-ffprobe \
			--enable-ffserver \
			--enable-libx264
		make -j$BUILD_PROCESSOR_NUM && \
		make -j$BUILD_PROCESSOR_NUM prefix=$PREFIX install && \
		cd ..
    check_exit $?	
}

# get args
PROFILES=""
NDK_BASE=$ANDROID_NDK_HOME
while getopts "p:n:" opt; do
    case $opt in
        p)
            PROFILES="$PROFILES$OPTARG "
            ;;
        n)
            NDK_BASE="$OPTARG"
            ;;
        ?)
            usage
            ;;
    esac
done

# clean first
if [[ -e build ]];
then
	rm -rf build
fi
mkdir build

# build
for p in $PROFILES;
do 
	build_for_profile "$p" "$NDK_BASE"
done
