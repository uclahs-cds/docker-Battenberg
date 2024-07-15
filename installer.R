library(argparse);
library(pkgdepends);

parser <- ArgumentParser();

parser$add_argument(
    '-r',
    '--repo-name',
    help = 'Specify the repo name'
    );
parser$add_argument(
    '-av',
    '--add-version',
    help = 'Specify tool version'
    );

args <- parser$parse_args();

repo <- args$repo_name;
version <- args$add_version;

if (!(startsWith(version, 'v'))) {
    version <- paste('v', version, sep = '')
    };

tool <- paste(repo, '@' ,version, sep = '');

pkg.download.proposal <- new_pkg_download_proposal(tool);
pkg.download.proposal$resolve();
pkg.download.proposal$download();

#Packages and dependencies will be installed in the path below
lib <- '/usr/lib/R/site-library';
config <- list(library = lib);

pkg.installation.proposal <- new_pkg_installation_proposal(
  tool,
  config = list(library = lib)
);
pkg.installation.proposal$solve();
pkg.installation.proposal$download();
pkg.installation.proposal$install();
