#!perl

use strict;
use warnings;

use Cwd ();
use File::Spec ();
use File::Temp ();
use Test::More;
use lib 't';
use Util;

prep_environment();

my @files = qw( t/text );

my @tests = (
    [ qw/Sue/ ],
    [ qw/boy -i/ ], # case-insensitive is handled correctly with --match
    [ qw/ll+ -Q/ ], # quotemeta        is handled correctly with --match
    [ qw/gon -w/ ], # words            is handled correctly with --match
);

plan tests => @tests + 11;

test_match( @{$_} ) for @tests;

# Giving only the --match argument (and no other args) should not result in an error.
run_ack( '--match', 'Sue' );

# Not giving a regex when piping into ack should result in an error.
my ($stdout, $stderr) = pipe_into_ack_with_stderr( 't/text/4th-of-july.txt', '--perl' );
isnt( get_rc(), 0, 'ack should return an error when piped into without a regex' );
is_empty_array( $stdout, 'ack should return no STDOUT when piped into without a regex' );
is( scalar @{$stderr}, 1, 'ack should return one line of error message when piped into without a regex' ) or diag(explain($stderr));

my $wd      = Cwd::getcwd();
my $tempdir = File::Temp->newdir;
mkdir File::Spec->catdir($tempdir->dirname, 'subdir');

PROJECT_ACKRC_MATCH_FORBIDDEN: {
    my @files = ( File::Spec->rel2abs('t/text/') );
    my @args = qw/ --env /;

    chdir $tempdir->dirname;
    write_file '.ackrc', "--match=question\n";

    my ( $stdout, $stderr ) = run_ack_with_stderr(@args, @files);

    is_empty_array( $stdout );
    is_nonempty_array( $stderr );
    like( $stderr->[0], qr/--match is illegal in project ackrcs/ ) or diag(explain($stderr));

    chdir $wd;
}

HOME_ACKRC_MATCH_PERMITTED: {
    my @files = ( File::Spec->rel2abs('t/text/') );
    my @args = qw/ --env /;

    write_file(File::Spec->catfile($tempdir->dirname, '.ackrc'), "--match=question\n");
    chdir File::Spec->catdir($tempdir->dirname, 'subdir');
    local $ENV{'HOME'} = $tempdir->dirname;

    my ( $stdout, $stderr ) = run_ack_with_stderr(@args, @files);

    is_nonempty_array( $stdout );
    is_empty_array( $stderr );

    chdir $wd;
}

ACKRC_ACKRC_MATCH_PERMITTED: {
    my @files = ( File::Spec->rel2abs('t/text/') );
    my @args = qw/ --env /;

    write_file(File::Spec->catfile($tempdir->dirname, '.ackrc'), "--match=question\n");
    chdir File::Spec->catdir($tempdir->dirname, 'subdir');
    local $ENV{'ACKRC'} = File::Spec->catfile($tempdir->dirname, '.ackrc');

    my ( $stdout, $stderr ) = run_ack_with_stderr(@args, @files);

    is_nonempty_array( $stdout );
    is_empty_array( $stderr );

    chdir $wd;
}
done_testing;

# Call ack normally and compare output to calling with --match regex.
#
# Due to 2 calls to run_ack, this sub runs altogether 3 tests.
sub test_match {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $regex = shift;
    my @args  = @_;

    return subtest "test_match( @args )" => sub {
        my @results_normal = run_ack( @args, $regex, @files );
        my @results_match  = run_ack( @args, @files, '--match', $regex );

        return sets_match( \@results_normal, \@results_match, "Same output for regex '$regex'." );
    };
}
