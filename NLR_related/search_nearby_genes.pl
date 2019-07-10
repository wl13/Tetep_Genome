#!/usr/bin/perl -w
#
#   search_nearby_genes.pl -- Get nearby genes according to physical chromosome location.
#                          
#
#   Author: Nowind
#   Created: 2012-05-31
#   Updated: 2019-03-07
#   Version: 1.0.0
#
#   Change logs:
#   Version 1.0.0 19/03/07: The initial version.



use strict;

use Data::Dumper;
use Getopt::Long;
use File::Find::Rule;
use File::Basename;

use MyPerl::FileIO qw(:all);

######################## Main ########################


my $CMDLINE = "perl $0 @ARGV";
my $VERSION = '1.0.0';
my $HEADER  = "##$CMDLINE\n##Version: $VERSION\n";


my $max_sep_gene = 0;
my ($input_file, @rows, $output);
GetOptions(
            "input=s"             => \$input_file,
            "rows=i{,}"           => \@rows,
            
            "output=s"            => \$output,
            
            "max-include=i"       => \$max_sep_gene,
           );

unless( $input_file ) {
    print <<EOF;

$0  -- Search for gene clusters

Version: $VERSION

Usage:   perl $0 [options]

Options:
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
    
EOF

    exit(1);
}

$|++;

if ($output) {
    open (STDOUT, "> $output") || die $!;
}


unless(scalar @rows > 3){ @rows = qw(0 1 2 3) };



print STDERR "# $0 v$VERSION\n# " . (scalar localtime()) . "\n";

print STDOUT "$HEADER##" . (scalar localtime()) . "\n";


print STDERR ">> Start parsing $input_file ... ";
mark_nearby_genes($input_file);
print STDERR "done!\n";


print STDERR "# " . (scalar localtime()) . "\n";

######################### Sub #########################


=head2 mark_nearby_genes

    About   : Mark nearby genes.
    Usage   : mark_nearby_genes($file);
    Args    : File contains ordered genes.
    Returns : Null
    
=cut
sub mark_nearby_genes
{
    my ($in) = @_;
    
    my %gene_orders = ();
    my %gene_strand = ();
    
    my $fh = getInputFilehandle($in);    
    while (<$fh>)
    {
        next if (/^\#/ || /^\s+$/);

        my ($gene_id, $chrom, $order, $strand) = (split /\s+/)[@rows];
        
        $gene_orders{$chrom}->{$gene_id} = $order;
        $gene_strand{$chrom}->{$gene_id} = $strand;
    }
    
    print STDOUT "#gene1_id\tgene2_id\tchrom\tgene1_order\tgene2_order\tgene1_strand"
               . "\tgene2_strand\tseperated_numbers\torientation\n";
    for my $chrom (sort keys %gene_orders)
    {
        ###if ((keys %{$gene_orders{$chrom}}) <= 1) {
        ###    print STDERR Dumper($gene_orders{$chrom});next;
        ###}
        
        my @genes_sorted = sort {$gene_orders{$chrom}->{$a} <=>
                                 $gene_orders{$chrom}->{$b}} keys %{$gene_orders{$chrom}};
        
        for (my $i=1; $i<=$#genes_sorted; $i++)
        {
            my $prev_gene_order = $gene_orders{$chrom}->{$genes_sorted[$i-1]};
            my $curr_gene_order = $gene_orders{$chrom}->{$genes_sorted[$i]};
            
            my $sep_genes = $curr_gene_order - $prev_gene_order - 1;
            
            my $prev_gene_strand = $gene_strand{$chrom}->{$genes_sorted[$i-1]};
            my $curr_gene_strand = $gene_strand{$chrom}->{$genes_sorted[$i]};
            
            my $orient = ($prev_gene_strand eq "-" && $curr_gene_strand eq "+") ? "head2head" : "non-head2head";
            
            if ($sep_genes <= $max_sep_gene) {
                
                print STDOUT "$genes_sorted[$i-1]\t$genes_sorted[$i]\t$chrom\t$prev_gene_order\t$curr_gene_order\t$prev_gene_strand"
                           . "\t$curr_gene_strand\t$sep_genes\t$orient\n";
            }
            else {
                
            }
        }
    }
}

