#!/bin/sh
#

: ${IPHONE_SDKVERSION:=`xcodebuild -showsdks | grep iphoneos | egrep "[[:digit:]]+\.[[:digit:]]+" -o | tail -1`}
: ${XCODE_ROOT:=`xcode-select -print-path`}

: ${SRCDIR:=`pwd`}
: ${IOSBUILDDIR:=`pwd`/ios/build}
: ${OSXBUILDDIR:=`pwd`/osx/build}
: ${PREFIXDIR:=`pwd`/ios/prefix}
: ${IOSFRAMEWORKDIR:=`pwd`/ios/framework}
: ${OSXFRAMEWORKDIR:=`pwd`/osx/framework}
: ${COMPILER:="gcc"}

: ${LUA_VERSION:=5.1.5}

#===============================================================================

ARM_DEV_DIR=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer/usr/bin/
SIM_DEV_DIR=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer/usr/bin/

ARM_COMBINED_LIB=$IOSBUILDDIR/lib_lua_arm.a
SIM_COMBINED_LIB=$IOSBUILDDIR/lib_lua_x86.a
OSX_COMBINED_LIB=$OSXBUILDDIR/lib_lua_osx.a

IOSSYSROOT=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$IPHONE_SDKVERSION.sdk
IOSSIMSYSROOT=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator$IPHONE_SDKVERSION.sdk

LUA_HEADERS="$SRCDIR/src/lua.h $SRCDIR/src/luaconf.h $SRCDIR/src/lualib.h $SRCDIR/src/lauxlib.h $SRCDIR/etc/lua.hpp"

EXTRA_CFLAGS="-DLUA_USE_DLOPEN"

compile_framework() {
	FRAMEWORK_BUNDLE=$1/lua.framework
	FRAMEWORK_VERSION=A
	FRAMEWORK_NAME=lua
	FRAMEWORK_CURRENT_VERSION=$LUA_VERSION

	shift;

	rm -rf $FRAMEWORK_BUNDLE

	mkdir -p $FRAMEWORK_BUNDLE
	mkdir -p $FRAMEWORK_BUNDLE/Versions
	mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION
	mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources
	mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers
	mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Documentation

	FRAMEWORK_INSTALL_NAME=$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME

	echo "Lipoing library into $FRAMEWORK_INSTALL_NAME..."
	cp `dirname $1`/luac $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/luac
	$ARM_DEV_DIR/lipo -create $@ -output "$FRAMEWORK_INSTALL_NAME" || exit

	ln -s $FRAMEWORK_VERSION               $FRAMEWORK_BUNDLE/Versions/Current
	ln -s Versions/Current/Headers         $FRAMEWORK_BUNDLE/Headers
	ln -s Versions/Current/Resources       $FRAMEWORK_BUNDLE/Resources
	ln -s Versions/Current/Documentation   $FRAMEWORK_BUNDLE/Documentation
	ln -s Versions/Current/$FRAMEWORK_NAME $FRAMEWORK_BUNDLE/$FRAMEWORK_NAME
	ln -s Versions/Current/luac            $FRAMEWORK_BUNDLE/luac

	echo "Framework: Copying includes..."
	cp -r $LUA_HEADERS  $FRAMEWORK_BUNDLE/Headers/

	echo "Framework: Creating plist..."
	cat > $FRAMEWORK_BUNDLE/Resources/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>CFBundleDevelopmentRegion</key>
		<string>English</string>
		<key>CFBundleExecutable</key>
		<string>${FRAMEWORK_NAME}</string>
		<key>CFBundleIdentifier</key>
		<string>org.lua</string>
		<key>CFBundleInfoDictionaryVersion</key>
		<string>6.0</string>
		<key>CFBundlePackageType</key>
		<string>FMWK</string>
		<key>CFBundleSignature</key>
		<string>????</string>
		<key>CFBundleVersion</key>
		<string>${FRAMEWORK_CURRENT_VERSION}</string>
	</dict>
</plist>
EOF
}


mkdir -p $IOSBUILDDIR
mkdir -p $OSXBUILDDIR

cd src && make clean echo liblua.a CC=$ARM_DEV_DIR$COMPILER \
	CFLAGS="-Wall -Os -arch armv6 -arch armv7 -arch armv7s -x c -isysroot $IOSSYSROOT $EXTRA_CFLAGS" \
	AR="$ARM_DEV_DIR/ar rcu" RANLIB="$ARM_DEV_DIR/ranlib"; cd -
cp src/liblua.a $ARM_COMBINED_LIB

make clean echo generic CC=$SIM_DEV_DIR$COMPILER \
	CFLAGS="-Wall -Os -arch i386 -x c -isysroot $IOSSIMSYSROOT $EXTRA_CFLAGS" \
	MYLDFLAGS="-arch i386 -isysroot $IOSSIMSYSROOT" \
	AR="$ARM_DEV_DIR/ar rcu" RANLIB="$ARM_DEV_DIR/ranlib"
cp src/liblua.a $SIM_COMBINED_LIB

cp src/luac $IOSBUILDDIR/luac

echo build ios framework ...
compile_framework $IOSFRAMEWORKDIR $ARM_COMBINED_LIB $SIM_COMBINED_LIB

echo build osx framework ...
make clean echo macosx  CC=clang
cp src/liblua.a $OSX_COMBINED_LIB
cp src/luac $OSXBUILDDIR/luac
compile_framework $OSXFRAMEWORKDIR $OSX_COMBINED_LIB

echo framework will be at $IOSFRAMEWORKDIR and $OSXFRAMEWORKDIR
echo success!
