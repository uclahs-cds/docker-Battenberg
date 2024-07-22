FROM ubuntu:20.04
FROM r-base:4.4.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libcurl4-openssl-dev \
        libbz2-dev \
        liblzma-dev \
        libpng-dev \
        libssl-dev \
        libxml2-dev \
        python3

# Main tool version
ARG BATTENBERG_VERSION=2.2.9

# Dependency version or commit ID
ARG ASCAT_VERSION=3.1.3
ARG COPYNUMBER_VERSION="b404a4d"

# GitHub repo link
ARG ASCAT="VanLoo-lab/ascat/ASCAT@v${ASCAT_VERSION}"
ARG COPYNUMBER="igordot/copynumber@${COPYNUMBER_VERSION}"
ARG BATTENBERG="Wedge-lab/battenberg@v${BATTENBERG_VERSION}"

# R library path to install the above packages
ARG LIBRARY="/usr/lib/R/site-library"

# Install Package Dependency toolkit
RUN library=${LIBRARY} R -e 'install.packages(c("argparse", "pkgdepends"), lib = Sys.getenv("library"))'

# Install Battenberg
COPY installer.R /usr/local/bin/installer.R

RUN chmod +x /usr/local/bin/installer.R

RUN Rscript /usr/local/bin/installer.R -l ${LIBRARY} -d ${COPYNUMBER} ${ASCAT} ${BATTENBERG}

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
