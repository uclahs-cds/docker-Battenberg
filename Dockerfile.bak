FROM rocker/r-base:4.0.2

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev
RUN install2.r BiocManager
RUN installBioc.r XML httr openssl BiocFileCache Rsamtools GenomicFeatures Rhtslib GenomicRanges SummarizedExperiment rtracklayer BSgenome GenomeInfoDb
RUN installBioc.r devtools splines readr doParallel ggplot2 RColorBrewer gridExtra gtools parallel VariantAnnotation
RUN installGithub.r Crick-CancerGenomics/ascat/ASCAT
RUN installBioc.r VariantAnnotation
#RUN installGithub.r Wedge-lab/battenberg@dev
RUN installGithub.r Wedge-lab/battenberg@aa14170714
RUN installBioc.r optparse

RUN apt-get install -y curl default-jre

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

#COPY battenberg_wgs.R /usr/local/bin/battenberg_wgs.R

CMD ["/bin/bash"]
