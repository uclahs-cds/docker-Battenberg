library(argparse);
library(pkgdepends);

parser <- ArgumentParser();

parser$add_argument(
    '-d',
    '--dependencies',
    nargs = '+',
    help = 'List dependencies separated by space'
    );

args <- parser$parse_args();

tools <- args$dependencies;

pkg.installation.proposal <- new_pkg_installation_proposal(tools);
pkg.installation.proposal$solve();
pkg.installation.proposal$download();
pkg.installation.proposal$install();
