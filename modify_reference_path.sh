#!/usr/bin/sh

refpath_default=$1
refpath_modified=$2

cat "${refpath_default}" | \
    sed 's|IMPUTEINFOFILE = \".*|IMPUTEINFOFILE = \"/opt/battenberg_reference/impute_info.txt\"|' | \
    sed 's|G1000PREFIX = \".*|G1000PREFIX = \"/opt/battenberg_reference/1000_genomes_loci/1000_genomes_allele_index_chr\"|' | \
    sed 's|G1000PREFIX_AC = \".*|G1000PREFIX_AC = \"/opt/battenberg_reference/1000_genomes_loci/1000_genomes_loci_chr\"|' | \
    sed 's|GCCORRECTPREFIX = \".*|GCCORRECTPREFIX = \"/opt/battenberg_reference/1000_genomes_gcContent/1000_genomes_GC_corr_chr\"|' | \
    sed 's|PROBLEMLOCI = \".*|PROBLEMLOCI = \"/opt/battenberg_reference/battenberg_problem_loci/probloci.txt.gz\"|' | \
    sed 's|REPLICCORRECTPREFIX = \".*|REPLICCORRECTPREFIX = \"/opt/battenberg_reference/battenberg_wgs_replication_timing_correction_1000_genomes/1000_genomes_replication_timing_chr\"|' > "${refpath_modified}"
