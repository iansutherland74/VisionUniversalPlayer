#!/usr/bin/env bash
set -euo pipefail

# Demux-only FFmpeg build for visionOS.
# Produces static libs and XCFrameworks for:
#   - libavformat
#   - libavcodec
#   - libavutil
# Enables protocols needed by this player:
#   http, https, ftp
# WebDAV is supported over HTTP(S) methods, so no separate FFmpeg protocol toggle exists.
# Enables bitstream filters required by bridge:
#   h264_mp4toannexb, hevc_mp4toannexb

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.ffmpeg-build"
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
    --disable-network \
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
    --enable-bsf=hevc_mp4toannexb \
    --disable-encoders \
    --disable-decoders \
    --disable-hwaccels \
    --enable-static \
    --disable-shared \
    --enable-pic

  make -j"${CPU_COUNT}"
  make install
  popd >/dev/null
}

lipo_platform() {
  local libname="$1"
  local outpath="$2"
  shift 2
  xcrun lipo -create "$@" -output "${outpath}"
}

build_xcframework_for_lib() {
  local libbase="$1"

  local xros_device="${BUILD_DIR}/universal-xros/${libbase}.a"
  local xros_sim="${BUILD_DIR}/universal-xrossim/${libbase}.a"

  local headers="${BUILD_DIR}/install-xros-arm64/include"

  xcodebuild -create-xcframework \
    -library "${xros_device}" -headers "${headers}" \
    -library "${xros_sim}" -headers "${headers}" \
    -output "${OUT_DIR}/${libbase}.xcframework"
}

download_source

# visionOS
configure_and_build xros arm64 xros "-mvisionos-version-min=2.0"
configure_and_build xrsimulator arm64 xrossim_arm64 "-mvisionos-simulator-version-min=2.0"
configure_and_build xrsimulator x86_64 xrossim_x86_64 "-mvisionos-simulator-version-min=2.0"

mkdir -p "${BUILD_DIR}/universal-xros" "${BUILD_DIR}/universal-xrossim"

for lib in libavformat libavcodec libavutil; do
  lipo_platform "${lib}" "${BUILD_DIR}/universal-xros/${lib}.a" \
    "${BUILD_DIR}/install-xros-arm64/lib/${lib}.a"

  lipo_platform "${lib}" "${BUILD_DIR}/universal-xrossim/${lib}.a" \
    "${BUILD_DIR}/install-xrossim_arm64/lib/${lib}.a" \
    "${BUILD_DIR}/install-xrossim_x86_64/lib/${lib}.a"

  build_xcframework_for_lib "${lib}"
done

echo "Built XCFrameworks in ${OUT_DIR}:"
ls -1 "${OUT_DIR}" | grep '.xcframework$' || true
