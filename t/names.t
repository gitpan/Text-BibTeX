use strict;
use IO::Handle;
BEGIN { require "t/common.pl"; }

my $loaded;
BEGIN { $| = 1; print "1..51\n"; }
END {print "not ok 1\n" unless $loaded;}
use Text::BibTeX;
$loaded = 1;
print "ok 1\n";

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

my (%names, @orig_namelist, $namelist, @namelist);

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
my ($text, $entry, @names);

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
