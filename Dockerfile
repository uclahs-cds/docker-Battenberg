ARG MINIFORGE_VERSION=23.1.0-1

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

FROM rocker/r-ver:4.4.1
COPY --from=builder /usr/local /usr/local

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libcurl4-openssl-dev \
        libbz2-dev \
        liblzma-dev \
        libpng-dev \
        libssl-dev \
        libxml2-dev \
        python3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Main tool version
ARG BATTENBERG_VERSION="2.2.9"

# Dependency version or commit ID
ARG ASCAT_VERSION=3.1.3
ARG COPYNUMBER_VERSION="b404a4d"

# GitHub repo link
ARG ASCAT="VanLoo-lab/ascat/ASCAT@v${ASCAT_VERSION}"
ARG COPYNUMBER="igordot/copynumber@${COPYNUMBER_VERSION}"
ARG BATTENBERG="Wedge-lab/battenberg@v${BATTENBERG_VERSION}"

# Install Package Dependency toolkit
RUN R -e 'install.packages(c("argparse", "BiocManager", "pkgdepends", "optparse"))' && \
    R -q -e 'BiocManager::install(c("ellipsis", "splines", "VariantAnnotation"))'

# Install Battenberg
COPY installer.R /usr/local/bin/installer.R
RUN chmod +x /usr/local/bin/installer.R

RUN Rscript /usr/local/bin/installer.R -d ${COPYNUMBER} ${ASCAT} ${BATTENBERG}

# Modify paths to reference files
COPY modify_reference_path.sh /usr/local/bin/modify_reference_path.sh
RUN chmod +x /usr/local/bin/modify_reference_path.sh && \
    bash /usr/local/bin/modify_reference_path.sh /usr/local/lib/R/site-library/Battenberg/example/battenberg_wgs.R /usr/local/bin/battenberg_wgs.R

RUN ln -sf /usr/local/lib/R/site-library/Battenberg/example/filter_sv_brass.R /usr/local/bin/filter_sv_brass.R && \
    ln -sf /usr/local/lib/R/site-library/Battenberg/example/battenberg_cleanup.sh /usr/local/bin/battenberg_cleanup.sh

# Add a new user/group called bldocker
RUN groupadd -g 500001 bldocker && \
    useradd -r -u 500001 -g bldocker bldocker

# Change the default user to bldocker from root
USER bldocker

LABEL maintainer="Mohammed Faizal Eeman Mootor <MMootor@mednet.ucla.edu>" \
      org.opencontainers.image.source=https://github.com/uclahs-cds/docker-Battenberg

CMD ["/bin/bash"]
