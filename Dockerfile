FROM nvidia/cuda:10.2-cudnn7-devel-ubuntu18.04
ARG bazel_bin_url="https://github.com/bazelbuild/bazel/releases/download/3.7.2/bazel-3.7.2-linux-x86_64"

WORKDIR /etc/apt/sources.list.d
RUN rm cuda.list nvidia-ml.list
WORKDIR /
RUN apt-get update && apt-get install -y --no-install-recommends wget curl git locales python3 python3-pip ca-certificates gdb apt-utils
RUN echo ${bazel_bin_url}
RUN curl -L ${bazel_bin_url} -o /usr/local/bin/bazel \
    && chmod +x /usr/local/bin/bazel \
    && bazel

RUN wget --no-check-certificate https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && dpkg -i erlang-solutions_2.0_all.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends esl-erlang && \
    apt-get install -y --no-install-recommends elixir && \
    rm erlang-solutions_2.0_all.deb

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN echo $LANG UTF-8 > /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=$LANG

RUN mix local.hex --force

RUN ln -s /usr/bin/python3 /usr/bin/python

RUN pip3 install numpy
ENV LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

# Install Livebook escript

RUN mix local.rebar --force && \
    mix escript.install --force hex livebook && \
    echo 'PATH="${PATH}:/root/.mix/escripts"' >> ~/.bashrc

# Add env vars to enable CUDA support in EXLA
ENV EXLA_FLAGS=--config=cuda

# Copy our DLE env mix project to the container
COPY dle_env /dle_env
WORKDIR /dle_env

# Build out our Mix project
RUN mix deps.get && \
    mix compile
