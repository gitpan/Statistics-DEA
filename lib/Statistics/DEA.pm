package Statistics::DEA;

use vars qw($VERSION);

$VERSION = '0.01';

use strict;
use warnings;

use Carp;

=head1 NAME

Statistics::DEA - Discontiguous Exponential Averaging

=head1 SYNOPSIS

    use Statistics::DEA;

    my $dea = Statistics::DEA->new($alpha, $max_gap);

    while (($data, $time) = some_data_source(...)) {
      ...
      $dea->update($data, $time);
      print $dea->average(), "\n";
      print $dea->standard_deviation(), "\n";
      print $dea->completeness($time), "\n";
      ...
   }

=head1 DESCRIPTION

The Statistics::DEA module can be used to compute exponentially
decaying averages even when the data has gaps.  The algorithm also
avoids initial value bias and postgap bias.

=head2 new

    my $dea = Statistics::DEA->new($alpha, $max_gap);

Creates a new (potentially discontiguous) exponential average object.

The $alpha is the exponential decay of I<data>: from zero (inclusive)
to one (exclusive): the lower values cause the effect of data to decay
more quickly, the higher values cause the effect of data to decay more
slowly.

The $max_gap is the maximum I<time> gap after which the data is
considered lost (decay should bring the average to zero).

=head2 update

    $dea->update($data, $time);

Update the average with new data at a particular point in time.

The time parameter is how you can indicate gaps in the data;
if you don't have gaps in your data, just monotonously increase it,
for example C<$time++>.

=head2 average

    my $avg = $dea->average();

Return the current average.

Functionally equivalent alias avg() is also available.

=head2 standard_deviation

    my $std_dev = $dea->standard_deviation();

Return the current standard deviation.

Functionally equivalent alias std_dev() is also available.

=head2 completeness

    my $completeness = $dea->completeness();

Return the current I<completeness>: how well based the current average
and standard deviation are on actual data.  Any gaps reduce this value.

=head2 alpha

    my $alpha = $dea->alpha();

Return the current exponential decay of data.

    $dea->alpha($alpha);

Set the exponential decay of data.

=head2 max_gap

    my $alpha = $dea->alpha();

Return the current maximum time gap.

    $dea->max_gap($max_gap);

Set the maximum time gap.

=head1 AUTHOR

Jarkko Hietaniemi <jhi@iki.fi>

=head1 ACKNOWLEDGEMENT

The idea and the code is from the September 1998 Doctor Dobb's Journal
Algorithm Alley article "Discontiguous Exponential Averaging" by John
C. Gunther, used with permission.  This is just a Perlification of the
code, all errors in transcription are solely mine.

=cut

sub alpha {
    my $dea = shift;
    $dea->{alpha} = shift if @_;
    $dea->max_weight();
    return $dea->{alpha};
}

sub max_gap {
    my $dea = shift;
    $dea->{max_gap} = shift if @_;
    $dea->max_weight();
    return $dea->{max_gap};
}

sub max_weight {
    my $dea = shift;
    return unless defined $dea->{alpha} && defined $dea->{max_gap};
    $dea->{max_weight} = 1 - $dea->{alpha} ** $dea->{max_gap};
}

sub new {
    my $class = shift;
    croak __PACKAGE__, "::new: need two arguments: alpha, max_gap"
	unless @_ == 2;
    my ($alpha, $max_gap) = @_;
    croak __PACKAGE__, "::new: Not 0 <= alpha $alpha < 1"
	unless 0 <= $alpha && $alpha < 1;
    croak __PACKAGE__, "::new: Not max_gap $max_gap > 0"
	unless $max_gap > 0;
    my $dea = bless {}, $class;
    $dea->{sum_of_weights}              = 0;
    $dea->{sum_of_data}                 = 0;
    $dea->{sum_of_squared_data}         = 0;
    $dea->{previous_time}               = -1e38; # -Infinity
    $dea->alpha($alpha);
    $dea->max_gap($max_gap);
    return $dea;
}

sub update {
    my ($dea, $new_data, $time) = @_;
    croak __PACKAGE__, "::update: Not previous_time $dea->{previous_time} < time $time"
	unless $dea->{previous_time} < $time;
    my $weight_reduction_factor =
	$dea->{alpha} ** ($time - $dea->{previous_time});
    my $new_data_weight_a = 1 - $weight_reduction_factor;
    my $new_data_weight_b = $dea->{max_weight};
    my $new_data_weight =
	$new_data_weight_a < $new_data_weight_b ?
	    $new_data_weight_a : $new_data_weight_b;
    $dea->{sum_of_weights} =
	$weight_reduction_factor * $dea->{sum_of_weights} +
	    $new_data_weight;
    $dea->{sum_of_data} =
	$weight_reduction_factor * $dea->{sum_of_data} +
	    $new_data_weight * $new_data;
    $dea->{sum_of_squared_data} =
	$weight_reduction_factor * $dea->{sum_of_data} +
	    $new_data_weight * $new_data * $new_data;
    $dea->{previous_time} = $time;
}

sub _average {
    my $dea = shift;
    return $dea->{sum_of_data} / $dea->{sum_of_weights};
}

sub average {
    my $dea = shift;
    croak __PACKAGE__, "::average: Not sum_of_weights > 0"
	unless $dea->{sum_of_weights} > 0;
    return $dea->_average();
}

*avg = \&average;

sub standard_deviation {
    my $dea = shift;
    croak __PACKAGE__, "::standard_deviation: Not sum_of_weights > 0"
	unless $dea->{sum_of_weights} > 0;
    my $average = $dea->_average();
    return sqrt($dea->{sum_of_squared_data} / $dea->{sum_of_weights} -
		$average * $average);
}

*std_dev = \&standard_deviation;

sub completeness {
    my $dea = shift;
    croak __PACKAGE__, "::completeness: need one argument: time"
	unless @_ == 1;
    my $time = shift;
    croak __PACKAGE__, "::completeness: Not previous_time $dea->{previous_time} < time $time"
	unless $dea->{previous_time} < $time;
    return
	$dea->{alpha} ** ($time - $dea->{previous_time}) *
	    $dea->{sum_of_weights};
}

1;
