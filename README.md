# vs-playground

[![CI-test](https://github.com/EutropicAI/vs-playground/actions/workflows/CI-test.yml/badge.svg)](https://github.com/EutropicAI/vs-playground/actions/workflows/CI-test.yml)
[![CI-build](https://github.com/EutropicAI/vs-playground/actions/workflows/CI-build.yml/badge.svg)](https://github.com/EutropicAI/vs-playground/actions/workflows/CI-build.yml)
[![Release](https://github.com/EutropicAI/vs-playground/actions/workflows/Release.yml/badge.svg)](https://github.com/EutropicAI/vs-playground/actions/workflows/Release.yml)

dev with docker and jupyter notebook!

### Preparations

- docker and docker-compose
- Nvidia GPU and GPU container runtime (optional)
- make (optional)

### Start

```bash
make dev
```

open `http://localhost:1145` in your browser, default password is `114514`

template ipynb file is in [./video](./video) folder, you should put video in here

- (optional) use code completion in jupyter notebook

load yuuno plugin in jupyter notebook, then you can preview any frame

#### _run the example code in order, encode your first video!_

<img width="2634" height="1702" alt="image" src="https://github.com/user-attachments/assets/6a841172-eb0f-4b57-875a-68d37a9127fd" />

### SSH

the playground image has sshd installed, you can ssh into the container to dev

- default port: 1022 (1022:22)
- user: root
- password: 123456

### Base Environment

- system: Ubuntu 22.04
- GCC/G++: 13
- python: 3.10
- FFmpeg: 8.0
- [Static FFmpeg](https://github.com/wader/static-ffmpeg): 8.0 (/static-ffmpeg/ffmpeg)
- VapourSynth: R70
- x264: latest
- x265: 4.1
- svt-av1-psy: latest
- aom: latest
- libvpx: latest
- fdk-aac: latest
- libass: latest

### AI Environment

- CUDA toolkit: 12.9
- PyTorch: 2.8.0+cu128 ['sm_70', 'sm_75', 'sm_80', 'sm_86', 'sm_90', 'sm_100', 'sm_120']
- cupy: cuda12x

### VapourSynth Python Plugin List

```bash
mbfunc
cccv
vsutil
mvsfunc
```

### VapourSynth C++ Plugin List

```bash
bestsource.so
libaddgrain.so
libakarin.so
libassrender.so
libbilateral.so
libbm3dcpu.so
libbm3dcuda.so
libbm3dcuda_rtc.so
libboxblur.so
libbwdif.so
libcas.so
libctmf.so
#libd2vsource.so
libdctfilter.so
libdescale.so
libdfttest2_cpu.so
libdfttest2_cuda.so
libdfttest2_nvrtc.so
libeedi2.so
libeedi3m.so
libffms2.so
libfillborders.so
libfluxsmooth.so
libfmtconv.so
libhqdn3d.so
libils.so
libmiscfilters.so
libmvtools.so
libneo-dfttest.so
libneo-f3kdb.so
libneo-fft3d.so
libnnedi3.so
libremapframes.so
libremovegrain.so
libretinex.so
libsangnom.so
libtcanny.so
libtedgemask.so
libttempsmooth.so
libvsnlm_cuda.so
libvsznedi3.so
```

### Build

build [image](./vs-pytorch.dockerfile) (default for FinalRip) and [playground image](./vs-playground.dockerfile)

```bash
make pt && make pg
```

### Reference

- [static-ffmpeg](https://github.com/wader/static-ffmpeg)
- [VSGAN-tensorrt-docker](https://github.com/styler00dollar/VSGAN-tensorrt-docker)
- [VapourSynth](https://www.vapoursynth.com/)
- [yuuno](https://github.com/Irrational-Encoding-Wizardry/yuuno)

### License

This project is licensed under the GPL-3.0 license - see the [LICENSE file](./LICENSE) for details.
