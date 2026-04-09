#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.ffmpeg-build-universal"
SRC_DIR="${BUILD_DIR}/src"
OUT_DIR="${ROOT_DIR}/Frameworks"
FFMPEG_VERSION="${1:-7.0}"
FFMPEG_TARBALL="ffmpeg-${FFMPEG_VERSION}.tar.xz"
FFMPEG_URL="https://ffmpeg.org/releases/${FFMPEG_TARBALL}"
CPU_COUNT="$(sysctl -n hw.ncpu)"

mkdir -p "${BUILD_DIR}" "${OUT_DIR}"

download_source() {
  if [[ ! -d "${SRC_DIR}" ]]; then
    mkdir -p "${SRC_DIR}"
    curl -L "${FFMPEG_URL}" -o "${BUILD_DIR}/${FFMPEG_TARBALL}"
    tar -xf "${BUILD_DIR}/${FFMPEG_TARBALL}" -C "${BUILD_DIR}"
    mv "${BUILD_DIR}/ffmpeg-${FFMPEG_VERSION}" "${SRC_DIR}"
  fi
}

configure_and_build() {
  local sdk="$1"
  local arch="$2"
  local platform_label="$3"
  local min_flag="$4"
  local prefix="${BUILD_DIR}/install-${platform_label}-${arch}"

  rm -rf "${prefix}"
  mkdir -p "${prefix}"

  pushd "${SRC_DIR}" >/dev/null
  make distclean >/dev/null 2>&1 || true

  local cc
  cc="$(xcrun --sdk "${sdk}" -find clang)"
  local cflags
  cflags="-arch ${arch} ${min_flag} -fembed-bitcode"

  ./configure \
    --prefix="${prefix}" \
    --target-os=darwin \
    --arch="${arch}" \
    --cc="${cc}" \
    --enable-cross-compile \
    --sysroot="$(xcrun --sdk "${sdk}" --show-sdk-path)" \
    --extra-cflags="${cflags}" \
    --extra-ldflags="${cflags}" \
    --disable-debug \
    --disable-doc \
    --disable-programs \
    --disable-avdevice \
    --disable-swresample \
    --disable-swscale \
    --disable-postproc \
    --disable-encoders \
    --disable-decoders \
    --disable-hwaccels \
    --enable-static \
    --disable-shared \
    --enable-pic \
    --enable-network \
    --enable-protocol=http \
    --enable-protocol=https \
    --enable-protocol=ftp \
    --enable-protocol=file \
    --enable-demuxer=mov \
    --enable-demuxer=matroska \
    --enable-demuxer=mpegts \
    --enable-demuxer=h264 \
    --enable-demuxer=hevc \
    --enable-demuxer=hls \
    --enable-demuxer=dash \
    --enable-parser=h264 \
    --enable-parser=hevc \
    --enable-bsf=h264_mp4toannexb \
    --enable-bsf=hevc_mp4toannexb

  make -j"${CPU_COUNT}"
  make install
  popd >/dev/null
}

lipo_platform() {
  local outpath="$1"
  shift
  xcrun lipo -create "$@" -output "${outpath}"
}

build_xcframework_for_lib() {
  local libbase="$1"
  shift
  local headers="${BUILD_DIR}/install-ios-arm64/include"
  local args=()

  while [[ $# -gt 0 ]]; do
    args+=( -library "$1" -headers "${headers}" )
    shift
  done

  xcodebuild -create-xcframework "${args[@]}" -output "${OUT_DIR}/${libbase}.xcframework"
}

download_source

configure_and_build iphoneos arm64 ios "-miphoneos-version-min=17.0"
configure_and_build iphonesimulator arm64 iossim_arm64 "-mios-simulator-version-min=17.0"
configure_and_build iphonesimulator x86_64 iossim_x86_64 "-mios-simulator-version-min=17.0"
configure_and_build xros arm64 xros "-mvisionos-version-min=2.0"
configure_and_build xrsimulator arm64 xrossim_arm64 "-mvisionos-simulator-version-min=2.0"
configure_and_build xrsimulator x86_64 xrossim_x86_64 "-mvisionos-simulator-version-min=2.0"

mkdir -p "${BUILD_DIR}/universal-ios" "${BUILD_DIR}/universal-iossim" "${BUILD_DIR}/universal-xros" "${BUILD_DIR}/universal-xrossim"

for lib in libavformat libavcodec libavutil; do
  lipo_platform "${BUILD_DIR}/universal-ios/${lib}.a" \
    "${BUILD_DIR}/install-ios-arm64/lib/${lib}.a"

  lipo_platform "${BUILD_DIR}/universal-iossim/${lib}.a" \
    "${BUILD_DIR}/install-iossim_arm64/lib/${lib}.a" \
    "${BUILD_DIR}/install-iossim_x86_64/lib/${lib}.a"

  lipo_platform "${BUILD_DIR}/universal-xros/${lib}.a" \
    "${BUILD_DIR}/install-xros-arm64/lib/${lib}.a"

  lipo_platform "${BUILD_DIR}/universal-xrossim/${lib}.a" \
    "${BUILD_DIR}/install-xrossim_arm64/lib/${lib}.a" \
    "${BUILD_DIR}/install-xrossim_x86_64/lib/${lib}.a"

  build_xcframework_for_lib "${lib}" \
    "${BUILD_DIR}/universal-ios/${lib}.a" \
    "${BUILD_DIR}/universal-iossim/${lib}.a" \
    "${BUILD_DIR}/universal-xros/${lib}.a" \
    "${BUILD_DIR}/universal-xrossim/${lib}.a"
done

echo "Built XCFrameworks in ${OUT_DIR}:"
ls -1 "${OUT_DIR}" | grep '.xcframework$' || true
