

## Predict NLR regions in the genome using NLR-Annotator (https://github.com/steuernb/NLR-Annotator)


### Step1: Chopping sequences
    java -jar NLR-Annotator/ChopSequence.jar \
        -i genome.fasta \
        -o genome.w20s5.fasta \
        -l 20000 -p 5000


### Step2: run NLR-Parser
    java -jar NLR-Annotator/NLR-Parser.jar \
        -t 2 -y /bin/mast \
        -x NLR-Annotator/meme.xml \
        -i genome.w20s5.fasta \
        -c genome.w20s5.nlr.xml


### Step3: run NLR-Annotator
    java -jar NLR-Annotator/NLR-Annotator.jar \
        -i genome.w20s5.nlr.xml \
        -o genome.w20s5.nlr.txt


