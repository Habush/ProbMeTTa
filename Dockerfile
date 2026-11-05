FROM ubuntu:24.04 AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates cmake git ninja-build pkg-config \
    libarchive-dev libedit-dev libgmp-dev libossp-uuid-dev libpcre2-dev \
    libssl-dev libutf8proc-dev libyaml-dev python3-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/probmetta
COPY bootstrap.sh .
RUN bash bootstrap.sh

FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates git libarchive13t64 libedit2 libgmp10 libossp-uuid16 \
    libpcre2-8-0 libpython3.12t64 libssl3t64 libutf8proc3 libyaml-0-2 \
    python3 zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/probmetta/.deps/swipl /opt/probmetta/.deps/swipl
COPY --from=build /opt/probmetta/.deps/PeTTa /opt/probmetta/.deps/PeTTa

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PETTA_DIR=/opt/probmetta/.deps/PeTTa \
    SWIPL=/opt/probmetta/.deps/swipl/bin/swipl \
    PATH=/opt/probmetta/.deps/swipl/bin:$PATH

WORKDIR /workspace
COPY . .

ENTRYPOINT ["bash", "/workspace/run.sh"]
CMD ["lib_pclp.metta", "sample.pclp", "--silent"]