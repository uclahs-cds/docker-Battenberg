###############################################################################
# 2024-08-01
# A pure R Battenberg (dev) WGS pipeline implementation for uclahscds.
###############################################################################
library(Battenberg);
library(optparse);

option.list <- list(
    make_option(c('-a', '--analysis_type'), type = 'character', default = 'paired', help = 'Type of analysis to run: paired (tumour+normal), cell_line (only tumour), germline (only normal)', metavar = 'character'),
    make_option(c('-t', '--samplename'), type = 'character', default = NULL, help = 'Samplename of the tumour', metavar = 'character'),
    make_option(c('-n', '--normalname'), type = 'character', default = NULL, help = 'Samplename of the normal', metavar = 'character'),
    make_option(c('--tb'), type = 'character', default = NULL, help = 'Sample BAM file', metavar = 'character'),
    make_option(c('--nb'), type = 'character', default = NULL, help = 'Normal BAM file', metavar = 'character'),
    make_option(c('--beagle_jar'), type = 'character', default = NULL, help = 'Full path to beagle jar', metavar = 'character'),
    make_option(c('--beagle_ref_template'), type = 'character', default = NULL, help = 'Full path to beagle reference template', metavar = 'character'),
    make_option(c('--beagle_plink_template'), type = 'character', default = NULL, help = 'Full path to beagle plink maps template', metavar = 'character'),
    make_option(c('--sex'), type = 'character', default = NULL, help = 'Sex of the sample', metavar = 'character'),
    make_option(c('-o', '--output'), type = 'character', default = NULL, help = 'Directory where output will be written', metavar = 'character'),
    make_option(c('--skip_allelecount'), type = 'logical', default = FALSE, action = 'store_true', help = 'Provide when alleles don\'t have to be counted. This expects allelecount files on disk', metavar = 'character'),
    make_option(c('--skip_preprocessing'), type = 'logical', default = FALSE, action = 'store_true', help = 'Provide when pre-processing has previously completed. This expects the files on disk', metavar = 'character'),
    make_option(c('--skip_phasing'), type = 'logical', default = FALSE, action = 'store_true', help = 'Provide when phasing has previously completed. This expects the files on disk', metavar = 'character'),
    make_option(c('--cpu'), type = 'numeric', default = 8, help = 'The number of CPU cores to be used by the pipeline (Default: 8)', metavar = 'character'),
    make_option(c('--bp'), type = 'character', default = NULL, help = 'Optional two column file (chromosome and position) specifying prior breakpoints to be used during segmentation', metavar = 'character'),
    make_option(c('-g', '--ref_genome_build'), type = 'character', default = 'hg19', help = 'Reference genome build to which the reads have been aligned. Options are hg19 and hg38', metavar = 'character')
    );

opt.parser <- OptionParser(option_list = option.list);
opt <- parse_args(opt.parser);

analysis <- opt$analysis_type;
SAMPLENAME <- opt$samplename;
NORMALNAME <- opt$normalname;
NORMALBAM <- opt$nb;
SAMPLEBAM <- opt$tb;
BEAGLEJAR <- opt$beagle_jar;
BEAGLEREF.template <- opt$beagle_ref_template;
BEAGLEPLINK.template <- opt$beagle_plink_template;
IS.MALE <- opt$se == 'male' | opt$sex == 'Male';
RUN.DIR <- opt$output;
SKIP.ALLELECOUNTING <- opt$skip_allelecount;
SKIP.PREPROCESSING <- opt$skip_preprocessing;
SKIP.PHASING <- opt$skip_phasing;
NTHREADS <- opt$cpu;
PRIOR.BREAKPOINTS.FILE <- opt$bp;
GENOMEBUILD <- opt$ref_genome_build;

supported.analysis <- c('paired', 'cell_line', 'germline');
if (!analysis %in% supported.analysis) {
    stop(paste0('Requested analysis type ', analysis, ' is not available. Please provide either of ', paste(supported.analysis, collapse = ' ')));
    }

supported.genome.builds <- c('hg19', 'hg38');
if (!GENOMEBUILD %in% supported.genome.builds) {
    stop(paste0('Provided genome build ', GENOMEBUILD, ' is not supported. Please provide either of ', paste(supported.genome.builds, collapse = ' ')));
    }

JAVAJRE <- 'java';
ALLELECOUNTER <- 'alleleCounter';
IMPUTE.EXE <- 'impute2';
USEBEAGLE <- T;

BATTENBERG.REFERENCE <- '/opt/battenberg_reference/';
IMPUTEINFOFILE <- file.path(BATTENBERG.REFERENCE,'impute_info.txt');
G1000PREFIX <- file.path(BATTENBERG.REFERENCE,'1000_genomes_loci/1000_genomes_allele_index_chr');
G1000PREFIX.AC <- file.path(BATTENBERG.REFERENCE,'1000_genomes_loci/1000_genomes_loci_chr');
GCCORRECTPREFIX <- file.path(BATTENBERG.REFERENCE,'1000_genomes_gcContent/1000_genomes_GC_corr_chr');
PROBLEMLOCI <- file.path(BATTENBERG.REFERENCE,'battenberg_problem_loci/probloci.txt.gz');
REPLICCORRECTPREFIX <- file.path(BATTENBERG.REFERENCE,'battenberg_wgs_replication_timing_correction_1000_genomes/1000_genomes_replication_timing_chr');
BEAGLE.BASEDIR <- file.path(BATTENBERG.REFERENCE,'beagle');
BEAGLEJAR <- file.path(BEAGLE.BASEDIR,'beagle.27May24.118.jar');

# General static
if ('hg19' == GENOMEBUILD) {
    BEAGLEREF.template <- file.path(BEAGLE.BASEDIR, 'chrCHROMNAME.1kg.phase3.v5a.b37.bref3');
    BEAGLEPLINK.template <- file.path(BEAGLE.BASEDIR, 'plink.chrCHROMNAME.GRCh37.map');
    CHROM.COORD.FILE <- file.path(BATTENBERG.REFERENCE, 'gcCorrect_chromosome_coordinates_hg19.txt');
    } else if ('hg38' == GENOMEBUILD) {
        BEAGLEREF.template <- file.path(BEAGLE.BASEDIR, 'chrCHROMNAME.1kg.phase3.v5a_GRCh38nounref.vcf.gz');
        BEAGLEPLINK.template <- file.path(BEAGLE.BASEDIR, 'plink.chrCHROMNAME.GRCh38.map');
        CHROM.COORD.FILE <- file.path(BATTENBERG.REFERENCE, 'gcCorrect_chromosome_coordinates_hg38.txt');
        }

PLATFORM.GAMMA <- 1;
PHASING.GAMMA <- 1;
SEGMENTATION.GAMMA <- 10;
SEGMENTATIIN.KMIN <- 3;
PHASING.KMIN <- 1;
CLONALITY.DIST.METRIC <- 0;
ASCAT.DIST.METRIC <- 1;
MIN.PLOIDY <- 1.6;
MAX.PLOIDY <- 4.8;
MIN.RHO <- 0.1;
MIN.GOODNESS.OF.FIT <- 0.63;
BALANCED.THRESHOLD <- 0.51;
MIN.NORMAL.DEPTH <- 10;
MIN.BASE.QUAL <- 20;
MIN.MAP.QUAL <- 35;
USEBEAGLE <- TRUE;
BEAGLE.MAX.MEM <- 15;
BEAGLENTHREADS <- 1;
BEAGLEWINDOW <- 40;
BEAGLEOVERLAP <- 4;

# Set `calc_seg_baf_option` based on battenberg() function
if ('paired' == analysis) {
    CALC.SEG.BAF.OPTION <- 3;
    } else {
        CALC.SEG.BAF.OPTION <- 1;
    }

# Enable cairo device (needed to prevent 'X11 not available' errors)
options(bitmapType = 'cairo');

# Change to work directory and load the chromosome information
setwd(RUN.DIR);

battenberg(
    analysis = analysis,
    samplename = SAMPLENAME,
    normalname = NORMALNAME,
    sample_data_file = SAMPLEBAM,
    normal_data_file = NORMALBAM,
    ismale = IS.MALE,
    imputeinfofile = IMPUTEINFOFILE,
    g1000prefix = G1000PREFIX,
    g1000allelesprefix = G1000PREFIX.AC,
    gccorrectprefix = GCCORRECTPREFIX,
    repliccorrectprefix = REPLICCORRECTPREFIX,
    problemloci = PROBLEMLOCI,
    data_type = 'wgs',
    impute_exe = IMPUTE.EXE,
    allelecounter_exe = ALLELECOUNTER,
    usebeagle = USEBEAGLE, ##set to TRUE to use beagle
    beaglejar = BEAGLEJAR, ##path
    beagleref = BEAGLEREF.template, ##pathtemplate
    beagleplink = BEAGLEPLINK.template, ##pathtemplate
    beaglemaxmem = BEAGLE.MAX.MEM,
    beaglenthreads = BEAGLENTHREADS,
    beaglewindow = BEAGLEWINDOW,
    beagleoverlap = BEAGLEOVERLAP,
    javajre = JAVAJRE,
    nthreads = NTHREADS,
    platform_gamma = PLATFORM.GAMMA,
    phasing_gamma = PHASING.GAMMA,
    segmentation_gamma = SEGMENTATION.GAMMA,
    segmentation_kmin = SEGMENTATIIN.KMIN,
    phasing_kmin = PHASING.KMIN,
    clonality_dist_metric = CLONALITY.DIST.METRIC,
    ascat_dist_metric = ASCAT.DIST.METRIC,
    min_ploidy = MIN.PLOIDY,
    max_ploidy = MAX.PLOIDY,
    min_rho = MIN.RHO,
    min_goodness = MIN.GOODNESS.OF.FIT,
    uninformative_BAF_threshold = BALANCED.THRESHOLD,
    min_normal_depth = MIN.NORMAL.DEPTH,
    min_base_qual = MIN.BASE.QUAL,
    min_map_qual = MIN.MAP.QUAL,
    calc_seg_baf_option = CALC.SEG.BAF.OPTION,
    skip_allele_counting = SKIP.ALLELECOUNTING,
    skip_preprocessing = SKIP.PREPROCESSING,
    skip_phasing = SKIP.PHASING,
    prior_breakpoints_file = PRIOR.BREAKPOINTS.FILE,
    genomebuild = GENOMEBUILD,
    chrom_coord_file = CHROM.COORD.FILE
    );
