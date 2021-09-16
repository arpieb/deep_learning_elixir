FROM nvidia/cuda:10.2-cudnn7-devel-ubuntu18.04
ARG bazel_bin_url="https://github.com/bazelbuild/bazel/releases/download/3.7.2/bazel-3.7.2-linux-x86_64"

# Disable Nvidia updates
WORKDIR /etc/apt/sources.list.d
RUN rm cuda.list nvidia-ml.list

# Configure locales
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install standard packages
WORKDIR /
RUN apt-get update && apt-get install -y --no-install-recommends wget curl git python3 python3-pip locales ca-certificates gdb apt-utils build-essential

# Update locales
RUN echo $LANG UTF-8 > /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=$LANG

# Configure python3
RUN ln -s /usr/bin/python3 /usr/bin/python
RUN pip3 install numpy
ENV LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

# Set up bazel
#RUN echo ${bazel_bin_url}
#RUN curl -L ${bazel_bin_url} -o /usr/local/bin/bazel \
#    && chmod +x /usr/local/bin/bazel \
#    && bazel

# Install Erlang + Elixir
RUN wget --no-check-certificate https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && dpkg -i erlang-solutions_2.0_all.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends esl-erlang && \
    apt-get install -y --no-install-recommends elixir && \
    rm erlang-solutions_2.0_all.deb
RUN mix local.hex --force

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y && \
    echo 'source $HOME/.cargo/env' >> $HOME/.bashrc

# Add env vars to enable CUDA support in EXLA
ENV XLA_TARGET=cuda102

# Install Livebook escript
RUN mix local.rebar --force && \
    mix escript.install --force hex livebook && \
    echo 'PATH="${PATH}:/root/.mix/escripts"' >> ~/.bashrc

