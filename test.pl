# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..21\n"; }
END {print "not ok 1\n" unless $loaded;}
use Text::BibTeX;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $i = 1;
sub test
{
   my ($result) = @_;

   ++$i;
   print $result ? "ok $i" : "not ok $i", "\n";
}


# First test entry: a normal ("structured") BibTeX entry
$text = <<TEXT;
\@foo { mykey,
  f1 = {hello } # { there},
  f2 = "fancy " # "that!" # foo # 1991,
    }
TEXT

print STDERR "Expect a warning about macro `foo' here:\n";
$entry = new Text::BibTeX::Entry $text;

&test ($entry)

# First, low-level tests: make sure the data structure itself
# looks right
&test ($entry->{'status'});
&test ($entry->{'type'} eq 'foo');
&test ($entry->{'key'} eq 'mykey');
&test (scalar @{$entry->{fields}} == 2);
&test (scalar keys %{$entry->{values}} == 2);
&test ($entry->{values}{f1} eq 'hello there');

# Now the same tests again, but using the object's methods
&test ($entry->parse_ok);
&test ($entry->type eq 'foo');
&test ($entry->key eq 'mykey');
&test ($entry->num_fields == 2);
%values = $entry->values;
&test ((scalar keys %values) == 2);
&test ($entry->value ('f1') eq 'hello there');


# Now let's try it with a macro definition

$macrodef = <<TEXT;
\@string{foo = "foo foo foo"}
TEXT

$entry = new Text::BibTeX::Entry $macrodef;

&test ($entry);
&test ($entry->parse_ok);
&test ($entry->type eq 'string');
&test (! defined $entry->key);
&test ($entry->value ('foo') eq 'foo foo foo');


# now a bogus entry (no key) -- just make sure parse_ok returns false
$text2 = <<TEXT;
\@article{f1 = {hello} # {there},}
TEXT

print STDERR "Expect a syntax error here:\n";
$entry = new Text::BibTeX::Entry $text2;

&test ($entry);
&test (! $entry->parse_ok);
