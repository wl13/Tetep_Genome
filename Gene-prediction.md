## Tetep gene prediction with MAKER-P (http://weatherby.genetics.utah.edu/MAKER/wiki/index.php/MAKER_Tutorial)

<br />

## 1) Pre-process procedures


### 1.1) Get homologous EST and protein data from NCBI (https://www.ncbi.nlm.nih.gov/nucest) and Uniprot (https://www.uniprot.org/), format the downloaded data
    perl -ne 'next if (/^\s+$/); s/\>gi\|(\d+).*/>$1/; print;' \
        est/Oryza_sativa.est.NCBI-20160406.fasta \
        > est/Oryza_sativa.est.NCBI-20160406.rename.fasta

    perl -ne 'next if (/^\s+$/); s/\>sp\|(\w+).*/>$1/; print;' \
        UniProt/uniprot-Oryza_sativa-20160527.fasta \
        > UniProt/uniprot-Oryza_sativa-20160527.rename.fasta

<br />

### 1.2) Process RNA-seq data


#### Step1: align RNA reads to Tetep genome using STAR aligner (https://github.com/alexdobin/STAR)

    STAR --genomeDir star \
        --readFilesIn Tetep_RNA_1.fq.gz Tetep_RNA_1_2.fq.gz \
        --runThreadN 12 --readFilesCommand zcat \
        --outSAMstrandField intronMotif --outFilterIntronMotifs RemoveNoncanonical \
        --outSAMtype BAM SortedByCoordinate \
        --outFileNamePrefix Tetep.star

    samtools index Tetep.starAligned.sortedByCoord.out.bam


<br />

#### Step2: Mapping transcriptome to reference genome with Cufflinks (http://cole-trapnell-lab.github.io/cufflinks/cufflinks/index.html)

    cufflinks Tetep.starAligned.sortedByCoord.out.bam \
        –frag-bias-correct genome.fasta \
        –multi-read-correct –max-intron-length 20000 –no-update-check

<br />

#### Step3: Transcriptome *denovo* with Trinity (https://github.com/trinityrnaseq/trinityrnaseq/wiki)

#### Step3-1: Genome-free assembly
    Trinity --CPU 12 --seqType fq --max_memory 150G --full_cleanup \
        --samples_file trinity/Tetep_RNA.samples.txt \
        --output trinity/Tetep.star.trinity

#### Step3-2: Genome-guided assembly
    Trinity --CPU 6 --max_memory 20G --genome_guided_max_intron 10000 \
        --genome_guided_bam Tetep.starAligned.sortedByCoord.out.bam \
        --output trinity/Tetep.star.trinity

#### Step3-3: combine results from both assembly
    cat trinity/Tetep.star.trinity.fasta \
        trinity/Tetep.star.trinity-GG.fasta \
        > trinity/Tetep.star.trinity-all.fasta

<br />

### 1.3) assessing genome assembly and annotation completeness with CEGMA (Core Eukaryotic Genes Mapping Approach, https://github.com/KorfLab/CEGMA_v2/)

cegma -T 8 -g genome.fasta -o genome


<br />

## 2) MAKER-P pipeline

### Step1: Train SNAP (https://github.com/KorfLab/SNAP) with CEGMA generated gff output

    cd snap/cegma/

    cegma2zff genome.cegma.gff genome.fasta

    fathom -categorize 1000 genome.ann genome.dna

    fathom -export 1000 -plus uni.ann uni.dna

    forge export.ann export.dna

    hmm-assembler.pl genome.cegma.snap . genome.cegma.snap.hmm

<br />

### Step2: First-pass run of MAKER, use:
  1. EST data (trinity assembled mRNAs, data downloaded from NCBI dbEST, keyword: Oryza sativa, retrieved: 20160406)
  
      est=trinity/Tetep.star.trinity-all.fasta
      
      altest=est/Oryza_sativa.est.NCBI-20160406.rename.fasta
      
      est2genome=1
      
  2. Proteins (data downloaded from UniProt, keyword: Oryza sativa, retrieved: 20160527)
  
      protein=UniProt/uniprot-Oryza_sativa-20160527.rename.fasta
      
      protein2genome=1
      
  3. a trained SNAP model
  
      snaphmm=snap/genome.cegma.snap.hmm
      
  4. predicted gff3 file from cufflinks
  
      pred_gff=star/Tetep.starAligned.sortedByCoord.cufflinks.transcripts.gff3
      
  5. other settings
  
      min_contig=10000
      
      min_protein=30
      
      alt_splice=1

    mpiexec -mca btl ^openib -n 12 maker \
        -genome genome.fasta \
        -cpus 1 -quiet -fix_nucleotides -base Tetep

<br />

### Step3: Generate GFF3 file from 1st pass run
    gff3_merge -n -d maker/pass1/Tetep.maker.output/master_datastore_index.log \
        -o maker/pass1/genome.maker.pass1.gff

<br />

### Step4: Further training SNAP and Augustus (http://augustus.gobics.de/) use 1st pass results

#### Step4-1: Training Augustus
    autoAug.pl --genome=genome.fasta \
        --species=oryza_sativa_indica --singleCPU --useexisting \
        --trainingset=maker/pass1/genome.maker.pass1.gff \
        --workingdir=augustus/maker


#### Step4-2: Re-generate SNAP traning file
    maker2zff -n -d maker/pass1/Tetep.maker.output/master_datastore_index.log

    fathom -categorize 1000 snap/maker/genome.ann \
        snap/maker/genome.dna

    fathom -export 1000 -plus snap/maker/uni.ann \
        snap/maker/uni.dna

    forge snap/maker/export.ann \
        snap/maker/export.dna

    hmm-assembler.pl genome.maker.snap . \
        > snap/genome.maker.snap.hmm

<br />

### Step5: Second-pass run of MAKER, using trained Augustus and SNAP model

  1. EST data (trinity assembled mRNAs, data downloaded from NCBI dbEST, keyword: Oryza sativa, retrieved: 20160406)
  
      est=trinity/Tetep.star.trinity-all.fasta
      
      altest=est/Oryza_sativa.est.NCBI-20160406.rename.fasta
      
      est2genome=0
      
  2. Proteins (data downloaded from UniProt, keyword: Oryza sativa, retrieved: 20160527)
  
      protein=UniProt/uniprot-Oryza_sativa-20160527.rename.fasta
      
      protein2genome=0
      
  3. a re-trained SNAP model
  
      snaphmm=snap/genome.maker.snap.hmm
      
  4. a trained Augustus model
  
      augustus_species=oryza_sativa_indica
      
  5. predicted gff3 file from cufflinks
  
      pred_gff=star/Tetep.starAligned.sortedByCoord.cufflinks.transcripts.gff3
      
  6. other settings
  
      min_contig=10000
      
      min_protein=30
      
      alt_splice=1


    mpiexec -mca btl ^openib -n 4 maker \
        -genome genome.fasta \
        -cpus 1 -quiet -fix_nucleotides -base Tetep

<br />

### Step6: Generate new GFF3 annotation file


    gff3_merge -n -g -d maker/pass2/Tetep.maker.output/master_datastore_index.log \
        -o maker/pass2/genome.maker.pass2.gff3


    fasta_merge -d maker/pass2/Tetep.maker.output/master_datastore_index.log \
        -o maker/pass2/genome.maker.pass2

<br />





