#!/usr/bin/env bash
set -e
cd /usr/lib/aarch64-linux-gnu
ln -sf libavcodec.so.58 libavcodec-e61fde82.so.58.134.100
ln -sf libavformat.so.58 libavformat-a93773b3.so.58.76.100
ln -sf libavutil.so.56 libavutil-5f9c2f63.so.56.70.100
ln -sf libswscale.so.5 libswscale-e6d9d937.so.5.9.100
ln -sf libopenblas.so.0 libopenblas-r0-8966572e.3.3.so
