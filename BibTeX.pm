package Text::BibTeX;

# ----------------------------------------------------------------------
# NAME       : BibTeX.pm
# DESCRIPTION: Code for the Text::BibTeX module; loads up everything 
#              needed for parsing BibTeX files (both Perl and C code).
# CREATED    : February 1997, Greg Ward
# MODIFIED   : 
# VERSION    : $Id: BibTeX.pm,v 1.8 1997/10/06 01:28:35 greg Exp $
# ----------------------------------------------------------------------


# BEGIN { print "compiling Text::BibTeX\n"; }

require 5.003;

=head1 NAME

Text::BibTeX - interface to read and parse BibTeX files

=head1 SYNOPSIS

   use Text::BibTeX;

   $bibfile = new Text::BibTeX::File "foo.bib";
   $newfile = new Text::BibTeX::File ">newfoo.bib";

   while ($entry = new Text::BibTeX::Entry $bibfile)
   {
      next unless $entry->parse_ok;

         .             # hack on $entry contents, using various
         .             # Text::BibTeX::Entry methods
         .

      $entry->write ($newfile);
   }

=head1 DESCRIPTION

C<Text::BibTeX> is just used to load the C<Text::BibTeX::File> and
C<Text::BibTeX::Entry> modules, which are the ones that do all the real
work (i.e., reading and parsing BibTeX files).  (You shouldn't try to load
C<Text::BibTeX::Entry> on its own, though, because C<Text::BibTeX> also
loads the C code needed for parsing BibTeX files.)  

The above synopsis shows one general approach for reading/parsing/writing
BibTeX files; see L<Text::BibTeX::File> and L<Text::BibTeX::Entry> for full
details on those two modules and their methods.

=cut

# BEGIN { print "setting up\n"; }

use strict;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $AUTOLOAD);

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);
%EXPORT_TAGS = (nodetypes => [qw(BTAST_STRING BTAST_MACRO BTAST_NUMBER)],
                metatypes => [qw(BTE_UNKNOWN BTE_REGULAR BTE_COMMENT 
                                 BTE_PREAMBLE BTE_MACRODEF)],
                subs      => [qw(bibloop split_list split_name)]);
@EXPORT_OK = (@{$EXPORT_TAGS{'subs'}}, @{$EXPORT_TAGS{'nodetypes'}});
@EXPORT = @{$EXPORT_TAGS{'metatypes'}};
$VERSION = '0.21';

sub AUTOLOAD
{
   # This AUTOLOAD is used to 'autoload' constants from the constant()
   # XS function.

#   print "AUTOLOAD: \$AUTOLOAD=$AUTOLOAD\n";

   my ($constname, $ok, $val);
   ($constname = $AUTOLOAD) =~ s/.*:://;
   carp ("Recursive AUTOLOAD--probable compilation error"), return
      if $constname eq 'constant';
   $val = constant ($constname)
      if $constname =~ /^BT/;
   croak ("Unknown Text::BibTeX function: \"$constname\"")
      unless (defined $val);
   
#   print "          constant ($constname) returned \"$val\"\n";

   eval "sub $AUTOLOAD { $val }";
   $val;
}

# BEGIN { print "loading helpers\n"; }
require Text::BibTeX::File;
require Text::BibTeX::Entry;

# BEGIN { print "bootstrapping\n"; }
bootstrap Text::BibTeX $VERSION;

# For the curious: I don't put the call to &initialize into a BEGIN block,
# because then it would come before the bootstrap above, and &initialize is
# XS code -- bad!  (The manifestation of this error is rather interesting:
# Perl calls my AUTOLOAD routine, which then tries to call `constant', but
# that's also an as-yet-unloaded XS routine, so it falls back to AUTOLOAD,
# which tries to call `constant' again, ad infinitum.  The moral of the
# story: beware of what you put in BEGIN blocks in XS-dependent modules!)

&initialize;                            # these are both XS functions
END { &cleanup; }

sub bibloop # (&$;$$)
{
   my ($body, $files, $dest, $extra_args) = @_;

   croak ("extra_args must be an array ref if given")
      if defined $extra_args && !ref $extra_args eq 'ARRAY';
   my @extra_args = (defined $extra_args) ? (@$extra_args) : ();

   my $file;
   while ($file = shift @$files)
   {
      my $bib = new Text::BibTeX::File $file;
      
      while (! $bib->eof())
      {
         my $entry = new Text::BibTeX::Entry $bib;
         next unless $entry->parse_ok;
#         $entry->get ($bib);

         # N.B. if I change the Entry structure to include a ref to
         # the associated Text::BibTeX::file, then the body doesn't
         # need to be passed a filename.  (Even better if I add
         # a `warn' method to Text::BibTeX::Entry, so caller doesn't
         # have to know about filename/line number at all.)

#         my $result = &$body ($bib->{'filename'}, $entry, @extra_args);
         my $result = &$body ($entry, @extra_args);
         $entry->write ($dest, 1)
            if ($result && $dest)
      }
   }
}

1;


__END__

=head1 BUGS AND LIMITATIONS

How to deal with macro definitions (C<@string> entries) from the Perl
programmer's point of view is still a little fuzzy (and undocumented).
Currently, macro expansions are stored in a hash table by the underlying C
library, macros are expanded when entries are parsed.  Macro expansion
values are not yet available to Perl code.

=head1 AUTHOR

Greg Ward <greg@bic.mni.mcgill.ca>

=head1 COPYRIGHT

Copyright (c) 1997 by Gregory P. Ward.  All rights reserved.  This is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself.

=head1 AVAILABILITY

The latest version of Text::BibTeX should be available from

   ftp://ftp.bic.mni.mcgill.ca/pub/users/greg/

in Text-BibTeX-x.y.tar.gz, where x.y is the version number.  You will
also find the latest version of btparse, the C library underlying
Text::BibTeX, at that location.  It's not strictly necessary to get this
separately, as the entire btparse distribution is currently included
with Text::BibTeX.  However, you might mention this to C programmers
looking for a BibTeX solution, or indeed to anyone who could use a C
solution to bind to high-level languages other than Perl.  Also, in the
future, I may include with Text::BibTeX only enough of btparse to build
Text::BibTeX itself, in which case it could become useful to get the
separate btparse distribution (eg. for documentation or examples).

=cut
