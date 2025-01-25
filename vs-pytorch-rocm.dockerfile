ARG BASE_CONTAINER_TAG=latest

FROM lychee0/vs-ffmpeg-docker:${BASE_CONTAINER_TAG}

###
# Set the working directory for ROCm
###
WORKDIR /amd

###
# set up ROCm environment (ROCm 6.1.3)
###

# Install necessary dependencies
RUN apt install -y \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && add-apt-repository universe \
    && apt update

RUN wget http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.2-0ubuntu2.1_amd64.deb
RUN apt install -y ./libtinfo5_6.2-0ubuntu2.1_amd64.deb && rm -f ./libtinfo5_6.2-0ubuntu2.1_amd64.deb

RUN wget https://mirrors.edge.kernel.org/ubuntu/pool/main/s/suitesparse/libsuitesparseconfig5_5.10.1+dfsg-4build1_amd64.deb
RUN apt install -y ./libsuitesparseconfig5_5.10.1+dfsg-4build1_amd64.deb && rm -f ./libsuitesparseconfig5_5.10.1+dfsg-4build1_amd64.deb

RUN wget https://mirrors.edge.kernel.org/ubuntu/pool/universe/s/suitesparse/libccolamd2_5.10.1+dfsg-4build1_amd64.deb
RUN apt install -y ./libccolamd2_5.10.1+dfsg-4build1_amd64.deb && rm -f ./libccolamd2_5.10.1+dfsg-4build1_amd64.deb

RUN wget https://mirrors.edge.kernel.org/ubuntu/pool/main/s/suitesparse/libcamd2_5.7.1+dfsg-2_amd64.deb
RUN apt install -y ./libcamd2_5.7.1+dfsg-2_amd64.deb && rm -f ./libcamd2_5.7.1+dfsg-2_amd64.deb

RUN wget https://mirrors.edge.kernel.org/ubuntu/pool/main/s/suitesparse/libcolamd2_5.7.1+dfsg-2_amd64.deb
RUN apt install -y ./libcolamd2_5.7.1+dfsg-2_amd64.deb && rm -f ./libcolamd2_5.7.1+dfsg-2_amd64.deb

RUN wget https://mirrors.edge.kernel.org/ubuntu/pool/main/s/suitesparse/libamd2_5.7.1+dfsg-2_amd64.deb
RUN apt install -y ./libamd2_5.7.1+dfsg-2_amd64.deb && rm -f ./libamd2_5.7.1+dfsg-2_amd64.deb

RUN wget https://mirrors.edge.kernel.org/ubuntu/pool/main/s/suitesparse/libcholmod3_5.7.1+dfsg-2_amd64.deb
RUN apt install -y ./libcholmod3_5.7.1+dfsg-2_amd64.deb && rm -f ./libcholmod3_5.7.1+dfsg-2_amd64.deb

RUN wget http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.2-0ubuntu2.1_amd64.deb
RUN apt install -y ./libncurses5_6.2-0ubuntu2.1_amd64.deb && rm -f ./libncurses5_6.2-0ubuntu2.1_amd64.deb

RUN wget https://mirrors.edge.kernel.org/ubuntu/pool/main/m/mime-support/mime-support_3.66_all.deb
RUN apt install -y ./mime-support_3.66_all.deb && rm -f ./mime-support_3.66_all.deb

RUN wget https://mirrors.edge.kernel.org/ubuntu/pool/universe/libf/libffi7/libffi7_3.3-5ubuntu1_amd64.deb
RUN apt install -y ./libffi7_3.3-5ubuntu1_amd64.deb && rm -f ./libffi7_3.3-5ubuntu1_amd64.deb

RUN wget https://mirrors.edge.kernel.org/ubuntu/pool/main/m/mpdecimal/libmpdec2_2.4.2-3_amd64.deb
RUN apt install -y ./libmpdec2_2.4.2-3_amd64.deb && rm -f ./libmpdec2_2.4.2-3_amd64.deb

# Download the AMD GPU installer package
RUN wget https://repo.radeon.com/amdgpu-install/6.1.3/ubuntu/jammy/amdgpu-install_6.1.60103-1_all.deb

RUN apt install -y ./amdgpu-install_6.1.60103-1_all.deb && rm -f ./amdgpu-install_6.1.60103-1_all.deb

RUN amdgpu-install -y --usecase=wsl,rocm --no-dkms

###
# Set the working directory for VapourSynth
###
WORKDIR /workspace

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
    libfftw3-dev

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
    mkdir build && cd build && meson -D opencl=false ../ && ninja && ninja install

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

###
# Install VapourSynth ROCm plugins
###

# TODO: Support ROCm, temporarily use the CPU version

# AmusementClub's plugins
# dfttest2
RUN git clone https://github.com/AmusementClub/vs-dfttest2 --depth 1 --recurse-submodules && cd vs-dfttest2 && \
    cmake -S . -B build -G Ninja -LA \
    -D ENABLE_CPU=ON \
    -D ENABLE_CUDA=OFF \
    -D ENABLE_HIP=OFF \
    -D VAPOURSYNTH_INCLUDE_DIRECTORY="/usr/local/include/vapoursynth" \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_CXX_FLAGS="-Wall -ffast-math -march=x86-64-v3" && \
    cmake --build build --verbose && \
    cmake --install build --verbose --prefix /usr/local

# WolframRhodium's plugins
# BM3DCUDA
RUN git clone https://github.com/WolframRhodium/VapourSynth-BM3DCUDA --depth 1 && cd VapourSynth-BM3DCUDA && \
    cmake -S . -B build -G Ninja -LA \
    -D ENABLE_CPU=ON \
    -D ENABLE_CUDA=OFF \
    -D ENABLE_HIP=OFF \
    -D VAPOURSYNTH_INCLUDE_DIRECTORY="/usr/local/include/vapoursynth" \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_CXX_FLAGS="-Wall -ffast-math -march=x86-64-v3" && \
    cmake --build build --verbose && \
    cmake --install build --verbose --prefix /usr/local
RUN ln -s /usr/local/lib/libbm3dcpu.so /usr/local/lib/vapoursynth/libbm3dcpu.so

###
# Install VapourSynth Python plugins
###

# install python packages with specific versions!!!
RUN pip install numpy==1.26.4
RUN pip install opencv-python-headless==4.10.0.82

# install other vs plugins
RUN pip install git+https://github.com/HomeOfVapourSynthEvolution/mvsfunc.git
RUN pip install vsutil==0.8.0
RUN pip install git+https://github.com/HomeOfVapourSynthEvolution/havsfunc.git

# install PyTorch
RUN wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.1.3/torch-2.1.2%2Brocm6.1.3-cp310-cp310-linux_x86_64.whl
RUN wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.1.3/torchvision-0.16.1%2Brocm6.1.3-cp310-cp310-linux_x86_64.whl
RUN wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.1.3/pytorch_triton_rocm-2.1.0%2Brocm6.1.3.4d510c3a44-cp310-cp310-linux_x86_64.whl
RUN pip install torch-2.1.2+rocm6.1.3-cp310-cp310-linux_x86_64.whl torchvision-0.16.1+rocm6.1.3-cp310-cp310-linux_x86_64.whl pytorch_triton_rocm-2.1.0+rocm6.1.3.4d510c3a44-cp310-cp310-linux_x86_64.whl
#RUN pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/rocm6.1

# Locate the torch library directory, HACK
RUN location=$(pip show torch | grep Location | awk -F ": " '{print $2}') && \
    cd ${location}/torch/lib/ && \
    rm -f libhsa-runtime64.so* && \
    cp /opt/rocm/lib/libhsa-runtime64.so.1.2 libhsa-runtime64.so

# install TensoRaws's packages
RUN pip install mbfunc==0.0.2
RUN pip install ccrestoration==0.2.1
RUN pip install ccvfi==0.0.1
