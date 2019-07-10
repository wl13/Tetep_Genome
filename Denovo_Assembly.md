## Tetep genome *denovo* assmbly using PacBio sequencing data

<br />

### Step 1) Prepare files, extract subreads and filtered by read length (>= 500) and score (>=0.8) using bash5tools.py (http://www.pacb.com/products-and-services/analytical-software/smrt-analysis/)
    bash5tools.py --minLength 500 --minReadScore 0.8 --readType subreads --outType fastq \
        --outFilePrefix file1.filtered_subreads file1.bas.h5
    .
    .
    .
    bash5tools.py --minLength 500 --minReadScore 0.8 --readType subreads --outType fastq \
        --outFilePrefix fileN.filtered_subreads fileN.bas.h5

<br />

### Step 2) Initial assembly with Canu (release v1.4, https://github.com/marbl/canu) use PacBio data only
    canu -p Tetep -d Tetep_PacBio genomeSize=449m ovsMemory=40g-100g -pacbio-raw *.filtered_subreads.fastq.gz

<br />

### Step 3) First round polishing with Quiver (https://github.com/PacificBiosciences/GenomicConsensus)
    ls *.bax.h5 > input.fofn

   #### Step 3.1) Align raw subreads to assembled contigs
    pbalign -vv --nproc 4 --forQuiver --tmpDir /tmp/ input.fofn contigs.fasta contigs.cmp.h5

   #### Step 3.2) Polishing with quiver
    quiver -j 30 contigs.cmp.h5 -r contigs.fasta -o contigs.quiver.fasta -o contigs.quiver.gff


<br />

### Step 4) Scaffolding with Chromosomer (https://github.com/gtamazian/chromosomer)
    chromosomer fastalength contigs.quiver.fasta contigs.quiver.length.csv

   #### Step 4.1) blast to MH63 reference genome (ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/001/623/365/GCA_001623365.1_MH63RS1/)
    makeblastdb -dbtype nucl -in MH63R_genome.fasta -title MH63R_genome -out MH63R_genome

    blastn -query contigs.quiver.fasta -db MH63R_genome.fasta -task blastn -evalue 1e-10 \
        -num_threads 12 -outfmt 6 -out contigs.quiver.blast.MH63.csv

   #### Step 4.2) run chromosomer fragmentmap and assembled (gap_size=20000, --ratio_threshold=1.1)
    chromosomer fragmentmap -r 1.1 contigs.quiver.blast.MH63.csv 20000 \
        contigs.quiver.length.csv contigs.quiver.chromosomer.map

    chromosomer assemble contigs.quiver.chromosomer.map contigs.quiver.fasta contigs.quiver.chromosomer.fasta


   #### Step 4.3) merge both placed chromosomes and unplaced contigs
    cat contigs.quiver.chromosomer_unlocalized.txt contigs.quiver.chromosomer_unplaced.txt | cut -f 1 | \
        fasta_process.pl --fasta contigs.quiver.fasta --query - --rows 0 --wordwrap 72 | \
        cat contigs.quiver.chromosomer.fasta - > scaffolds.fasta

<br />

### Step 5) Gap closing with PBJelly (https://sourceforge.net/p/pb-jelly/wiki/Home/) using all raw PacBio reads
    source PBSuite_15.8.24/setup.sh

    fakeQuals.py scaffolds.fasta scaffolds.qual

   #### Initial Stats, get some size information about reference and input reads
    summarizeAssembly.py scaffolds.fasta > scaffolds.sum.csv

    readSummary.py PBJelly.Protocol.xml > subreads.sum.csv

   #### Step 5.1) Setup files
    Jelly.py setup PBJelly.Protocol.xml

   #### Step 5.2) Mapping pacbio data
    Jelly.py mapping PBJelly.Protocol.xml

   #### Step 5.3) Support the gaps
    Jelly.py support PBJelly.Protocol.xml

   #### Step 5.4) Extract Useful Reads
    Jelly.py extraction PBJelly.Protocol.xml

   #### Step 5.5) Assemble The Gaps
    Jelly.py assembly PBJelly.Protocol.xml -x "--nproc=4"

   #### Step 5.6) Output Your Results
    Jelly.py output PBJelly.Protocol.xml

   #### Step 5.7) Rename output file
    python PBSuite_15.8.24/bin/rename_jelly_out.py scaffolds.fasta \
        liftOverTable.json jelly.out.fasta > scaffolds.jelly.fasta

<br />

### Step 6) second round polishing with Quiver
    smrtwrap pbalign -vv --nproc 4 --forQuiver --tmpDir /tmp/ input.fofn \
        scaffolds.jelly.fasta out.cmp.h5

    smrtwrap quiver -j 24 scaffolds.jelly.cmp.h5 -r scaffolds.jelly.fasta \
        -o scaffolds.jelly.quiver.fasta -o scaffolds.jelly.quiver.gff

<br />
