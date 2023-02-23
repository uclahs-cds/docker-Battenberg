FROM ghcr.io/uclahs-cds/bl-base:1.1.0 AS builder

# Use mamba to install tools and dependencies into /usr/local
#ARG TOOL_VERSION=X.X.X
#RUN mamba create -qy -p /usr/local \
#    -c bioconda \
#    -c conda-forge \
#    tool_name==${TOOL_VERSION}

FROM ubuntu:20.04
COPY --from=builder /usr/local /usr/local

#
CMD ["bash"]

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y libxml2 libxml2-dev libcurl4-gnutls-dev r-cran-rgl git libssl-dev curl

RUN mkdir /tmp/downloads

RUN curl -sSL -o tmp.tar.gz --retry 10 https://github.com/samtools/htslib/archive/1.7.tar.gz && \
    mkdir /tmp/downloads/htslib && \
    tar -C /tmp/downloads/htslib --strip-components 1 -zxf tmp.tar.gz && \
    make -C /tmp/downloads/htslib && \
    rm -f /tmp/downloads/tmp.tar.gz

ENV HTSLIB /tmp/downloads/htslib

RUN curl -sSL -o tmp.tar.gz --retry 10 https://github.com/cancerit/alleleCount/archive/v4.0.0.tar.gz && \
    mkdir /tmp/downloads/alleleCount && \
    tar -C /tmp/downloads/alleleCount --strip-components 1 -zxf tmp.tar.gz && \
    cd /tmp/downloads/alleleCount/c && \
    mkdir bin && \
    make && \
    cp /tmp/downloads/alleleCount/c/bin/alleleCounter /usr/local/bin/. && \
    cd /tmp/downloads && \
    rm -rf /tmp/downloads/alleleCount /tmp/downloads/tmp.tar.gz

RUN curl -sSL -o tmp.tar.gz --retry 10 https://mathgen.stats.ox.ac.uk/impute/impute_v2.3.2_x86_64_static.tgz && \
    mkdir /tmp/downloads/impute2 && \
    tar -C /tmp/downloads/impute2 --strip-components 1 -zxf tmp.tar.gz && \
    cp /tmp/downloads/impute2/impute2 /usr/local/bin && \
    rm -rf /tmp/downloads/impute2 /tmp/downloads/tmp.tar.gz

RUN R -q -e 'install.packages("BiocManager"); BiocManager::install(c("cpp11","lifecycle","readr","ellipsis","vctrs","GenomicRanges","IRanges","gtools", "optparse", "RColorBrewer","ggplot2","gridExtra","doParallel","foreach", "splines")); install.packages("https://cloud.r-project.org/src/contrib/devtools_2.4.5.tar.gz",repos=NULL,type="source")'

RUN R -q -e 'devtools::install_github("Crick-CancerGenomics/ascat/ASCAT")'

RUN R -q -e 'BiocManager::install(c("VariantAnnotation","copynumber"))'
RUN R -q -e 'devtools::install_github("Wedge-Oxford/battenberg@v2.2.9")'

# modify paths to reference files
RUN cat /usr/local/lib/R/site-library/Battenberg/example/battenberg_wgs.R | \
    sed 's|IMPUTEINFOFILE = \".*|IMPUTEINFOFILE = \"/opt/battenberg_reference/1000genomes_2012_v3_impute/impute_info.txt\"|' | \
    sed 's|G1000PREFIX = \".*|G1000PREFIX = \"/opt/battenberg_reference/1000genomes_2012_v3_loci/1000genomesAlleles2012_chr\"|' | \
    sed 's|G1000PREFIX_AC = \".*|G1000PREFIX_AC = \"/opt/battenberg_reference/1000genomes_2012_v3_loci/1000genomesloci2012_chr\"|' | \
    sed 's|GCCORRECTPREFIX = \".*|GCCORRECTPREFIX = \"/opt/battenberg_reference/1000genomes_2012_v3_gcContent/1000_genomes_GC_corr_chr_\"|' | \
    sed 's|PROBLEMLOCI = \".*|PROBLEMLOCI = \"/opt/battenberg_reference/battenberg_problem_loci/probloci_270415.txt.gz\"|' | \
    sed 's|REPLICCORRECTPREFIX = \".*|REPLICCORRECTPREFIX = \"/opt/battenberg_reference/battenberg_wgs_replic_correction_1000g_v3/1000_genomes_replication_timing_chr_\"|' > /usr/local/bin/battenberg_wgs.R

RUN grep "IMPUTEINFOFILE" /usr/local/bin/battenberg_wgs.R; grep "PROBLEMLOCI" /usr/local/bin/battenberg_wgs.R
RUN cp /usr/local/lib/R/site-library/Battenberg/example/filter_sv_brass.R /usr/local/bin/filter_sv_brass.R
RUN cp /usr/local/lib/R/site-library/Battenberg/example/battenberg_cleanup.sh /usr/local/bin/battenberg_cleanup.sh
RUN ls -alth /usr/local/bin/*

# Deploy the target tools into a base image

# Add a new user/group called bldocker
RUN groupadd -g 500001 bldocker && \
    useradd -r -u 500001 -g bldocker bldocker

# Change the default user to bldocker from root
USER bldocker
WORKDIR /home/ubuntu

LABEL   maintainer="Mohammed Faizal Eeman Mootor <MMootor@mednet.ucla.edu>" \
        org.opencontainers.image.source=https://github.com/uclahs-cds/<REPO>

CMD ["/bin/bash"]
