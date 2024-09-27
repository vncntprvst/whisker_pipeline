Checking what's in `deeplabcut/deeplabcut:latest-core`.

```bash
$ singularity inspect /om2/group/wanglab/images/deeplabcut_latest-core.sif 
com.nvidia.cudnn.version: 8.2.2.26
maintainer: NVIDIA CORPORATION <cudatools@nvidia.com>
org.label-schema.build-arch: amd64
org.label-schema.build-date: Tuesday_20_August_2024_18:17:54_EDT
org.label-schema.schema-version: 1.0
org.label-schema.usage.apptainer.version: 1.1.7
org.label-schema.usage.singularity.deffile.bootstrap: docker
org.label-schema.usage.singularity.deffile.from: deeplabcut/deeplabcut:latest-core
```

```bash
$ singularity shell /om2/group/wanglab/images/deeplabcut_latest-core.sif 
```
```bash
Apptainer> /usr/bin/python3 --version
Python 3.8.10

Apptainer> /usr/bin/python3 -c "import deeplabcut; print(deeplabcut.__version__)"
2024-09-26 22:39:39.316939: I tensorflow/stream_executor/platform/default/dso_loader.cc:53] Successfully opened dynamic library libcudart.so.11.0
DLC loaded in light mode; you cannot use any GUI (labeling, relabeling and standalone GUI)
Matplotlib created a temporary config/cache directory at /tmp/matplotlib-eiduhnb8 because the default path (/home/prevosto/.cache/matplotlib) is not a writable directory; it is highly recommended to set the MPLCONFIGDIR environment variable to a writable directory, in particular to speed up the import of Matplotlib and to better support multiprocessing.
2.2.0.2

Apptainer> env | grep -i cuda
NVIDIA_REQUIRE_CUDA=cuda>=11.4 brand=tesla,driver>=418,driver<419 brand=tesla,driver>=440,driver<441 driver>=450
NV_CUDNN_PACKAGE=libcudnn8=8.2.2.26-1+cuda11.4
NV_CUDA_CUDART_VERSION=11.4.43-1
CUDA_VERSION=11.4.0
NV_CUDA_LIB_VERSION=11.4.0-1
NV_CUDA_COMPAT_PACKAGE=cuda-compat-11-4
NV_LIBNCCL_PACKAGE=libnccl2=2.10.3-1+cuda11.4
PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

Apptainer> echo $PATH
/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

```

So, we have: 
CUDA_VERSION=11.4.0
NV_CUDA_CUDART_VERSION=11.4.43-1
NV_CUDA_LIB_VERSION=11.4.0-1

and DeepLabCut 2.2.0.2
