ARG MINIFORGE_VERSION=23.1.0-1
ARG ASCAT_VERSION=3.1.2
ARG BATTENBERG_VERSION=2.2.9

FROM condaforge/mambaforge:${MINIFORGE_VERSION} AS builder

# Use mamba to install tools and dependencies into /usr/local
ARG HTSLIB_VERSION=1.16
ARG ALLELECOUNT_VERSION=4.3.0
ARG IMPUTE2_VERSION=2.3.2
RUN mamba create -qy -p /usr/local \
    -c bioconda \
    -c conda-forge \
    htslib==${HTSLIB_VERSION} \
    cancerit-allelecount==${ALLELECOUNT_VERSION} \
    impute2==${IMPUTE2_VERSION}

# Deploy the target tools into a base image
FROM ubuntu:20.04
COPY --from=builder /usr/local /usr/local

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libxml2 \
    libxml2-dev \
    libcurl4-gnutls-dev \
    build-essential \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    r-cran-rgl \
    git \
    libssl-dev \
    r-cran-curl \
    r-cran-devtools \
    wget && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN R -q -e 'install.packages("renv")' && \
    mkdir -p /usr/local/src

COPY renv.lock /usr/local/renv.lock
COPY battenberg_bl_custom.R /usr/local/src/
COPY battenberg_wgs_bl_custom.R /usr/local/src/

ARG ASCAT_VERSION
ARG BATTENBERG_VERSION

RUN set -eux && \
    # Ignore specific packages from `renv.lock` file
    R -q -e 'renv::settings$ignored.packages(c("ASCAT", "Battenberg"))' && \
    R -q -e 'renv::restore(lockfile = "/usr/local/renv.lock")' && \
    # Install ASCAT
    cd /usr/local/src/ && \
    wget -q -O ascat-${ASCAT_VERSION}.tar.gz \
        https://github.com/VanLoo-lab/ascat/archive/refs/tags/v${ASCAT_VERSION}.tar.gz && \
    tar -xzf ascat-${ASCAT_VERSION}.tar.gz && \
    R CMD INSTALL ascat-${ASCAT_VERSION}/ASCAT/ && \
    # Instal Battenberg
    wget -q -O battenberg-${BATTENBERG_VERSION}.tar.gz \
        https://github.com/Wedge-lab/battenberg/archive/refs/tags/v${BATTENBERG_VERSION}.tar.gz && \
    tar -xzf battenberg-${BATTENBERG_VERSION}.tar.gz && \
    cp battenberg_bl_custom.R battenberg-${BATTENBERG_VERSION}/R/battenberg.R && \
    cp battenberg_wgs_bl_custom.R battenberg-${BATTENBERG_VERSION}/inst/example/battenberg_wgs.R && \
    R CMD INSTALL battenberg-${BATTENBERG_VERSION}/ && \
    # Cleanup
    cd /usr/local/ && \
    rm -rf /usr/local/src/*

# Add a new user/group called bldocker
RUN groupadd -g 500001 bldocker && \
    useradd -r -u 500001 -g bldocker bldocker

# Change the default user to bldocker from root
USER bldocker

LABEL maintainer="Mohammed Faizal Eeman Mootor <MMootor@mednet.ucla.edu>" \
      org.opencontainers.image.source=https://github.com/uclahs-cds/docker-Battenberg

CMD ["/bin/bash"]
