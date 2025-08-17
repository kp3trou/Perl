#!/usr/bin/perl
use strict;
use warnings;


# filename of the judjes test
#my $filename = 'qrels.text_parsed4';

my $filename = 'qrels.text_parsed_2';

my @krites_ ; # array of array ref

open (FH,'<', $filename) or die $!;

while (<FH>) {
	#print $_;
	$_ =~ /^(\d+)\s+(\d+)/ ;
	#print $1,"\n";
	#print $2 ,"\n";
	my $key = $1;
	my $value = $2;
	$krites_[$key] //= [];
	push @{$krites_[$key]},$value;
}

close (FH);

my @tempkr;

foreach (@krites_){
	next unless $_;
	push @tempkr,$_;
	#print  join (',', @$_),"\n";
}

my $krit = [@tempkr]; # array ref of array references

#my $krit = [[1410,1572,1605,2020,2358],[1410,1572,1605,2020,2358]];

# filename of the lucene output results
#my $filename2 = 'output_lucene_results_parsed2';

#my $filename2 = 'lucene_output_results_parsed';

my $filename2 = 'lucene_output_tf_idf';

# file names parsed for precision and recall
#lucene_output_bm25
#lucene_output_LMDirichletSimilarity
#lucene_output_LMJelinekMercerSimilarity
#lucene_output_tf_idf

my @eng_ ; # array of array ref

open (FH,'<', $filename2) or die $!;

while (<FH>) {
	#print $_;
	$_ =~ /^(\d+)\s+(\d+)/ ;
	#print $1,"\n";
	#print $2 ,"\n";
	my $key = $1;
	my $value = $2;
	$eng_[$key] //= [];
	push @{$eng_[$key]},$value;
}

close (FH);

my @tempeng;

foreach (@eng_){

	next unless $_;
	push @tempeng,$_;
	#print join (',', @$_),"\n";
	
}

my $eng = [@tempeng]; # array ref of array references

#my $eng = [[2319,1410,1938,1572,1680,1391,1605,971,2317,2424],[2319,1410,1938,1572,1680,1391,1605,971,2317,2424]];

my $tp_fn2;

my $tp_fp2;

my $tp2;

my @fpr = ();

for (my $i = 0; $i < scalar(@$eng); $i++ ){
	my $retrieved = @$eng[$i]; 
	my $relevant = @$krit[$i];
	$tp_fn2 = scalar(@$relevant);
	$tp_fp2 = 0;
	$tp2 = 0;
	my @rec = ();
	my @prec = ();
	my @final = ();
	foreach my $v (@$retrieved) {
		$tp_fp2 += 1;
		$tp2 += find ($v,@$relevant);
		push (@prec,precision_recall($tp2,$tp_fp2)); # precision calculation
		push (@rec,precision_recall($tp2,$tp_fn2));  # recall calculation
	}
	
	push(@final,[@rec]);
	push(@final,[@prec]);
	push(@fpr,[@final]);
}

#             [recall],[precision] 
#my @fpr = ([ [r],[p] ],[ [r],[p] ] );

#print @fpr,"\n";


# Sort and reorganize for each pair of sub-arrays
my @sorted_fpr = map {
	# Extract the first and second sub-arrays
	my ($first, $second) = @$_;

	# Create a list of indices sorted by the first sub-array
	my @indices = sort { $first->[$a] <=> $first->[$b] } (0 .. $#$first);

	# Sort the first array based on indices
	my @sorted_first = @{$first}[@indices];

	# Reorder the second array based on the same indices
	my @reordered_second = @{$second}[@indices];

	# Return the sorted and reordered pair
	[\@sorted_first, \@reordered_second];
} @fpr;



print "\e[32m--------------------\e[0m\n";

my $i = 0;
foreach(@sorted_fpr){
	$i +=1;
	print "query : $i\n";
	#print $_,"\n";
	foreach my $q(@$_){
		print "q : @$q\n"; # as output : recall, precision, recall , precision, ....
	}
}

###################
#Solution for the previous array @sorted_fpr and the make : normalization and average for all the precision points per recall steps. 

# Input array with multiple queries
=pod
my @sorted_fpr = (
    [
        [0.3, 0.3, 0.7, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0], # Query 1 x-axis
        [1.0, 0.5, 0.7, 0.8, 0.6, 0.5, 0.4, 0.4, 0.3, 0.3]  # Query 1 y-axis
    ],
    [
        [0.0, 0.2, 0.2, 0.4, 0.4, 0.4, 0.6, 0.6, 0.6, 0.6], # Query 2 x-axis
        [0.0, 0.5, 0.3, 0.5, 0.4, 0.3, 0.4, 0.4, 0.3, 0.3]  # Query 2 y-axis
    ]
);
=cut


# Step size
my $step_size = 0.1;

# Calculate the points (step, max_y) for each query
my @query_outputs;

foreach my $query_index (0 .. $#sorted_fpr) {
    my $x_axis = $sorted_fpr[$query_index][0];
    my $y_axis = $sorted_fpr[$query_index][1];

   
    # Validate the input structure
    if (!@$x_axis || !@$y_axis || scalar(@$x_axis) != scalar(@$y_axis)) {
        die "Invalid input for query $query_index: x-axis and y-axis arrays must have the same length.\n";
    }

    # Output for this query
    my @output;

    # Loop from 0.0 to 1.0 in steps of $step_size
    for (my $step = 0.0; $step <= 1.0; $step += $step_size) {
        my $max_y = 0; # Initialize maximum y-value for the current step

        # Find the maximum y for the current step
        for my $i (0 .. $#$x_axis) {
            if ($x_axis->[$i] >= $step) {
                $max_y = $y_axis->[$i] if $y_axis->[$i] > $max_y;
            }
        }

        # Store the result for this step
        push @output, [$step, $max_y];
    }

    # Store the output for this query
    push @query_outputs, \@output;
}

# Aggregate results across all queries
my @aggregated_output;

# Loop through each step (0.0 to 1.0)
for (my $step = 0.0; $step <= 1.0; $step += $step_size) {
    my @y_values;

    # Collect the y-axis values for this step from all queries
    foreach my $query_output (@query_outputs) {
        foreach my $point (@$query_output) {
            if (sprintf("%.1f", $point->[0]) == sprintf("%.1f", $step)) {
                push @y_values, $point->[1];
            }
        }
    }

    # Calculate the average of the y-axis values for this step
    my $sum = 0;
    $sum += $_ for @y_values;
    my $average = @y_values ? $sum / @y_values : 0;

    # Store the aggregated point
    push @aggregated_output, [$step, $average];
}

# Print the aggregated results
print "\nAggregated Results: $filename2 \n";
foreach my $point (@aggregated_output) {
    printf "(%.1f, %.1f)\n", $point->[0], $point->[1];
}


###################


sub precision_recall {
	my ($a, $b) = @_;
	#print $a,"/","$b","\n";
	return sprintf("%.1f",($a/$b));	
}

sub find {
	my @params = @_;
	my $val = shift(@params);
	#print "val : ", $val,"\n";
	#print join(',',@params),"\n";
	foreach (@params){
		if ($val eq $_){
			#print "found\n";
			#print $val,"\n";
			return 1;
		}
	}
	return 0;
}


