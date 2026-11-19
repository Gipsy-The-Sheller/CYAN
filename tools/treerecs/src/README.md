Copyright (C) 2020  INRIA

This program is released under the GNU Affero General Public License Version 3.0-or-later.

# Treerecs
Treerecs is an open-source (species- and gene-) tree reconciliation software available for Linux, Windows and MacOS.
It can correct, rearrange and (re-)root gene trees with regard to a given species tree.

This README contains condensed information about how to install and how to use Treerecs.
For *detailed* information, please visit [the website](https://project.inria.fr/treerecs/).

# Installation

## Binaries
The simplest way to get Treerecs is to download the precompiled binaries.

### GNU/Linux and OS X
[install treerecs with bioconda](https://bioconda.github.io/recipes/treerecs/README.html)

### Windows
We advise windows users to run Treerecs via [Seaview](https://doua.prabi.fr/software/seaview).
Install and launch Seaview, then open a gene tree file (for instance one of those provided in the examples) and choose “Reconcile->Reconcile, root and rearrange with Treerecs” in the menu.

If you want to use Treerecs without Seaview, you can download binaries from the [gitlab page](https://gitlab.inria.fr/Phylophile/Treerecs/-/releases)


## From source

### 1. Dependencies

Treerecs comes with libpll and modules thereof. `libpll` requires that [GNU Bison](http://www.gnu.org/software/bison/)
and [Flex](http://flex.sourceforge.net/) are installed on the target system. On
a Debian-based Linux system, the two packages can be installed using the command

`apt-get install flex bison`

### 2. Get the source
#### Latest stable release:
* [download zip](https://gitlab.inria.fr/Phylophile/Treerecs/-/archive/master/Treerecs-master.zip)
* [downoad tar.gz](https://gitlab.inria.fr/Phylophile/Treerecs/-/archive/master/Treerecs-master.tar.gz)

### 3. Build

    cmake -DCMAKE_BUILD_TYPE=Release .
    cmake --build .
    
The created executable can be found in the *bin* directory.

    ./bin/treerecs -h

#### Note for Mac users:
The `-P | --parallelize` option requires the compiler to support openmp, which may not be the case for the default compiler. Consider using another compiler instead.
    
### 3. Install (optional)

    sudo cmake --install .
    
If you ever wish to uninstall Treerecs:

    xargs rm < install_manifest.txt

# Usage
## Syntax
*    `treerecs -h` or `--help`
*    `treerecs -V` or `--version`
*    `treerecs --usage`
*    `treerecs -g GENETREE_FILE -s SPECIESTREE_FILE [-S SMAP_FILE] [-t BRANCH_SUPPORT_THRESHOLD] [...]`
*    `treerecs -g GENETREE_FILE --info`

For option details, please visit [this page](https://project.inria.fr/treerecs/treerecs-options/).

## Tutorial
A tutorial is available at [https://project.inria.fr/treerecs/tutorial/](https://project.inria.fr/treerecs/tutorial/)

# References
* __Treerecs: an integrated phylogenetic tool, from sequences to reconciliations (2020)__,
    Nicolas Comte,
    Benoit Morel,
    Damir Hasic,
    Laurent Guéguen,
    Bastien Boussau,
    Vincent Daubin,
    Simon Penel,
    Celine Scornavacca,
    Manolo Gouy,
    Alexandros Stamatakis,
    Eric Tannier,
    David P. Parsons (in press)
* [__Efficient Gene Tree Correction Guided by Genome Evolution (2016)__,
    Emmanuel Noutahi,
    Magali Semeria, 
    Manuel Lafond, 
    Jonathan Seguin, 
    Bastien Boussau, 
    Laurent Guéguen, 
    Nadia El-Mabrouk,…](http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0159559)
* [__An Optimal Reconciliation Algorithm for Gene Trees with Polytomies__,
    Manuel Lafond,
    Krister M. Swenson,
    Nadia El-Mabrouk](http://link.springer.com/chapter/10.1007/978-3-642-33122-0_9)
* [__Genome-scale phylogenetic analysis finds extensive gene transfer among fungi__,
    Gergely J. Szöllősi,
    Adrián Arellano Davín, 
    Eric Tannier, 
    Vincent Daubin, 
    Bastien Boussau](http://rstb.royalsocietypublishing.org/content/370/1678/20140335.long)
