FROM ubuntu:22.04

# Set environment variables to avoid user interaction during the installation process
ENV DEBIAN_FRONTEND=noninteractive

###
# prepare environment
###

RUN apt update && apt upgrade -y

# Install Python versions and pip
RUN apt install -y \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    python3-pip \
    python-is-python3

RUN apt install -y \
    libgl1-mesa-glx \
    curl \
    wget \
    make \
    cmake \
    libssl-dev \
    libffi-dev \
    libopenblas-dev \
    git

###
# Install compilers and build tools
###

# from https://github.com/styler00dollar/VSGAN-tensorrt-docker/blob/main/Dockerfile#L382
RUN apt install autoconf libtool nasm ninja-build yasm pkg-config checkinstall -y && \
    apt --fix-broken install && \
    pip install --no-cache-dir meson ninja cython

# install g++13
RUN apt install build-essential manpages-dev software-properties-common -y && \
    add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
    apt update -y && \
    apt install gcc-13 g++-13 -y && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 13 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 13


###
# Set the working directory for CUDA
###
WORKDIR /cuda

###
# set up CUDA environment (CUDA 12.9)
###

RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt update && \
    apt install -y cuda-nvcc-12-9 cuda-cudart-dev-12-9 cuda-nvrtc-dev-12-9 libcufft-dev-12-9 && \
    apt clean

# set up environment variables
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV CUDA_PATH=/usr/local/cuda
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

###
# Set the working directory for VapourSynth and FFmpeg
###
WORKDIR /workspace

###
# Install VapourSynth
###

# zimg
# setting pkg version manually since otherwise 'Version' field value '-1': version number is empty
RUN git clone https://github.com/sekrit-twc/zimg --recursive && cd zimg && \
  ./autogen.sh && ./configure && make -j$(nproc) && make install && \
  checkinstall -y -pkgversion=0.0 && apt install ./zimg_0.0-1_amd64.deb -y

### Install VapourSynth
ARG VAPOURSYNTH_VERSION=R70
RUN wget https://github.com/vapoursynth/vapoursynth/archive/refs/tags/${VAPOURSYNTH_VERSION}.tar.gz && \
  tar -zxf ${VAPOURSYNTH_VERSION}.tar.gz && rm ${VAPOURSYNTH_VERSION}.tar.gz && mv vapoursynth-${VAPOURSYNTH_VERSION} vapoursynth && cd vapoursynth && \
  ./autogen.sh && ./configure && make -j$(nproc) && make install && ldconfig
# install vapoursynth python package
RUN cd vapoursynth && python setup.py install

###
# Install FFmpeg with Encoders
###

# --- prerequisites ---

RUN apt install -y \
    tcl \
    libfreetype-dev \
    libfribidi-dev \
    libfontconfig-dev \
    libharfbuzz-dev \
    libunibreak-dev \
    libsoxr-dev \
    libxml2-dev

# Vulkan-Headers
RUN git clone https://github.com/KhronosGroup/Vulkan-Headers.git --depth 1 && \
  cd Vulkan-Headers/ && cmake -S . -B build/ && cmake --install build

# nv-codec-headers
RUN wget https://github.com/FFmpeg/nv-codec-headers/releases/download/n12.2.72.0/nv-codec-headers-12.2.72.0.tar.gz && \
  tar -zxf nv-codec-headers-*.tar.gz && rm nv-codec-headers-*.tar.gz && \
  cd nv-codec-headers-* && make -j$(nproc) && make install

RUN git clone https://github.com/gypified/libmp3lame --depth 1 && \
  cd libmp3lame && ./configure --enable-nasm --enable-static --enable-shared && make -j$(nproc) install

RUN git clone https://github.com/mstorsjo/fdk-aac --depth 1 && \
  cd fdk-aac && ./autogen.sh && ./configure --enable-static --enable-shared && make -j$(nproc) install

RUN git clone https://github.com/xiph/ogg --depth 1 && \
  cd ogg && ./autogen.sh && ./configure --enable-static --enable-shared && make -j$(nproc) install

RUN git clone https://github.com/xiph/vorbis --depth 1 && \
  cd vorbis && ./autogen.sh && ./configure --enable-static --enable-shared && make -j$(nproc) install

RUN git clone https://github.com/xiph/opus --depth 1 && \
  cd opus && ./autogen.sh && ./configure --enable-static --enable-shared && make -j$(nproc) install

RUN git clone https://github.com/xiph/theora --depth 1 && \
  cd theora && ./autogen.sh && ./configure --disable-examples --enable-static --enable-shared && make -j$(nproc) install

RUN git clone https://github.com/webmproject/libvpx --depth 1 && \
  cd libvpx && ./configure --enable-vp9-highbitdepth --disable-unit-tests --disable-examples --enable-static --enable-shared && \
  make -j$(nproc) install

RUN git clone https://code.videolan.org/videolan/x264.git --depth 1 && \
  cd x264 && ./configure --enable-pic --enable-static --enable-shared && make -j$(nproc) install

ARG X265_VERSION=4.1
ARG X265_URL="https://bitbucket.org/multicoreware/x265_git/downloads/x265_$X265_VERSION.tar.gz"
# multilib.sh will build 8,10,12bit libraries and link them together to 8bit's directory
RUN wget -O x265.tar.gz "$X265_URL" && tar -zxf x265.tar.gz && rm x265.tar.gz && cd x265_*/build/linux && \
  MAKEFLAGS="-j$(nproc)" ./multilib.sh && \
  make -C 8bit -j$(nproc) install

RUN git clone https://github.com/webmproject/libwebp --depth 1 && \
  cd libwebp && ./autogen.sh && ./configure --enable-static --enable-shared && make -j$(nproc) install

RUN git clone https://github.com/xiph/speex --depth 1 && \
  cd speex && ./autogen.sh && ./configure --enable-static --enable-shared && make -j$(nproc) install

RUN git clone --depth 1 https://aomedia.googlesource.com/aom --depth 1 && \
  cd aom && mkdir build_tmp && cd build_tmp && \
  cmake \
    -DENABLE_TESTS=OFF \
    -DENABLE_NASM=ON \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DBUILD_SHARED_LIBS=ON \
    .. && \
    make -j$(nproc) install

RUN git clone https://github.com/georgmartius/vid.stab --depth 1 && \
  cd vid.stab && cmake -DBUILD_SHARED_LIBS=on . && make -j$(nproc) install

RUN git clone https://github.com/ultravideo/kvazaar --depth 1 && \
  cd kvazaar && ./autogen.sh && ./configure --enable-static --enable-shared && make -j$(nproc) install

# dependencies for libass and ffmpeg
# libfreetype-dev libfribidi-dev libfontconfig-dev libharfbuzz-dev libunibreak-dev
# libass
RUN git clone https://github.com/libass/libass --depth 1 && \
  cd libass && ./autogen.sh && ./configure --enable-static --enable-shared && make -j$(nproc) && make install

RUN git clone https://github.com/uclouvain/openjpeg --depth 1 && \
  cd openjpeg && cmake -G "Unix Makefiles" && make -j$(nproc) install

RUN git clone https://code.videolan.org/videolan/dav1d --depth 1 && \
  cd dav1d && meson build --buildtype release && ninja -C build install

# add extra CFLAGS that are not enabled by -O3
# http://websvn.xvid.org/cvs/viewvc.cgi/trunk/xvidcore/build/generic/configure.in?revision=2146&view=markup
ARG XVID_VERSION=1.3.7
ARG XVID_URL="https://downloads.xvid.com/downloads/xvidcore-$XVID_VERSION.tar.gz"
ARG XVID_SHA256=abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d
RUN wget -O libxvid.tar.gz "$XVID_URL" && \
    echo "$XVID_SHA256  libxvid.tar.gz" | sha256sum --status -c - && \
    tar -zxf libxvid.tar.gz && rm libxvid.tar.gz && \
    cd xvidcore/build/generic && \
    CFLAGS="-O2 -fno-strict-overflow -fstack-protector-all -fPIE -fstrength-reduce -ffast-math" ./configure && \
    make -j$(nproc) && make install

# configure use tcl sh
RUN git clone https://github.com/Haivision/srt --depth 1 && \
  cd srt && ./configure --cmake-install-libdir=lib --cmake-install-includedir=include --cmake-install-bindir=bin && \
  make -j$(nproc) && make install

RUN git clone https://github.com/gianni-rosato/svt-av1-psy --depth 1 && \
  cd svt-av1-psy/Build && \
    cmake \
    -G"Unix Makefiles" \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    .. && \
    make -j$(nproc) install

RUN git clone https://github.com/pkuvcl/davs2 --depth 1 && \
  cd davs2/build/linux && ./configure --disable-asm --enable-pic --enable-static --enable-shared && \
  make -j$(nproc) install

RUN git clone https://github.com/Netflix/vmaf --depth 1 && \
  cd vmaf/libvmaf && meson build --buildtype release && ninja -C build install

RUN git clone https://github.com/cisco/openh264 --depth 1 && \
  cd openh264 && meson build --buildtype release && ninja -C build install

RUN git clone https://github.com/mpeg5/xeve && \
  cd xeve && mkdir build && cd build && cmake .. && make -j$(nproc) && make install

# dependencies for ffmpeg: libsoxr-dev libxml2-dev
RUN wget https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n8.0.tar.gz && \
  tar -zxf n8.0.tar.gz && rm n8.0.tar.gz && mv FFmpeg-n8.0 FFmpeg && \
  cd FFmpeg && \
  CFLAGS="-O3 -static-libgcc -fno-strict-overflow -fstack-protector-all -fPIE" && \
    ./configure \
    --extra-cflags="-fopenmp -lcrypto -lz -ldl -I${CUDA_PATH}/include" \
    --extra-cxxflags="-fopenmp -lcrypto -lz -ldl -I${CUDA_PATH}/include" \
    --extra-ldflags="-fopenmp -lcrypto -lz -ldl -L${CUDA_PATH}/lib64" \
    --toolchain=hardened \
    --enable-static \
    --enable-shared \
    --disable-debug \
    --enable-pic \
    --enable-gpl \
    --enable-gray \
    --enable-nonfree \
    --enable-openssl \
    --enable-iconv \
    --enable-libxml2 \
    --enable-libmp3lame \
    --enable-libfdk-aac \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libtheora \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libwebp \
    --enable-libspeex \
    --enable-libaom \
    --enable-libvidstab \
    --enable-libkvazaar \
    --enable-libfreetype \
    --enable-fontconfig \
    --enable-libfribidi \
    --enable-libass \
    --enable-libsoxr \
    --enable-libopenjpeg \
    --enable-libdav1d \
    --enable-libsrt \
    --enable-libsvtav1 \
    --enable-libdavs2 \
    --enable-libvmaf \
    --enable-libxeve \
    --enable-cuda-nvcc \
    --enable-vapoursynth \
    --enable-libopenh264 \
    --enable-optimizations \
    --enable-nvdec \
    --enable-nvenc \
    --enable-cuvid \
    --enable-cuda \
    --enable-pthreads \
    --enable-runtime-cpudetect \
    --enable-lto && \
    make -j$(nproc) && make install

# Install static ffmpeg build (fallback)
COPY --from=mwader/static-ffmpeg:8.0 /ffmpeg /static-ffmpeg/ffmpeg
COPY --from=mwader/static-ffmpeg:8.0 /ffprobe /static-ffmpeg/ffprobe

###
# Install VapourSynth C++ plugins
###

# --- prerequisites ---

RUN apt install -y \
    autoconf \
    llvm-15 \
    nasm \
    libboost-dev \
    libxxhash-dev \
    libfftw3-dev \
    libtbb-dev

# jansson
RUN git clone https://github.com/akheron/jansson --depth 1 && cd jansson && autoreconf -fi && CFLAGS=-fPIC ./configure && \
  make -j$(nproc) && make install

# bzip2
RUN git clone https://github.com/libarchive/bzip2 --depth 1 && cd bzip2 && \
  mkdir build && cd build && cmake .. && make -j$(nproc) && make install

# --- VapourSynth plugins ---
# bestsource
RUN git clone https://github.com/vapoursynth/bestsource.git --depth 1 --recurse-submodules --shallow-submodules --remote-submodules && cd bestsource && \
  CFLAGS=-fPIC meson setup -Denable_plugin=true build && CFLAGS=-fPIC ninja -C build && ninja -C build install

# vs-miscfilters
RUN git clone https://github.com/vapoursynth/vs-miscfilters-obsolete --depth 1 && cd vs-miscfilters-obsolete && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# ffms2
RUN git clone https://github.com/FFMS/ffms2 --depth 1 && cd ffms2 && \
    ./autogen.sh && CFLAGS=-fPIC CXXFLAGS=-fPIC LDFLAGS="-Wl,-Bsymbolic" ./configure --enable-shared && make -j$(nproc) && make install
RUN ln -s /usr/local/lib/libffms2.so /usr/local/lib/vapoursynth/libffms2.so

# fmtconv
RUN git clone https://github.com/EleonoreMizo/fmtconv --depth 1 && cd fmtconv/build/unix/ && \
    ./autogen.sh && ./configure && make -j$(nproc) && make install
RUN ln -s /usr/local/lib/libfmtconv.so /usr/local/lib/vapoursynth/libfmtconv.so

# removegrain
RUN git clone https://github.com/vapoursynth/vs-removegrain --depth 1 && cd vs-removegrain && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# HomeOfVapourSynthEvolution's plugins
# Retinex
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-Retinex --depth 1 && cd VapourSynth-Retinex && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# TCanny
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-TCanny --depth 1 && cd VapourSynth-TCanny && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# CTMF
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-CTMF --depth 1 && cd VapourSynth-CTMF && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# CAS
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-CAS --depth 1 && cd VapourSynth-CAS && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# AddGrain
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-AddGrain --depth 1 && cd VapourSynth-AddGrain && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# Bilateral
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-Bilateral --depth 1 && cd VapourSynth-Bilateral && \
    ./configure && make -j$(nproc) && make install

# Bwdif
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-Bwdif --depth 1 && cd VapourSynth-Bwdif && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# DCTFilter
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-DCTFilter --depth 1 && cd VapourSynth-DCTFilter && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# TTempSmooth
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-TTempSmooth --depth 1 && cd VapourSynth-TTempSmooth && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# EEDI2
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-EEDI2 --depth 1 && cd VapourSynth-EEDI2 && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# EEDI3
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-EEDI3 --depth 1 && cd VapourSynth-EEDI3 && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# HomeOfAviSynthPlusEvolution's plugins
# neo_FFT3D
RUN git clone https://github.com/HomeOfAviSynthPlusEvolution/neo_FFT3D && cd neo_FFT3D && \
    cmake -S . -B build -G Ninja -LA && \
    cmake --build build --verbose
RUN cp neo_FFT3D/build/libneo-fft3d.so /usr/local/lib && \
    ln -s /usr/local/lib/libneo-fft3d.so /usr/local/lib/vapoursynth/libneo-fft3d.so

# neo_DFTTest
RUN git clone https://github.com/HomeOfAviSynthPlusEvolution/neo_DFTTest && cd neo_DFTTest && \
    cmake -S . -B build -G Ninja -LA && \
    cmake --build build --verbose
RUN cp neo_DFTTest/build/libneo-dfttest.so /usr/local/lib && \
    ln -s /usr/local/lib/libneo-dfttest.so /usr/local/lib/vapoursynth/libneo-dfttest.so

# neo_f3kdb
RUN git clone https://github.com/HomeOfAviSynthPlusEvolution/neo_f3kdb && cd neo_f3kdb && git checkout ad9fa1a11412ab46199d3b8e7cc2e5a89f1d5d1a && \
    cmake -S . -B build -G Ninja -LA && \
    cmake --build build --verbose
RUN cp neo_f3kdb/build/libneo-f3kdb.so /usr/local/lib && \
    ln -s /usr/local/lib/libneo-f3kdb.so /usr/local/lib/vapoursynth/libneo-f3kdb.so

# AmusementClub's plugins
# assrender
RUN git clone https://github.com/AmusementClub/assrender --depth 1 && cd assrender && \
    mkdir build && cd build && cmake .. && make -j$(nproc) && make install

# vs-boxblur
RUN git clone https://github.com/AmusementClub/vs-boxblur --depth 1 --recurse-submodules && cd vs-boxblur && \
    cmake -S . -B build -G Ninja \
    -D VS_INCLUDE_DIR="/usr/local/include/vapoursynth" \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_CXX_FLAGS_RELEASE="-Wall -ffast-math -march=x86-64-v3" && \
    cmake --build build --verbose && \
    cmake --install build --prefix /usr/local

# Irrational-Encoding-Wizardry's plugins
# RemapFrames
RUN git clone https://github.com/Irrational-Encoding-Wizardry/Vapoursynth-RemapFrames --depth 1 && cd Vapoursynth-RemapFrames && \
    mkdir build && cd build && meson ../ && ninja && ninja install
RUN ln -s /usr/local/lib/x86_64-linux-gnu/vapoursynth/libremapframes.so /usr/local/lib/vapoursynth/libremapframes.so

# AkarinVS's plugins
# libakarin, depends on llvm ver >= 10.0 && < 16
RUN git clone https://github.com/AkarinVS/vapoursynth-plugin --depth 1 && cd vapoursynth-plugin && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# dubhater's plugins
# mvtools
RUN git clone https://github.com/dubhater/vapoursynth-mvtools --depth 1 && cd vapoursynth-mvtools && \
    mkdir build && cd build && meson ../ && ninja && ninja install
RUN ln -s /usr/local/lib/x86_64-linux-gnu/libmvtools.so /usr/local/lib/vapoursynth/libmvtools.so

# fillborders
RUN git clone https://github.com/dubhater/vapoursynth-fillborders --depth 1 && cd vapoursynth-fillborders && \
    mkdir build && cd build && meson ../ && ninja && ninja install
RUN ln -s /usr/local/lib/x86_64-linux-gnu/libfillborders.so /usr/local/lib/vapoursynth/libfillborders.so

# flux
RUN git clone https://github.com/dubhater/vapoursynth-fluxsmooth --depth 1 && cd vapoursynth-fluxsmooth && \
    ./autogen.sh && CFLAGS=-fPIC ./configure && make -j$(nproc) && make install
RUN ln -s /usr/local/lib/libfluxsmooth.so /usr/local/lib/vapoursynth/libfluxsmooth.so

# nnedi3
RUN git clone https://github.com/dubhater/vapoursynth-nnedi3 --depth 1 && cd vapoursynth-nnedi3 && \
    ./autogen.sh && CFLAGS=-fPIC CXXFLAGS=-fPIC ./configure && make -j$(nproc) && make install
RUN ln -s /usr/local/lib/libnnedi3.so /usr/local/lib/vapoursynth/libnnedi3.so

# tedgemask
RUN git clone https://github.com/dubhater/vapoursynth-tedgemask --depth 1 && cd vapoursynth-tedgemask && \
    mkdir build && cd build && meson ../ && ninja && ninja install
RUN ln -s /usr/local/lib/x86_64-linux-gnu/libtedgemask.so /usr/local/lib/vapoursynth/libtedgemask.so

# sangnom
RUN git clone https://github.com/dubhater/vapoursynth-sangnom --depth 1 && cd vapoursynth-sangnom && \
    mkdir build && cd build && meson ../ && ninja && ninja install
RUN ln -s /usr/local/lib/x86_64-linux-gnu/libsangnom.so /usr/local/lib/vapoursynth/libsangnom.so

# TensoRaw's plugins
# descale
RUN git clone https://github.com/EutropicAI/vapoursynth-descale --depth 1 && cd vapoursynth-descale && \
    mkdir build && cd build && meson ../ && ninja && ninja install

# hqdn3d
RUN git clone https://github.com/EutropicAI/vapoursynth-hqdn3d --depth 1 && cd vapoursynth-hqdn3d && \
    ./autogen.sh && CXXFLAGS=-fPIC ./configure && make -j$(nproc) && make install
RUN ln -s /usr/local/lib/libhqdn3d.so /usr/local/lib/vapoursynth/libhqdn3d.so

## d2vsource
#RUN git clone https://github.com/EutropicAI/d2vsource --depth 1 && cd d2vsource && \
#    ./autogen.sh && CXXFLAGS=-fPIC ./configure && make -j$(nproc) && make install
#RUN ln -s /usr/local/lib/libd2vsource.so /usr/local/lib/vapoursynth/libd2vsource.so

# znedi3
RUN git clone https://github.com/EutropicAI/znedi3 --depth 1 --recurse-submodules && cd znedi3 && \
    mkdir build && cd build && meson ../ && ninja && ninja install
RUN ln -s /usr/local/lib/x86_64-linux-gnu/libvsznedi3.so /usr/local/lib/vapoursynth/libvsznedi3.so
RUN cp znedi3/nnedi3_weights.bin /usr/local/lib && \
    ln -s /usr/local/lib/nnedi3_weights.bin /usr/local/lib/vapoursynth/nnedi3_weights.bin

###
# Install VapourSynth CUDA plugins
###

# align with PyTorch supported architectures
# >>> torch.cuda.get_arch_list()
# ['sm_50', 'sm_60', 'sm_61', 'sm_70', 'sm_75', 'sm_80', 'sm_86', 'sm_90', 'sm_100', 'sm_120']

# AmusementClub's plugins
# dfttest2
RUN git clone https://github.com/AmusementClub/vs-dfttest2 --depth 1 --recurse-submodules && cd vs-dfttest2 && \
    cmake -S . -B build -G Ninja -LA \
    -D USE_NVRTC_STATIC=ON \
    -D VAPOURSYNTH_INCLUDE_DIRECTORY="/usr/local/include/vapoursynth" \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_CXX_FLAGS="-Wall -ffast-math -march=x86-64-v3" \
    -D CMAKE_CUDA_FLAGS="--threads 0 --use_fast_math --resource-usage -Wno-deprecated-gpu-targets" \
    -D CMAKE_CUDA_ARCHITECTURES="50;60;61;70;75;80;86;90;100;120" && \
    cmake --build build --verbose && \
    cmake --install build --verbose --prefix /usr/local

# nlm_cuda
RUN git clone https://github.com/AmusementClub/vs-nlm-cuda && cd vs-nlm-cuda && \
    cmake -S . -B build -G Ninja -LA \
    -D VAPOURSYNTH_INCLUDE_DIRECTORY="/usr/local/include/vapoursynth" \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_CXX_FLAGS="-Wall -ffast-math -march=x86-64-v3" \
    -D CMAKE_CUDA_FLAGS="--threads 0 --use_fast_math --resource-usage -Wno-deprecated-gpu-targets" \
    -D CMAKE_CUDA_ARCHITECTURES="50;60;61;70;75;80;86;90;100;120" && \
    cmake --build build --verbose && \
    cmake --install build --verbose --prefix /usr/local

# WolframRhodium's plugins
# BM3DCUDA
RUN git clone https://github.com/WolframRhodium/VapourSynth-BM3DCUDA --depth 1 && cd VapourSynth-BM3DCUDA && \
    cmake -S . -B build -G Ninja -LA \
    -D USE_NVRTC_STATIC=ON \
    -D VAPOURSYNTH_INCLUDE_DIRECTORY="/usr/local/include/vapoursynth" \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_CXX_FLAGS="-Wall -ffast-math -march=x86-64-v3" \
    -D CMAKE_CUDA_FLAGS="--threads 0 --use_fast_math --resource-usage -Wno-deprecated-gpu-targets" \
    -D CMAKE_CUDA_ARCHITECTURES="50;60;61;70;75;80;86;90;100;120" && \
    cmake --build build --verbose && \
    cmake --install build --verbose --prefix /usr/local
RUN ln -s /usr/local/lib/libbm3dcuda.so /usr/local/lib/vapoursynth/libbm3dcuda.so && \
    ln -s /usr/local/lib/libbm3dcuda_rtc.so /usr/local/lib/vapoursynth/libbm3dcuda_rtc.so && \
    ln -s /usr/local/lib/libbm3dcpu.so /usr/local/lib/vapoursynth/libbm3dcpu.so

# ILS
RUN git clone https://github.com/WolframRhodium/VapourSynth-ILS --depth 1 && cd VapourSynth-ILS && \
    cmake -S . -B build -G Ninja \
    -D VAPOURSYNTH_INCLUDE_DIRECTORY="/usr/local/include/vapoursynth" \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_CXX_FLAGS="-Wall -ffast-math -march=x86-64-v3" \
    -D CMAKE_CUDA_FLAGS="--threads 0 --use_fast_math --resource-usage -Wno-deprecated-gpu-targets" \
    -D CMAKE_CUDA_ARCHITECTURES="50;60;61;70;75;80;86;90;100;120" && \
    cmake --build build --verbose
RUN cp VapourSynth-ILS/build/libils.so /usr/local/lib && \
    ln -s /usr/local/lib/libils.so /usr/local/lib/vapoursynth/libils.so

###
# Install VapourSynth Python plugins
###

# install python packages with specific versions!!!
RUN pip install --no-cache-dir \
    numpy==1.26.4 \
    opencv-python==4.10.0.84

# install vsutil
RUN pip install --no-cache-dir vsutil==0.8.0

# install maven's func package
RUN pip install --no-cache-dir git+https://github.com/HomeOfVapourSynthEvolution/mvsfunc.git

# install PyTorch 2.8.0 with CUDA 12.8 support
# ['sm_70', 'sm_75', 'sm_80', 'sm_86', 'sm_90', 'sm_100', 'sm_120']
RUN pip install --no-cache-dir torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128

# install CuPy
RUN pip install --no-cache-dir cupy-cuda12x

# install EutropicAI's packages
RUN pip install --no-cache-dir \
    mbfunc==0.1.0 \
    ccrestoration==0.2.1 \
    ccvfi==0.0.1
