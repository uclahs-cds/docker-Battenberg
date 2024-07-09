###############################################################################
# A pure R Battenberg v2.2.9 WGS pipeline implementation.
###############################################################################
library(Battenberg);
library(optparse);

option_list = list(
  make_option(c("-t", "--tumourname"), type="character", default=NULL, help="Samplename of the tumour", metavar="character"),
  make_option(c("-n", "--normalname"), type="character", default=NULL, help="Samplename of the normal", metavar="character"),
  make_option(c("--tb"), type="character", default=NULL, help="Tumour BAM file", metavar="character"),
  make_option(c("--nb"), type="character", default=NULL, help="Normal BAM file", metavar="character"),
  make_option(c("--sex"), type="character", default=NULL, help="Sex of the sample", metavar="character"),
  make_option(c("-o", "--output"), type="character", default=NULL, help="Directory where output will be written", metavar="character"),
  make_option(c("--skip_allelecount"), type="logical", default=FALSE, action="store_true", help="Provide when alleles don't have to be counted. This expects allelecount files on disk", metavar="character"),
  make_option(c("--skip_preprocessing"), type="logical", default=FALSE, action="store_true", help="Provide when pre-processing has previously completed. This expects the files on disk", metavar="character"),
  make_option(c("--skip_phasing"), type="logical", default=FALSE, action="store_true", help="Provide when phasing has previously completed. This expects the files on disk", metavar="character"),
  make_option(c("--cpu"), type="numeric", default=8, help="The number of CPU cores to be used by the pipeline (Default: 8)", metavar="character"),
  make_option(c("--bp"), type="character", default=NULL, help="Optional two column file (chromosome and position) specifying prior breakpoints to be used during segmentation", metavar="character"),
  make_option(c("--min_ploidy"), type="double", default=1.6, help="The minimum ploidy to consider", metavar="character"),
  make_option(c("--max_ploidy"), type="double", default=4.8, help="The maximum ploidy to consider", metavar="character"),
  make_option(c("--min_rho"), type="double", default=0.1, help="The minimum cellularity to consider", metavar="character"),
  make_option(c("--max_rho"), type="double", default=1.0, help="The maximum cellularity to consider", metavar="character")
  );

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

TUMOURNAME = opt$tumourname;
NORMALNAME = opt$normalname;
NORMALBAM = opt$nb;
TUMOURBAM = opt$tb;
IS.MALE = opt$sex=="male" | opt$sex=="Male";
RUN_DIR = opt$output;
SKIP_ALLELECOUNTING = opt$skip_allelecount;
SKIP_PREPROCESSING = opt$skip_preprocessing;
SKIP_PHASING = opt$skip_phasing;
NTHREADS = opt$cpu;
PRIOR_BREAKPOINTS_FILE = opt$bp;
MIN_PLOIDY = opt$min_ploidy;
MAX_PLOIDY = opt$max_ploidy;
MIN_RHO = opt$min_rho;
MAX_RHO = opt$max_rho;

# General static
IMPUTEINFOFILE = "/opt/battenberg_reference/impute_info.txt";
G1000PREFIX = "/opt/battenberg_reference/1000_genomes_loci/1000_genomes_allele_index_chr";
G1000PREFIX_AC = "/opt/battenberg_reference/1000_genomes_loci/1000_genomes_loci_chr";
GCCORRECTPREFIX = "/opt/battenberg_reference/1000_genomes_gcContent/1000_genomes_GC_corr_chr";
REPLICCORRECTPREFIX = "/opt/battenberg_reference/battenberg_wgs_replication_timing_correction_1000_genomes/1000_genomes_replication_timing_chr";
IMPUTE_EXE = "impute2";

PLATFORM_GAMMA = 1;
PHASING_GAMMA = 1;
SEGMENTATION_GAMMA = 10;
SEGMENTATIIN_KMIN = 3;
PHASING_KMIN = 1;
CLONALITY_DIST_METRIC = 0;
ASCAT_DIST_METRIC = 1;
MIN_GOODNESS_OF_FIT = 0.63;
BALANCED_THRESHOLD = 0.51;
MIN_NORMAL_DEPTH = 10;
MIN_BASE_QUAL = 20;
MIN_MAP_QUAL = 35;
CALC_SEG_BAF_OPTION = 3;

# WGS specific static
ALLELECOUNTER = "alleleCounter";
PROBLEMLOCI = "/opt/battenberg_reference/battenberg_problem_loci/probloci.txt.gz";

# Change to work directory and load the chromosome information
setwd(RUN_DIR);

battenberg(
    tumourname=TUMOURNAME,
    normalname=NORMALNAME,
    tumour_data_file=TUMOURBAM,
    normal_data_file=NORMALBAM,
    ismale=IS.MALE,
    imputeinfofile=IMPUTEINFOFILE,
    g1000prefix=G1000PREFIX,
    g1000allelesprefix=G1000PREFIX_AC,
    gccorrectprefix=GCCORRECTPREFIX,
    repliccorrectprefix=REPLICCORRECTPREFIX,
    problemloci=PROBLEMLOCI,
    data_type="wgs",
    impute_exe=IMPUTE_EXE,
    allelecounter_exe=ALLELECOUNTER,
    nthreads=NTHREADS,
    platform_gamma=PLATFORM_GAMMA,
    phasing_gamma=PHASING_GAMMA,
    segmentation_gamma=SEGMENTATION_GAMMA,
    segmentation_kmin=SEGMENTATIIN_KMIN,
    phasing_kmin=PHASING_KMIN,
    clonality_dist_metric=CLONALITY_DIST_METRIC,
    ascat_dist_metric=ASCAT_DIST_METRIC,
    min_ploidy=MIN_PLOIDY,
    max_ploidy=MAX_PLOIDY,
    min_rho=MIN_RHO,
    min_goodness=MIN_GOODNESS_OF_FIT,
    uninformative_BAF_threshold=BALANCED_THRESHOLD,
    min_normal_depth=MIN_NORMAL_DEPTH,
    min_base_qual=MIN_BASE_QUAL,
    min_map_qual=MIN_MAP_QUAL,
    calc_seg_baf_option=CALC_SEG_BAF_OPTION,
    skip_allele_counting=SKIP_ALLELECOUNTING,
    skip_preprocessing=SKIP_PREPROCESSING,
    skip_phasing=SKIP_PHASING,
    prior_breakpoints_file=PRIOR_BREAKPOINTS_FILE
    );
