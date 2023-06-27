# docker-Battenberg
This repository contains code for the whole genome sequencing subclonal copy number caller Battenberg, as described in [Nik-Zainal, Van Loo, Wedge, et al. (2012), Cell](https://www.ncbi.nlm.nih.gov/pubmed/22608083).

It installs the release v2.2.9 of Battenberg and modifies the Battenberg resource paths for GRCh37 and GRCh38 based on how they are structured in the Boutros Lab cluster.

GRCh37 resources - `/hot/ref/tool-specific-input/Battenberg/download_202204/GRCh37/`

GRCh38 resources -
 - with `chr` name (recommended): `/hot/ref/tool-specific-input/Battenberg/download_202204/GRCh38/battenberg_ref_hg38_chr/`
 - without `chr` name: `/hot/ref/tool-specific-input/Battenberg/download_202204/GRCh38/battenberg_ref_hg38_non_chr/`

This image can be found in docker-Battenberg's GitHub package page [here](https://github.com/uclahs-cds/docker-Battenberg/pkgs/container/battenberg).

# Example Usage
```
docker run --rm -u $(id -u):$(id -g) -w $(pwd) -v /hot/:/hot/ \
    -v /hot/ref/tool-specific-input/Battenberg/download_202204/GRCh38/battenberg_ref_hg38_chr/:/opt/battenberg_reference/ \
    battenberg:2.2.9 Rscript /usr/local/bin/battenberg_wgs.R \
        -t ${tumor_sample_name} \
        -n ${normal_sample_name} \
        --tb ${tumor_bam} \
        --nb ${normal_bam} \
        -o ${sample_out_dir} \
        --sex ${sample_sex}
```

# Documentation
Battenberg GitHub repository [here](https://github.com/Wedge-lab/battenberg)


# Version
| Tool | Version |
|------|---------|
|Battenberg|2.2.9|
|HTSlib|1.16|
|alleleCount|4.3.0|
|IMPUTE2|2.3.2|
|ASCAT|3.1.2|


---

## References

1. Nik-Zainal S, Van Loo P, Wedge DC, Alexandrov LB, Greenman CD, Lau KW, Raine K, Jones D, Marshall J, Ramakrishna M, Shlien A, Cooke SL, Hinton J, Menzies A, Stebbings LA, Leroy C, Jia M, Rance R, Mudie LJ, Gamble SJ, Stephens PJ, McLaren S, Tarpey PS, Papaemmanuil E, Davies HR, Varela I, McBride DJ, Bignell GR, Leung K, Butler AP, Teague JW, Martin S, Jönsson G, Mariani O, Boyault S, Miron P, Fatima A, Langerød A, Aparicio SA, Tutt A, Sieuwerts AM, Borg Å, Thomas G, Salomon AV, Richardson AL, Børresen-Dale AL, Futreal PA, Stratton MR, Campbell PJ; Breast Cancer Working Group of the International Cancer Genome Consortium. The life history of 21 breast cancers. Cell. 2012 May 25;149(5):994-1007. doi: 10.1016/j.cell.2012.04.023. Epub 2012 May 17. Erratum in: Cell. 2015 Aug 13;162(4):924. PMID: 22608083; PMCID: PMC3428864.

---

## License

Author: 'Mohammed Faizal Eeman Mootor', 'Ardalan Davarifar'

docker-Battenberg is licensed under the GNU General Public License version 2. See the file LICENSE for the terms of the GNU GPL license.

docker-Battenberg can be used to create a docker instance to use the Battenberg tool. 

Copyright (C) 2021-2023 University of California Los Angeles ("Boutros Lab") All rights reserved.

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
