FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    libssl-dev \
    pkg-config \
    autoconf \
    automake \
    libtool \
    libspeexdsp-dev \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Clone and build AWS SDK 1.11.200
RUN git clone --depth 1 --branch 1.11.200 https://github.com/aws/aws-sdk-cpp.git && \
    cd aws-sdk-cpp && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_ONLY="transcribestreaming" \
        -DENABLE_TESTING=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# Copy module source
COPY modules/mod_aws_transcribe /build/mod_aws_transcribe

WORKDIR /build/mod_aws_transcribe

# Build module using standalone compilation
RUN g++ -c -std=c++11 -fPIC \
    -I/usr/local/include \
    -I. \
    aws_transcribe_glue.cpp -o aws_transcribe_glue.o && \
    echo "C++ compilation successful"

CMD ["/bin/bash"]
