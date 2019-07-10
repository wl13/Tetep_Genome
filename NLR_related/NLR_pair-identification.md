
## Identification of paired NLR genes

<br />

### Step 1): sort all annotated genes by chromosome positions and assign an order number to each gene
    awk 'BEGIN{OFS="\t";} $3 == "gene" {print $1,$4,$5,$7,$9;}' \
        annotated_genes.gff3 | \
        sort -k1,1 -k2,3n | awk '{print $0,NR;}' \
        > annotated_genes.ordered.csv

<br />

### Step 2) extract NLRs, assume predicted NLR genes are marked by "NLR" in the above file
    grep "NLR" annotated_genes.ordered.csv > NLRs.ordered.csv

* The output would contain the strand and orders of each NLR in the following format:
        
        chromome start   end     strand  ID      order_number
        
        chr01    17212   24564   +       NLR1    1
        chr01    24591   25790   -       NLR2    6
        chr01    25943   29729   +       NLR3    7
        chr01    30362   40772   +       NLR4    16
        chr01    40991   42938   +       NLR5    25

<br />


### Step 3) search for strict and non-strict paired NLRs

> strict: head-to-head adjacent NLRs;

> non-strict: 1. nearby but non-adjacent NLRs (enclosing <= 2 non-NLR genes);   2. adjacent NLRs but not head-to-head orientated

      search_nearby_genes.pl -i NLRs.ordered.csv -m 2 -r 4 0 5 3 > NLRs.paired.csv

* Note: manully investigation is required for regions with >= 3 adjacent NLRs
 
<br />



### Step 4) map paired NLR homologues from other genomes
* first run orthofinder (https://github.com/davidemms/OrthoFinder) to find homologues of each NLR, then manually check whether non-strict paired NLRs have strict paired NLR homologues

      orthofinder -f nb-arc_pep/ -t 12 -og

<br />

### Step 5) confirm whether those candidate NLR pairs follow the co-evolve relationship between different species/cultivars in a phylogenetic tree

<br />


## Scripts


#### search_nearby_genes.pl   
> Extract closely resided genes 

* **Usage:**

        perl search_nearby_genes.pl -i <input> [-o <output>]

* **Options:**

        -i, --input  <filename>
            file contains ordered genes with strand info, required

        -r, --rows   <numbers>
            specify the row fields of gene id, chromosome id, gene order, and
            gene strand in input file [default: 0 1 2 3]

        -m, --max-include <int>
            how many non-desired genes are allowed between two genes
            [default: 0, means adjacent genes]

        -o, --output  <filename>
            output filename, default to STDOUT

<br />
