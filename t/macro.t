use strict;
use IO::Handle;
BEGIN { require "t/common.pl"; }

my $loaded;
BEGIN { $| = 1; print "1..18\n"; }
END {print "not ok 1\n" unless $loaded;}
use Text::BibTeX;
$loaded = 1;
print "ok 1\n";

setup_stderr;

# ----------------------------------------------------------------------
# test macro parsing and expansion

my ($macrodef, $regular, $entry, @warnings);

$macrodef = <<'TEXT';
@string ( foo = "  The Foo
  Journal",  
        sons  = " \& Sons",
    bar 
=    {Bar   } # sons,

)
TEXT

$regular = <<'TEXT';
@article { my_article, 
            author = { Us and Them },
            journal = foo,
            publisher = "Fu" # bar 
          }
TEXT

# NB. macro values as returned by the XS code are fully processed; what's
# inserted into *other* values (by the C library) are correctly 
# under-processed (no whitespace collapsing), though.
$entry = new Text::BibTeX::Entry;
$entry->parse_s ($macrodef);
test (! warnings);
test_entry ($entry, 'string', undef, 
            [qw(foo sons bar)],
            ['The Foo Journal', '\& Sons', 'Bar \& Sons']);

# calling a parse or read method on an existing object isn't documented
# as an "ok thing to do", but it is (at least as the XS code currently
# is!) -- hence I can leave the "new" uncommented
# $entry = new Text::BibTeX::Entry;
$entry->parse_s ($regular);
test (! warnings);
test_entry ($entry, 'article', 'my_article',
            [qw(author journal publisher)],
            ['Us and Them', 'The Foo Journal', 'FuBar \& Sons']);

