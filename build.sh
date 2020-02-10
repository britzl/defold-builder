#!/usr/bin/env bash

set -e

usage()
{
	echo "
Wrapper for downloading and using bob.jar
Get the latest version of this script from https://github.com/britzl/defold-builder

usage: build.sh [options] [command ...]

options:
	-h | --help                       Show this help
	-e | --email                      (string) E-mail to use when resolving dependencies
	-u | --auth                       (string) Defold auth token to use when resolving dependencies
	-mp | --mobileprovisioning        (string) Provisioning profile to use when bundling for iOS
	--identity                        (string) Signing identity to use when bundling for iOS
	-ce | --certificate               (string) Certificate to use when bundling for Android
	-pk | --private-key               (string) Private key to use when bundling for Android
	--sha1                 	          (string) SHA1 of engine to use
	--channel                         (alpha|beta|stable) Get SHA1 of engine from latest
	--build-server                    (string) default is https://build.defold.com
	--with-symbols                    Enables a build with debug symbols (for apps using native extensions)
	-p | --platform                   (string) Platform to build for
	-a | --archive                    Create archive when building
	-d | --debug                      Create debug build (deprecated: will set variant to debug)
	--se | --strip-executable         Strip the executable when bundling for Android or iOS
	-V | --variant                    (string) Build variant (headless, debug or release)
	-v | --verbose                    Show verbose output from bob.jar
	--log                             Show verbose output this script

commands:
	clean
	resolve
	build
	build_ios
	build_android
	bundle
	bundle_ios
	bundle_android
"
}

log() {
	if [ ! -z ${LOG} ]; then
		echo "$@"
	fi
}

err() {
	echo "ERROR: $@"
}

VARIANT="release"
BUILD_SERVER="https://build.defold.com"
STRIP_EXECUTABLE=""
while [ "$1" != "" ]; do
	PARAM=`echo $1 | awk -F= '{print $1}'`
	VALUE=`echo $1 | awk -F= '{print $2}'`
	if [[ ${PARAM} != -* ]]; then
		break
	fi
	case ${PARAM} in
		-h | --help)
			usage
			exit
			;;
		-e | --email)
			EMAIL="${VALUE}"
			;;
		-u | --auth)
			AUTH="${VALUE}"
			;;
		-mp | --mobileprovisioning)
			MOBILEPROVISIONING="${VALUE}"
			;;
		--identity)
			IDENTITY="${VALUE}"
			;;
		-ce | --certificate)
			CERTIFICATE="${VALUE}"
			;;
		-pk | --private-key)
			PRIVATEKEY="${VALUE}"
			;;
		--sha1)
			SHA1="${VALUE}"
			;;
		--channel)
			CHANNEL="${VALUE}"
			;;
		--build-server)
			BUILD_SERVER=="${VALUE}"
			;;
		--with-symbols)
			WITH_SYMBOLS=="${PARAM}"
			;;
		-p | --platform)
			PLATFORM="${VALUE}"
			;;
		-a | --archive)
			ARCHIVE="${PARAM}"
			;;
		-d | --debug)
			VARIANT="debug"
			;;
		-V | --variant)
			VARIANT="${VALUE}"
			;;
		-v | --verbose)
			VERBOSE="${PARAM}"
			;;
		-se | --strip-executable)
			STRIP_EXECUTABLE="--strip-executable"
			;;
		--log)
			LOG="${PARAM}"
			;;

		*)
			echo "unknown parameter \"$PARAM\""
			usage
			exit 1
			;;
	esac
	shift
done

PLATFORM_ANDROID=armv7-android
PLATFORM_IOS=armv7-darwin

setup() {
	log "Setting up the project"

	if [ ! -z ${CHANNEL} ]; then
		SHA1=$(curl -s http://d.defold.com/${CHANNEL}/info.json | sed 's/.*sha1": "\(.*\)".*/\1/')
		log "Using SHA1 of latest release on channel ${CHANNEL} (SHA1: '${SHA1}')"
	elif [ -z ${SHA1} ]; then
		SHA1=$(curl -s http://d.defold.com/stable/info.json | sed 's/.*sha1": "\(.*\)".*/\1/')
		log "Using SHA1 of latest stable release (SHA1: '${SHA1}')"
	else
		log "Using predefined SHA1 (SHA1: '${SHA1}')"
	fi

	BOB_JAR=bob_${SHA1}.jar
	BOB_URL="http://d.defold.com/archive/${SHA1}/bob/bob.jar"
	if [ ! -f ${BOB_JAR} ]; then
		log "Downloading ${BOB_URL}"
		curl -o ${BOB_JAR} ${BOB_URL}
	fi
}

bob() {
	log "bob $@"
	java -jar ${BOB_JAR} ${VERBOSE} "$@"
}

clean() {
	bob clean
}

resolve() {
	if [ -z "${EMAIL}" ]; then usage; err "Missing email"; exit 1; fi
	if [ -z "${AUTH}" ]; then usage; err "Missing auth"; exit 1; fi
	log "Resolving dependencies"
	bob --email "${EMAIL}" --auth "${AUTH}" resolve
}

build() {
	if [ -z "${PLATFORM}" ]; then usage; err "Missing platform"; exit 1; fi
	log "Building ${PLATFORM}"
	bob --platform ${PLATFORM} --variant ${VARIANT} ${ARCHIVE} --build-server=${BUILD_SERVER} ${WITH_SYMBOLS} build
}

build_android() {
	bob --platform ${PLATFORM_ANDROID} --variant ${VARIANT} ${ARCHIVE} --build-server=${BUILD_SERVER} ${WITH_SYMBOLS} build
}

build_ios() {
	bob --platform ${PLATFORM_IOS} --variant ${VARIANT} ${ARCHIVE} --build-server=${BUILD_SERVER} ${WITH_SYMBOLS} build
}

bundle() {
	if [ -z "${PLATFORM}" ]; then usage; err "Missing platform"; exit 1; fi
	log "Bundling ${PLATFORM}"
	bob --platform ${PLATFORM} --variant ${VARIANT} ${STRIP_EXECUTABLE} --bundle-output build/${PLATFORM} bundle
}

bundle_android() {
	if [ -z "${CERTIFICATE}" ]; then usage; err "Missing certificate"; exit 1; fi
	if [ -z "${PRIVATEKEY}" ]; then usage; err "Missing key"; exit 1; fi
	bob --platform ${PLATFORM_ANDROID} --variant ${VARIANT} ${STRIP_EXECUTABLE} --bundle-output build/${PLATFORM_ANDROID} --certificate "${CERTIFICATE}" --private-key "${PRIVATEKEY}" bundle
}

bundle_ios() {
	if [ -z "${MOBILEPROVISIONING}" ]; then usage; err "Missing mobile provisioning"; exit 1; fi
	if [ -z "${IDENTITY}" ]; then usage; err "Missing signing identity"; exit 1; fi
	bob --platform ${PLATFORM_IOS} --variant ${VARIANT} ${STRIP_EXECUTABLE} --bundle-output build/${PLATFORM_IOS} --mobileprovisioning "${MOBILEPROVISIONING}" --identity "${IDENTITY}" bundle
}


setup

while [ "$1" != "" ]; do
	COMMAND=$1; shift 1
	${COMMAND}
done
