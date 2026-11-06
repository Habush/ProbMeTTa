# Setup

Choose a local installion on Ubuntu/Debian or use Docker.

## Clone the Repo

```bash
git clone https://github.com/Habush/ProbMeTTa.git
cd ProbMeTTa
```

Run the commands below from `ProbMeTTa` directory.

### Using existing installations

If you already have SWI-Prolog and PeTTa installed, you can skip to [Running examples](#3-run-examples) section after setting the following environment variables:

```bash
export PETTA_DIR=/path/to/PeTTa 
```

```bash
export SWIPL=/path/to/swipl
```

## Local installation (Ubuntu/Debian)

### 1. Install dependencies

Skip this step if you already have [SWI-Prolog 9.3](https://github.com/SWI-Prolog/swipl-devel/releases/tag/V9.3.34) or later with Janus, PCRE, and CLP(R).

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    build-essential ca-certificates cmake git ninja-build pkg-config \
    libarchive-dev libedit-dev libgmp-dev libossp-uuid-dev libpcre2-dev \
    libssl-dev libutf8proc-dev libyaml-dev python3-dev zlib1g-dev
```

### 2. Run bootstrap.sh

This script installs [PeTTa](https://github.com/trueagi-io/PeTTa) from its sources and reuses a compatible SWI-Prolog installation. If none is found, it builds SWI-Prolog from source. Note that by default it installs `PeTTa` to `.deps` directory under the working directory, if you'd like to change this, pass the `--install-dir /path/to/deps` argument.

```bash
./bootstrap.sh
```

### 3. Run examples

To run a PCLP example, such as `examples/sample.pclp` 

```bash
./run.sh lib_pclp.metta sample.pclp --silent
```

The expected probability bounds are `[0.392, 0.704]`

To run the ProbLog-style examples:

```bash
./run.sh examples/prob.metta --silent
```

## Docker

Build the image:

```bash
docker build -t probmetta .
```

Run the PCLP sample:

```bash
docker run --name probmetta-sample probmetta
```

Run the ProbLog-style examples:

```bash
docker run --name probmetta-prob probmetta examples/prob.metta --silent
```

When finished, you can remove the containers you created:

```bash
docker rm probmetta-sample probmetta-prob
```