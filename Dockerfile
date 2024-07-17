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

# Deploy the target tools into a base image
FROM ubuntu:20.04
COPY --from=builder /usr/local /usr/local

FROM r-base:latest

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends libxml2 libxml2-dev libcurl4-gnutls-dev build-essential \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev r-cran-rgl git libssl-dev r-cran-curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN R -q -e 'install.packages("BiocManager")' && \
    R -q -e 'BiocManager::install(c("curl","cpp11","lifecycle","readr","ellipsis","vctrs",\
        "GenomicRanges","IRanges","gtools", "optparse", "RColorBrewer","ggplot2",\
        "gridExtra","doParallel","foreach", "splines", "VariantAnnotation", "copynumber"))'

# Install devtools, ASCAT & Battenberg
COPY installer.R /usr/local/bin/installer.R
RUN R -q -e 'install.packages(c("argparse", "pkgdepends"), lib = "/usr/lib/R/site-library")' && \
    chmod +x /usr/local/bin/installer.R
#RUN Rscript /usr/local/bin/installer.R -r "Crick-CancerGenomics/ascat/ASCAT" -av "3.1.2"
#RUN Rscript /usr/local/bin/installer.R -r "Wedge-Oxford/battenberg" -av "2.2.9"

# Modify paths to reference files
#COPY modify_reference_path.sh /usr/local/bin/modify_reference_path.sh
#RUN chmod +x /usr/local/bin/modify_reference_path.sh && \
#    bash /usr/local/bin/modify_reference_path.sh /usr/local/lib/R/site-library/Battenberg/example/battenberg_wgs.R /usr/local/bin/battenberg_wgs.R

#RUN ln -sf /usr/local/lib/R/site-library/Battenberg/example/filter_sv_brass.R /usr/local/bin/filter_sv_brass.R && \
#    ln -sf /usr/local/lib/R/site-library/Battenberg/example/battenberg_cleanup.sh /usr/local/bin/battenberg_cleanup.sh

# Add a new user/group called bldocker
RUN groupadd -g 500001 bldocker && \
    useradd -r -u 500001 -g bldocker bldocker

# Change the default user to bldocker from root
USER bldocker

LABEL maintainer="Mohammed Faizal Eeman Mootor <MMootor@mednet.ucla.edu>" \
      org.opencontainers.image.source=https://github.com/uclahs-cds/docker-Battenberg

CMD ["/bin/bash"]
