library(Battenberg)
library(optparse)


#' @inheritParams battenberg
battenberg_refit = function(varusepresetrhopsi=F, varpresetrho=NA, varpresetpsi=NA, tumourname, normalname, tumour_data_file, normal_data_file, imputeinfofile, g1000prefix, problemloci, gccorrectprefix=NULL,
                      repliccorrectprefix=NULL, g1000allelesprefix=NA, ismale=NA, data_type="wgs", impute_exe="impute2", allelecounter_exe="alleleCounter", nthreads=8, platform_gamma=1, phasing_gamma=1,
                      segmentation_gamma=10, segmentation_kmin=3, phasing_kmin=1, clonality_dist_metric=0, ascat_dist_metric=1, min_ploidy=1.6,
                      max_ploidy=4.8, min_rho=0.1, min_goodness=0.63, uninformative_BAF_threshold=0.51, min_normal_depth=10, min_base_qual=20,
                      min_map_qual=35, calc_seg_baf_option=3, skip_allele_counting=F, skip_preprocessing=F, skip_phasing=F, externalhaplotypefile = NA,
                      usebeagle=FALSE,
                      beaglejar=NA,
                      beagleref.template=NA,
                      beagleplink.template=NA,
                      beaglemaxmem=10,
                      beaglenthreads=1,
                      beaglewindow=40,
                      beagleoverlap=4,
                      javajre="java",
                      write_battenberg_phasing = T, multisample_relative_weight_balanced = 0.25, multisample_maxlag = 100, segmentation_gamma_multisample = 5,
                      snp6_reference_info_file=NA, apt.probeset.genotype.exe="apt-probeset-genotype", apt.probeset.summarize.exe="apt-probeset-summarize",
                      norm.geno.clust.exe="normalize_affy_geno_cluster.pl", birdseed_report_file="birdseed.report.txt", heterozygousFilter="none",
                      prior_breakpoints_file=NULL) {

  requireNamespace("foreach")
  requireNamespace("doParallel")
  requireNamespace("parallel")

  if (data_type=="wgs" & is.na(ismale)) {
    stop("Please provide a boolean denominator whether this sample represents a male donor")
  }

  if (data_type=="wgs" & is.na(g1000allelesprefix)) {
    stop("Please provide a path to 1000 Genomes allele reference files")
  }

  if (data_type=="wgs" & is.null(gccorrectprefix)) {
    stop("Please provide a path to GC content reference files")
  }

  if (!file.exists(problemloci)) {
    stop("Please provide a path to a problematic loci file")
  }

  if (!file.exists(imputeinfofile)) {
    stop("Please provide a path to an impute info file")
  }

  # check whether the impute_info.txt file contains correct paths
  check.imputeinfofile(imputeinfofile = imputeinfofile, is.male = ismale, usebeagle = usebeagle)

  # check whether multisample case
  nsamples <- length(tumourname)
  if (nsamples > 1) {
    if (length(skip_allele_counting) < nsamples) {
      skip_allele_counting = rep(skip_allele_counting[1], nsamples)
    }
    if (length(skip_preprocessing) < nsamples) {
      skip_preprocessing = rep(skip_preprocessing[1], nsamples)
    }
    if (length(skip_phasing) < nsamples) {
      skip_phasing = rep(skip_phasing[1], nsamples)
    }
  }


  if (data_type=="wgs" | data_type=="WGS") {
    if (nsamples > 1) {
      print(paste0("Running Battenberg in multisample mode on ", nsamples, " samples: ", paste0(tumourname, collapse = ", ")))
    }
    chrom_names = get.chrom.names(imputeinfofile, ismale)
  } else if (data_type=="snp6" | data_type=="SNP6") {
    if (nsamples > 1) {
      stop(paste0("Battenberg multisample mode has not been tested with SNP6 data"))
    }
    chrom_names = get.chrom.names(imputeinfofile, TRUE)
    logr_file = paste(tumourname, "_mutantLogR.tab", sep="")
    allelecounts_file = NULL
  }

  for (sampleidx in 1:nsamples) {

    if (!skip_preprocessing[sampleidx]) {
      if (data_type=="wgs" | data_type=="WGS") {
        # Setup for parallel computing
        clp = parallel::makeCluster(nthreads)
        doParallel::registerDoParallel(clp)

        prepare_wgs(chrom_names=chrom_names,
                    tumourbam=tumour_data_file[sampleidx],
                    normalbam=normal_data_file,
                    tumourname=tumourname[sampleidx],
                    normalname=normalname,
                    g1000allelesprefix=g1000allelesprefix,
                    g1000prefix=g1000prefix,
                    gccorrectprefix=gccorrectprefix,
                    repliccorrectprefix=repliccorrectprefix,
                    min_base_qual=min_base_qual,
                    min_map_qual=min_map_qual,
                    allelecounter_exe=allelecounter_exe,
                    min_normal_depth=min_normal_depth,
                    nthreads=nthreads,
                    skip_allele_counting=skip_allele_counting[sampleidx],
                    skip_allele_counting_normal = (sampleidx > 1))

        # Kill the threads
        parallel::stopCluster(clp)

      } else if (data_type=="snp6" | data_type=="SNP6") {

        prepare_snp6(tumour_cel_file=tumour_data_file[sampleidx],
                     normal_cel_file=normal_data_file,
                     tumourname=tumourname[sampleidx],
                     chrom_names=chrom_names,
                     snp6_reference_info_file=snp6_reference_info_file,
                     apt.probeset.genotype.exe=apt.probeset.genotype.exe,
                     apt.probeset.summarize.exe=apt.probeset.summarize.exe,
                     norm.geno.clust.exe=norm.geno.clust.exe,
                     birdseed_report_file=birdseed_report_file)

      } else {
        print("Unknown data type provided, please provide wgs or snp6")
        q(save="no", status=1)
      }
    }

    if (data_type=="snp6" | data_type=="SNP6") {
      # Infer what the gender is - WGS requires it to be specified
      gender = infer_gender_birdseed(birdseed_report_file)
      ismale = gender == "male"
    }


    if (!skip_phasing[sampleidx]) {

      # if external phasing data is provided (as a vcf), split into chromosomes for use in haplotype reconstruction
      if (!is.na(externalhaplotypefile) && file.exists(externalhaplotypefile)) {
        externalhaplotypeprefix <- paste0(normalname, "_external_haplotypes_chr")

        # if these files exist already, no need to split again
        if (any(!file.exists(paste0(externalhaplotypeprefix, 1:length(chrom_names), ".vcf")))) {

          print(paste0("Splitting external phasing data from ", externalhaplotypefile))
          split_input_haplotypes(chrom_names = chrom_names,
                                 externalhaplotypefile = externalhaplotypefile,
                                 outprefix = externalhaplotypeprefix)
        } else {
          print("No need to split, external haplotype files per chromosome found")
        }
      } else {
        externalhaplotypeprefix <- NA
      }

      # Setup for parallel computing
      clp = parallel::makeCluster(nthreads)
      doParallel::registerDoParallel(clp)

      # Reconstruct haplotypes
      # mclapply(1:length(chrom_names), function(chrom) {
      foreach::foreach (chrom=1:length(chrom_names)) %dopar% {
        print(chrom)

        run_haplotyping(chrom=chrom,
                        tumourname=tumourname[sampleidx],
                        normalname=normalname,
                        ismale=ismale,
                        imputeinfofile=imputeinfofile,
                        problemloci=problemloci,
                        impute_exe=impute_exe,
                        min_normal_depth=min_normal_depth,
                        chrom_names=chrom_names,
                        snp6_reference_info_file=snp6_reference_info_file,
                        heterozygousFilter=heterozygousFilter,
                        usebeagle=usebeagle,
                        beaglejar=beaglejar,
                        beagleref=gsub("CHROMNAME",if(chrom==23) "X" else chrom, beagleref.template),
                        beagleplink=gsub("CHROMNAME",if(chrom==23) "X" else chrom, beagleplink.template),
                        beaglemaxmem=beaglemaxmem,
                        beaglenthreads=beaglenthreads,
                        beaglewindow=beaglewindow,
                        beagleoverlap=beagleoverlap,
                        externalhaplotypeprefix=externalhaplotypeprefix,
                        use_previous_imputation=(sampleidx > 1))
      }#, mc.cores=nthreads)

      # Kill the threads as from here its all single core
      parallel::stopCluster(clp)

      # Combine all the BAF output into a single file
      combine.baf.files(inputfile.prefix=paste(tumourname[sampleidx], "_chr", sep=""),
                        inputfile.postfix="_heterozygousMutBAFs_haplotyped.txt",
                        outputfile=paste(tumourname[sampleidx], "_heterozygousMutBAFs_haplotyped.txt", sep=""),
                        no.chrs=length(chrom_names))
    }

    # Segment the phased and haplotyped BAF data
    segment.baf.phased(samplename=tumourname[sampleidx],
                       inputfile=paste(tumourname[sampleidx], "_heterozygousMutBAFs_haplotyped.txt", sep=""),
                       outputfile=paste(tumourname[sampleidx], ".BAFsegmented.txt", sep=""),
                       prior_breakpoints_file=prior_breakpoints_file,
                       gamma=segmentation_gamma,
                       phasegamma=phasing_gamma,
                       kmin=segmentation_kmin,
                       phasekmin=phasing_kmin,
                       calc_seg_baf_option=calc_seg_baf_option)

    if (nsamples > 1 | write_battenberg_phasing) {
      # Write the Battenberg phasing information to disk as a vcf
      write_battenberg_phasing(tumourname = tumourname[sampleidx],
                               SNPfiles = paste0(tumourname[sampleidx], "_alleleFrequencies_chr", 1:length(chrom_names), ".txt"),
                               imputedHaplotypeFiles = paste0(tumourname[sampleidx], "_impute_output_chr", 1:length(chrom_names), "_allHaplotypeInfo.txt"),
                               bafsegmented_file = paste0(tumourname[sampleidx], ".BAFsegmented.txt"),
                               outprefix = paste0(tumourname[sampleidx], "_Battenberg_phased_chr"),
                               chrom_names = chrom_names,
                               include_homozygous = F)
    }

  }


  # if this is a multisample run, combine the battenberg phasing outputs, incorporate it and resegment
  if (nsamples > 1) {
    print("Constructing multisample phasing")
    multisamplehaplotypeprefix <- paste0(normalname, "_multisample_haplotypes_chr")


    # Setup for parallel computing
    clp = parallel::makeCluster(nthreads)
    doParallel::registerDoParallel(clp)

    # Reconstruct haplotypes
    # mclapply(1:length(chrom_names), function(chrom) {
    foreach::foreach (chrom=1:length(chrom_names)) %dopar% {
      print(chrom)

      get_multisample_phasing(chrom = chrom,
                              bbphasingprefixes = paste0(tumourname, "_Battenberg_phased_chr"),
                              maxlag = multisample_maxlag,
                              relative_weight_balanced = multisample_relative_weight_balanced,
                              outprefix = multisamplehaplotypeprefix)

    }


    # continue over all samples to incorporate the multisample phasing
    for (sampleidx in 1:nsamples) {

      # rename the original files without multisample phasing info
      MutBAFfiles <- paste0(tumourname[sampleidx], "_chr", 1:length(chrom_names), "_heterozygousMutBAFs_haplotyped.txt")
      heterozygousdatafiles <- paste0(tumourname[sampleidx], "_chr", 1:length(chrom_names), "_heterozygousData.png")
      raffiles <- paste0(tumourname[sampleidx], "_RAFseg_chr", chrom_names, ".png")
      segfiles <- paste0(tumourname[sampleidx], "_segment_chr", chrom_names, ".png")
      haplotypedandbafsegmentedfiles <- paste0(tumourname[sampleidx], c("_heterozygousMutBAFs_haplotyped.txt", ".BAFsegmented.txt"))

      file.copy(from = MutBAFfiles, to = gsub(pattern = ".txt$", replacement = "_noMulti.txt", x = MutBAFfiles), overwrite = T)
      file.copy(from = heterozygousdatafiles, to = gsub(pattern = ".png$", replacement = "_noMulti.png", x = heterozygousdatafiles), overwrite = T)
      file.copy(from = raffiles, to = gsub(pattern = ".png$", replacement = "_noMulti.png", x = raffiles), overwrite = T)
      file.copy(from = segfiles, to = gsub(pattern = ".png$", replacement = "_noMulti.png", x = segfiles), overwrite = T)
      file.copy(from = haplotypedandbafsegmentedfiles, to = gsub(pattern = ".txt$", replacement = "_noMulti.txt", x = haplotypedandbafsegmentedfiles), overwrite = T)
      # done renaming, next sections will overwrite orignals


      foreach::foreach (chrom=1:length(chrom_names)) %dopar% {
        print(chrom)

        input_known_haplotypes(chrom = chrom,
                               chrom_names = chrom_names,
                               imputedHaplotypeFile = paste0(tumourname[sampleidx], "_impute_output_chr", chrom, "_allHaplotypeInfo.txt"),
                               externalHaplotypeFile = paste0(multisamplehaplotypeprefix, chrom, ".vcf"),
                               oldfilesuffix = "_noMulti.txt")

        GetChromosomeBAFs(chrom=chrom,
                          SNP_file=paste0(tumourname[sampleidx], "_alleleFrequencies_chr", chrom, ".txt"),
                          haplotypeFile=paste0(tumourname[sampleidx], "_impute_output_chr", chrom, "_allHaplotypeInfo.txt"),
                          samplename=tumourname[sampleidx],
                          outfile=paste0(tumourname[sampleidx], "_chr", chrom, "_heterozygousMutBAFs_haplotyped.txt"),
                          chr_names=chrom_names,
                          minCounts=min_normal_depth)

        # Plot what we have until this point
        plot.haplotype.data(haplotyped.baf.file=paste0(tumourname[sampleidx], "_chr", chrom, "_heterozygousMutBAFs_haplotyped.txt"),
                            imageFileName=paste0(tumourname[sampleidx],"_chr",chrom,"_heterozygousData.png"),
                            samplename=tumourname[sampleidx],
                            chrom=chrom,
                            chr_names=chrom_names)
      }

    }

    # Kill the threads as from here its single core
    parallel::stopCluster(clp)

    for (sampleidx in 1:nsamples) {

      # Combine all the BAF output into a single file
      combine.baf.files(inputfile.prefix=paste0(tumourname[sampleidx], "_chr"),
                        inputfile.postfix="_heterozygousMutBAFs_haplotyped.txt",
                        outputfile=paste0(tumourname[sampleidx], "_heterozygousMutBAFs_haplotyped.txt"),
                        no.chrs=length(chrom_names))

    }

    # Segment the phased and haplotyped BAF data
    segment.baf.phased.multisample(samplename=tumourname,
                                   inputfile=paste(tumourname, "_heterozygousMutBAFs_haplotyped.txt", sep=""),
                                   outputfile=paste(tumourname, ".BAFsegmented.txt", sep=""),
                                   prior_breakpoints_file=prior_breakpoints_file,
                                   gamma=segmentation_gamma_multisample,
                                   calc_seg_baf_option=calc_seg_baf_option)

  }


  # Setup for parallel computing
  clp = parallel::makeCluster(min(nthreads, nsamples))
  doParallel::registerDoParallel(clp)

  # for (sampleidx in 1:nsamples) {
  foreach::foreach (sampleidx=1:nsamples) %dopar% {
    print(paste0("Fitting final copy number and calling subclones for sample ", tumourname[sampleidx]))

    if (data_type=="wgs" | data_type=="WGS") {
      logr_file = paste(tumourname[sampleidx], "_mutantLogR_gcCorrected.tab", sep="")
      allelecounts_file = paste(tumourname[sampleidx], "_alleleCounts.tab", sep="")
    }

    # Fit a clonal copy number profile
    fit.copy.number(samplename=tumourname[sampleidx],
                    outputfile.prefix=paste(tumourname[sampleidx], "_", sep=""),
                    inputfile.baf.segmented=paste(tumourname[sampleidx], ".BAFsegmented.txt", sep=""),
                    inputfile.baf=paste(tumourname[sampleidx],"_mutantBAF.tab", sep=""),
                    inputfile.logr=logr_file,
                    dist_choice=clonality_dist_metric,
                    ascat_dist_choice=ascat_dist_metric,
                    min.ploidy=min_ploidy,
                    max.ploidy=max_ploidy,
                    min.rho=min_rho,
                    min.goodness=min_goodness,
                    uninformative_BAF_threshold=uninformative_BAF_threshold,
                    gamma_param=platform_gamma,
                    use_preset_rho_psi=varusepresetrhopsi,
                    preset_rho=varpresetrho,
                    preset_psi=varpresetpsi,
                    read_depth=30)

    # Go over all segments, determine which segements are a mixture of two states and fit a second CN state
    callSubclones(sample.name=tumourname[sampleidx],
                  baf.segmented.file=paste(tumourname[sampleidx], ".BAFsegmented.txt", sep=""),
                  logr.file=logr_file,
                  rho.psi.file=paste(tumourname[sampleidx], "_rho_and_psi.txt",sep=""),
                  output.file=paste(tumourname[sampleidx],"_subclones.txt", sep=""),
                  output.figures.prefix=paste(tumourname[sampleidx],"_subclones_chr", sep=""),
                  output.gw.figures.prefix=paste(tumourname[sampleidx],"_BattenbergProfile", sep=""),
                  masking_output_file=paste(tumourname[sampleidx], "_segment_masking_details.txt", sep=""),
                  prior_breakpoints_file=prior_breakpoints_file,
                  chr_names=chrom_names,
                  gamma=platform_gamma,
                  segmentation.gamma=NA,
                  siglevel=0.05,
                  maxdist=0.01,
                  noperms=1000,
                  calc_seg_baf_option=calc_seg_baf_option)

    # Make some post-hoc plots
    make_posthoc_plots(samplename=tumourname[sampleidx],
                       logr_file=logr_file,
                       subclones_file=paste(tumourname[sampleidx], "_subclones.txt", sep=""),
                       rho_psi_file=paste(tumourname[sampleidx], "_rho_and_psi.txt", sep=""),
                       bafsegmented_file=paste(tumourname[sampleidx], ".BAFsegmented.txt", sep=""),
                       logrsegmented_file=paste(tumourname[sampleidx], ".logRsegmented.txt", sep=""),
                       allelecounts_file=allelecounts_file)

    # Save refit suggestions for a future rerun
    cnfit_to_refit_suggestions(samplename=tumourname[sampleidx],
                               subclones_file=paste(tumourname[sampleidx], "_subclones.txt", sep=""),
                               rho_psi_file=paste(tumourname[sampleidx], "_rho_and_psi.txt", sep=""),
                               gamma_param=platform_gamma)

  }

  # Kill the threads as last part again is single core
  parallel::stopCluster(clp)

  if (nsamples > 1) {
    print("Assessing mirrored subclonal allelic imbalance (MSAI)")
    call_multisample_MSAI(rdsprefix = multisamplehaplotypeprefix,
                          subclonesfiles = paste0(tumourname, "_subclones.txt"),
                          chrom_names = chrom_names,
                          tumournames = tumourname,
                          plotting = T)
  }
}
environment(battenberg_refit) <- environment(battenberg)


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
  make_option(c("--min_ploidy"), type="numeric", default=1.6, help="Minimum ploidy to be considered (Default: 1.6)", metavar="character"),
  make_option(c("--max_ploidy"), type="numeric", default=4.8, help="Maximum ploidy to be considered (Default: 4.8)", metavar="character"),
  make_option(c("--min_rho"), type="numeric", default=0.1, help="Minimum purity to be considered (Default: 0.1", metavar="character"),
  make_option(c("--min_goodness"), type="numeric", default=0.63, help="Minimum goodness of fit required for a purity/ploidy combination to be accepted as a solution (Default: 0.63)", metavar="character"),
  make_option(c("--use_presetrhopsi"), type="logical", default=FALSE, help="Use a preset rho and psi for refitting", metavar="character"),
  make_option(c("--preset_rho"), type="numeric", default=NULL, help="Preset rho", metavar="character"),
  make_option(c("--preset_psi"), type="numeric", default=NULL, help="Preset psi", metavar="character"),
  make_option(c("--cpu"), type="numeric", default=8, help="The number of CPU cores to be used by the pipeline (Default: 8)", metavar="character"),
  make_option(c("--bp"), type="character", default=NULL, help="Optional two column file (chromosome and position) specifying prior breakpoints to be used during segmentation", metavar="character")
)

opt_parser = OptionParser(option_list=option_list)
opt = parse_args(opt_parser)

TUMOURNAME = opt$tumourname
NORMALNAME = opt$normalname
NORMALBAM = opt$nb
TUMOURBAM = opt$tb
IS.MALE = opt$sex=="male" | opt$sex=="Male"
RUN_DIR = opt$output
SKIP_ALLELECOUNTING = opt$skip_allelecount
SKIP_PREPROCESSING = opt$skip_preprocessing
SKIP_PHASING = opt$skip_phasing
NTHREADS = opt$cpu
PRIOR_BREAKPOINTS_FILE = opt$bp
MIN_PLOIDY = opt$min_ploidy
MAX_PLOIDY = opt$max_ploidy
MIN_RHO = opt$min_rho
MIN_GOODNESS_OF_FIT = opt$min_goodness
VARUSEPRESETRHOPSI = opt$use_presetrhopsi
VARPRESETRHO = opt$preset_rho
VARPRESETPSI = opt$preset_psi

###############################################################################
# 2018-11-01
# A pure R Battenberg v2.2.9 WGS pipeline implementation.
# sd11 [at] sanger.ac.uk
###############################################################################

# General static
IMPUTEINFOFILE = "/opt/battenberg_reference/imputation/impute_info_modified.txt"
G1000PREFIX = "/opt/battenberg_reference/1000G_loci_hg38/1kg.phase3.v5a_GRCh38nounref_allele_index_chr"
G1000PREFIX_AC = "/opt/battenberg_reference/1000G_loci_hg38/1kg.phase3.v5a_GRCh38nounref_loci_chrstring_chr"
GCCORRECTPREFIX = "/opt/battenberg_reference/GC_correction_hg38/1000G_GC_chr"
REPLICCORRECTPREFIX = "/opt/battenberg_reference/RT_correction_hg38/1000G_RT_chr"
IMPUTE_EXE = "impute2"

PLATFORM_GAMMA = 1
PHASING_GAMMA = 1
SEGMENTATION_GAMMA = 10
SEGMENTATIIN_KMIN = 3
PHASING_KMIN = 1
CLONALITY_DIST_METRIC = 0
ASCAT_DIST_METRIC = 1
BALANCED_THRESHOLD = 0.51
MIN_NORMAL_DEPTH = 10
MIN_BASE_QUAL = 20
MIN_MAP_QUAL = 35
CALC_SEG_BAF_OPTION = 1

# WGS specific static
ALLELECOUNTER = "alleleCounter"
PROBLEMLOCI = "/opt/battenberg_reference/probloci/probloci.txt"
USEBEAGLE = T
GENOME_VERSION = "hg38"
BEAGLE_BASEDIR = "/opt/battenberg_reference/beagle5"
BEAGLEJAR = file.path(BEAGLE_BASEDIR, "beagle.24Aug19.3e8.jar")
BEAGLEREF.template = file.path(BEAGLE_BASEDIR, GENOME_VERSION, "chrCHROMNAME.1kg.phase3.v5a_GRCh38nounref.vcf.gz")
BEAGLEPLINK.template = file.path(BEAGLE_BASEDIR, GENOME_VERSION, "plink.chrCHROMNAME.GRCh38.map")
JAVAJRE = "java"


# Change to work directory and load the chromosome information
setwd(RUN_DIR)

battenberg_refit(varusepresetrhopsi=VARUSEPRESETRHOPSI,
					 varpresetrho=VARPRESETRHO,
					 varpresetpsi=VARPRESETPSI,
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
	   usebeagle=USEBEAGLE,
	   beaglejar=BEAGLEJAR,
	   beagleref=BEAGLEREF.template,
	   beagleplink=BEAGLEPLINK.template,
	   beaglemaxmem=10,
	   beaglenthreads=1,
	   beaglewindow=40,
	   beagleoverlap=4,
	   javajre=JAVAJRE,
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
           prior_breakpoints_file=PRIOR_BREAKPOINTS_FILE)

