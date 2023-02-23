FROM ghcr.io/uclahs-cds/bl-base:1.1.0 AS builder

# Use mamba to install tools and dependencies into /usr/local
ARG HTSLIB_VERSION=1.16
ARG ALLELECOUNTER_VERSION=4.3.0
ARG IMPUTE2_VERSION=2.3.2
RUN mamba create -qy -p /usr/local \
    -c bioconda \
    -c conda-forge \
    htslib==${HTSLIB_VERSION} \
    cancerit-allelecount==${ALLELECOUNTER_VERSION} \
    impute2==${IMPUTE2_VERSION}

# Deploy the target tools into a base image
FROM ubuntu:20.04
COPY --from=builder /usr/local /usr/local

# Install more dependencies
CMD ["bash"]

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y libxml2 libxml2-dev libcurl4-gnutls-dev r-cran-rgl git libssl-dev curl

RUN R -q -e 'install.packages("BiocManager"); BiocManager::install(c("cpp11","lifecycle","readr","ellipsis","vctrs","GenomicRanges","IRanges","gtools", "optparse", "RColorBrewer","ggplot2","gridExtra","doParallel","foreach", "splines", "VariantAnnotation", "copynumber")); install.packages("https://cloud.r-project.org/src/contrib/devtools_2.4.5.tar.gz",repos=NULL,type="source")'

RUN R -q -e 'devtools::install_github("Crick-CancerGenomics/ascat/ASCAT")'

# Install Battenberg 2.2.9
RUN R -q -e 'devtools::install_github("Wedge-Oxford/battenberg@v2.2.9")'

# modify paths to reference files
RUN cat /usr/local/lib/R/site-library/Battenberg/example/battenberg_wgs.R | \
    sed 's|IMPUTEINFOFILE = \".*|IMPUTEINFOFILE = \"/opt/battenberg_reference/1000genomes_2012_v3_impute/impute_info.txt\"|' | \
    sed 's|G1000PREFIX = \".*|G1000PREFIX = \"/opt/battenberg_reference/1000genomes_2012_v3_loci/1000genomesAlleles2012_chr\"|' | \
    sed 's|G1000PREFIX_AC = \".*|G1000PREFIX_AC = \"/opt/battenberg_reference/1000genomes_2012_v3_loci/1000genomesloci2012_chr\"|' | \
    sed 's|GCCORRECTPREFIX = \".*|GCCORRECTPREFIX = \"/opt/battenberg_reference/1000genomes_2012_v3_gcContent/1000_genomes_GC_corr_chr_\"|' | \
    sed 's|PROBLEMLOCI = \".*|PROBLEMLOCI = \"/opt/battenberg_reference/battenberg_problem_loci/probloci_270415.txt.gz\"|' | \
    sed 's|REPLICCORRECTPREFIX = \".*|REPLICCORRECTPREFIX = \"/opt/battenberg_reference/battenberg_wgs_replic_correction_1000g_v3/1000_genomes_replication_timing_chr_\"|' > /usr/local/bin/battenberg_wgs.R

RUN cp /usr/local/lib/R/site-library/Battenberg/example/filter_sv_brass.R /usr/local/bin/filter_sv_brass.R
RUN cp /usr/local/lib/R/site-library/Battenberg/example/battenberg_cleanup.sh /usr/local/bin/battenberg_cleanup.sh

# Add a new user/group called bldocker
RUN groupadd -g 500001 bldocker && \
    useradd -r -u 500001 -g bldocker bldocker

# Change the default user to bldocker from root
USER bldocker
WORKDIR /home/ubuntu

LABEL   maintainer="Mohammed Faizal Eeman Mootor <MMootor@mednet.ucla.edu>" \
        org.opencontainers.image.source=https://github.com/uclahs-cds/<REPO>

CMD ["/bin/bash"]
