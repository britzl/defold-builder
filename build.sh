#!/usr/bin/env bash

usage()
{
	echo "Wrapper for downloading and using bob.jar

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
	-p | --platform                   (string) Platform to build for
	-a | --archive                    Create archive when building
	-d | --debug                      Create debug build
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
		-p | --platform)
			PLATFORM="${VALUE}"
			;;
		-a | --archive)
			ARCHIVE="${PARAM}"
			;;
		-d | --debug)
			DEBUG="${PARAM}"
			;;
		-v | --verbose)
			VERBOSE="${PARAM}"
			;;
		--log)
			LOG="${PARAM}"
			;;

		*)
			echo "ERROR: unknown parameter \"$PARAM\""
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
	java -Djava.ext.dirs=${JAVA_HOME}/jre/lib/ext -jar ${BOB_JAR} ${VERBOSE} "$@"
}

clean() {
	bob clean
}

resolve() {
	if [ -z "${EMAIL}" ]; then usage; exit 1; fi
	if [ -z "${AUTH}" ]; then usage; exit 1; fi
	log "Resolving dependencies"
	bob --email "${EMAIL}" --auth "${AUTH}" resolve
}

build() {
	if [ -z "${PLATFORM}" ]; then usage; exit 1; fi
	log "Building ${PLATFORM}"
	bob --platform ${PLATFORM} ${DEBUG} ${ARCHIVE} build
}

bundle() {
	if [ -z "${PLATFORM}" ]; then usage; exit 1; fi
	log "Bundling ${PLATFORM}"
	bob --platform ${PLATFORM} --bundle-output build/${PLATFORM} bundle
}

build_android() {
	bob --platform ${PLATFORM_ANDROID} ${DEBUG} ${ARCHIVE} build
}

build_ios() {
	bob --platform ${PLATFORM_IOS} ${DEBUG} ${ARCHIVE} build
}

bundle_android() {
	if [ -z "${CERTIFICATE}" ]; then usage; exit 1; fi
	if [ -z "${PRIVATEKEY}" ]; then usage; exit 1; fi
	bob --platform ${PLATFORM_ANDROID} --bundle-output build/${PLATFORM_ANDROID} --certificate "${CERTIFICATE}" --private-key "${PRIVATEKEY}" bundle
}

bundle_ios() {
	if [ -z "${MOBILEPROVISIONING}" ]; then usage; exit 1; fi
	if [ -z "${IDENTITY}" ]; then usage; exit 1; fi
	bob --platform ${PLATFORM_IOS} --bundle-output build/${PLATFORM_IOS} --mobileprovisioning "${MOBILEPROVISIONING}" --identity "${IDENTITY}" bundle
}


setup

while [ "$1" != "" ]; do
	COMMAND=$1; shift 1
	${COMMAND}
done
