use strict;
use vars qw($DEBUG);
use IO::Handle;
BEGIN { require "t/common.pl"; }

my $loaded;
BEGIN { $| = 1; print "1..62\n"; }
END {print "not ok 1\n" unless $loaded;}
use Text::BibTeX;
$loaded = 1;
print "ok 1\n";

$DEBUG = 0;

setup_stderr;

sub test_name
{
   my ($name, $components) = @_;
   my $ok = 1;
   my @parts = qw(first von last jr);
   my $i;

   for $i (0 .. $#parts)
   {
      $ok &= (defined $components->[$i])
         ? (defined $name->{$parts[$i]}) && 
            slist_equal ($components->[$i], $name->{$parts[$i]})
         : (! defined $name->{$parts[$i]});
   }

   test (keys %$name <= 4 && $ok);
}


# ----------------------------------------------------------------------
# processing of author names

my (@names, %names, @orig_namelist, $namelist, @namelist);
my ($text, $entry);

@names =
   ('J. Smith and N. D. Andrews' => ['J. Smith', 'N. D. Andrews'],
    'J. Smith and A. Jones' => ['J. Smith', 'A. Jones'],
    'J. Smith and A. Jones and J. Random' => ['J. Smith', 'A. Jones', 'J. Random'],
    'A. Smith and J. Jones' => ['A. Smith', 'J. Jones'],
    'A. Smith and A. Jones' => ['A. Smith', 'A. Jones'],
    'Amy Smith and Andrew Jones' => ['Amy Smith', 'Andrew Jones'],
    'Amy Smith and And y Jones' => ['Amy Smith', undef, 'y Jones'],
    'K. Herterich and S. Determann and B. Grieger and I. Hansen and P. Helbig and S. Lorenz and A. Manschke' => ['K. Herterich', 'S. Determann', 'B. Grieger', 'I. Hansen', 'P. Helbig', 'S. Lorenz', 'A. Manschke'],
    'A. Manschke and M. Matthies and A. Paul and R. Schlotte and U. Wyputta' => ['A. Manschke', 'M. Matthies', 'A. Paul', 'R. Schlotte', 'U. Wyputta'],
    'S. Lorenz and A. Manschke and M. Matthies' => ['S. Lorenz', 'A. Manschke', 'M. Matthies'],
    'K. Herterich and S. Determann and B. Grieger and I. Hansen and P. Helbig and S. Lorenz and A. Manschke and M. Matthies and A. Paul and R. Schlotte and U. Wyputta' => ['K. Herterich', 'S. Determann', 'B. Grieger', 'I. Hansen', 'P. Helbig', 'S. Lorenz', 'A. Manschke', 'M. Matthies', 'A. Paul', 'R. Schlotte', 'U. Wyputta'],
   );

while (@names)
{
   my ($name, $should_split) = (shift @names, shift @names);
   my $actual_split = [Text::BibTeX::split_list ($name, 'and')];

   if ($DEBUG)
   {
      printf "name = >%s<\n", $name;
      print "should split to:\n  ";
      print join ("\n  ", @$should_split) . "\n";
      print "actually split to:\n  ";
      print join ("\n  ", @$actual_split) . "\n";
   }

   test (slist_equal ($should_split, $actual_split));
}

# first just a big ol' list of names, not attached to any entry
%names =
 ('van der Graaf'          => '|van+der|Graaf|',
  'Jones'                  => '||Jones|',
  'van'                    => '||van|',
  'John Smith'             => 'John||Smith|',
  'John van Smith'         => 'John|van|Smith|',
  'John van Smith Jr.'     => 'John|van|Smith+Jr.|',
  'John Smith Jr.'         => 'John+Smith||Jr.|',
  'John van'               => 'John||van|',
  'John van der'           => 'John|van|der|',
  'John van der Graaf'     => 'John|van+der|Graaf|',
  'John van der Graaf foo' => 'John|van+der|Graaf+foo|',
  'foo Foo foo'            => '|foo|Foo+foo|',
  'Foo foo'                => 'Foo||foo|',
  'foo Foo'                => '|foo|Foo|'
 );
          
@orig_namelist = keys %names;
$namelist = join (' and ', @orig_namelist);
@namelist = Text::BibTeX::split_list
   ($namelist, 'and', 'test', 0, 'name');
test (slist_equal (\@orig_namelist, \@namelist));

my $i;
foreach $i (0 .. $#namelist)
{
   test ($namelist[$i] eq $orig_namelist[$i]);
   my $comp = Text::BibTeX::split_name ($namelist[$i], 'test', 0, $i);
   test (keys %$comp <= 4);

   my @name = map { join ('+', ref $_ ? @$_ : ()) }
                  @$comp{'first','von','last','jr'};
   test (join ('|', @name) eq $names{$orig_namelist[$i]});

}

# now an entry with some names in it

$text = <<'TEXT';
@article{homer97,
  author = {  Homer  Simpson    and
              Flanders, Jr.,    Ned Q. and
              {Foo  Bar and Co.}},
  title = {Territorial Imperatives in Modern Suburbia},
  journal = {Journal of Suburban Studies},
  year = 1997
}
TEXT

test ($entry = new Text::BibTeX::Entry $text);
my $author = $entry->get ('author');
test ($author
      eq 'Homer Simpson and Flanders, Jr., Ned Q. and {Foo Bar and Co.}');
@names = $entry->split ('author');
test (@names == 3 &&
      $names[0] eq 'Homer Simpson' &&
      $names[1] eq 'Flanders, Jr., Ned Q.' &&
      $names[2] eq '{Foo Bar and Co.}');
@names = $entry->names ('author');
test (@names == 3);
test_name ($names[0], [['Homer'], undef, ['Simpson'], undef]);
test_name ($names[1], [['Ned', 'Q.'], undef, ['Flanders'], ['Jr.']]);
test_name ($names[2], [undef, undef, ['{Foo Bar and Co.}']]);
