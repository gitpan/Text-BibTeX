# ----------------------------------------------------------------------
# NAME       : BibFormat.pm
# CLASSES    : Text::BibTeX::BibFormat
# RELATIONS  : sub-class of Text::BibTeX::StructuredEntry
#              super-class of Text::BibTeX::BibEntry
# DESCRIPTION: Provides methods for final output formatting of 
#              bibliographic entries.
# CREATED    : 1997/11/24, GPW
# MODIFIED   : 
# VERSION    : $Id: BibFormat.pm,v 1.11 2000/03/23 02:08:40 greg Exp $
# COPYRIGHT  : Copyright (c) 1997 by Gregory P. Ward.  All rights reserved.
# 
#              This file is part of the Text::BibTeX library.  This is free
#              software; you can redistribute it and/or modify it under the
#              same terms as Perl itself.
# ----------------------------------------------------------------------

package Text::BibTeX::BibFormat;

use Carp;
use strict;
use vars qw(@ISA);

use Text::BibTeX::Name;
use Text::BibTeX::NameFormat;
use Text::BibTeX::Structure;

@ISA = qw(Text::BibTeX::StructuredEntry);

use Text::BibTeX qw(:subs display_list :nameparts :joinmethods);

=head1 NAME

Text::BibTeX::BibFormat - formats bibliography entries

=head1 SYNOPSIS

   # Assuming $entry comes from a database of the 'Bib' structure
   # (i.e., that it's blessed into the BibEntry class, which inherits
   # the format method from BibFormat):
   @blocks = $entry->format;

=head1 DESCRIPTION

The C<Text::BibTeX::BibFormat> class is a base class of
C<Text::BibTeX::BibEntry> for formatting bibliography entries.  It thus
performs the main job of any program that would hope to supplant BibTeX
itself; the other important job (sorting) is handled by its companion
class, C<Text::BibTeX::BibSort>.  

C<BibFormat> (the C<Text::BibTeX> prefix will be dropped for brevity)
pays attention to almost all of the structure options described in
L<Text::BibTeX::Bib>; it only ignores those that cover sorting,
currently just C<sortby>.  In particular, all of the "markup" options
control what language is generated by C<BibFormat>; if none of those
options are set, then it will generate plain, unmarked text.

The only method in C<BibFormat>'s documented interface (so far) is
C<format>.  (The class defines many other methods, but these should not
be necessary to outsiders, so they are undocumented and subject to
change.)

=head1 METHODS

=over 4

=cut

# ----------------------------------------------------------------------
# Ordinary subroutines:

sub connect_words
{
   my ($s1, $s2) = @_;

   return $s1 . ((length ($s2) < 3) ? '~' : ' ') . $s2;
}


# ----------------------------------------------------------------------
# Utility methods (eg. apply a bit of markup to a string or field)

sub markup_field
{
   my ($self, $markup, $field) = @_;

   $markup = $self->structure->get_options ("${markup}_mkup")
      unless (ref $markup eq 'ARRAY' && @$markup == 2);
   croak "${markup}_mkup option not defined"
      unless defined $markup;

   $self->exists ($field)
      ? $markup->[0] . $self->get ($field) . $markup->[1]
      : '';
}


sub markup_string
{
   my ($self, $markup, $string) = @_;

   $markup = $self->structure->get_options ("${markup}_mkup")
      unless (ref $markup eq 'ARRAY' && @$markup == 2);
   croak "${markup}_mkup option not defined"
      unless defined $markup;

   $markup->[0] . $string . $markup->[1];
}


# ----------------------------------------------------------------------
# Formatting methods I: utility methods called by the entry-formatters

sub format_authors
{
   my $self = shift;

   return '' unless $self->exists ('author');
   my @authors = $self->names ('author');
   $self->format_names (\@authors)
}


sub format_editors
{
   my $self = shift;

   # The word used to indicate editorship should be customizable --
   # might want it in another language, or abbreviated, or both.
   return '' unless $self->exists ('editor');
   my @editors = $self->names ('editor');
   my $tackon = (@editors == 1) ? ', editor' : ', editors';
   $self->format_names (\@editors) . $tackon;
}


sub format_names
{
   my ($self, $names) = @_;
   my ($format, $name);

   my ($order, $style) =
      $self->structure->get_options ('nameorder', 'namestyle');
   croak "format_names: bad nameorder option \"$order\""
      unless $order eq 'first' || $order eq 'last';
   croak "format_names: bad namestyle option \"$style\""
      unless $style =~ /^(full|abbrev|nopunct|nospace)$/;

   $order = ($order eq 'first') ? 'fvlj' : 'vljf';
   $format = new Text::BibTeX::NameFormat ($order, ! ($style eq 'full'));

   $format->set_text (&BTN_FIRST, undef, undef, undef, '')
      if $style eq 'nopunct' || $style eq 'nospace';
   $format->set_options (&BTN_FIRST, 1, &BTJ_NOTHING, &BTJ_SPACE)
      if $style eq 'nospace';

   foreach $name (@$names)
   {
      $name = $name->format ($format);
      $name = 'et. al.' if $name eq 'others';
   }

   return $self->markup_string ('name', display_list($names,0));
}   


sub format_atitle
{
   my $self = shift;

   my $lower = $self->structure->get_options ('atitle_lower');
   my $title = $self->get ('title');
   $title = change_case ('t', $title) if $lower;
   $self->markup_string ('atitle', $title);
#   $markup->[0] . $title . $markup->[1];
}


sub format_btitle
{
   my $self = shift;

   $self->markup_field ('btitle', 'title');
#   my $markup = $self->structure->get_options ('btitle_mkup');
#   my $title = $self->get ('title');
#   $markup->[0] . $title . $markup->[1];
}


# sub format_xref_article
# {
#    my $self = shift;

#    # N.B. this assumes that the appropriate fields from the cross-
#    # referenced entry have already been put into the current entry!

#    # XXX hard-coded LaTeX markup here!!!

#    my ($key, $journal, $crossref);
#    $key = $self->get ('key');
#    $journal = $self->get ('journal');
#    $crossref = $self->get ('crossref');
#    if (defined $key)
#    {
#       return "In $key \cite{$crossref}";
#    }
#    else
#    {
#       if (defined $journal)
#       {
#          return "In {\em $journal} \cite{$crossref}";
#       }
#       else
#       {
#          $self->warn ("need key or journal for crossref");
#          return " \cite{$crossref}";
#       }
#    }
# }


sub format_pages
{
   my $self = shift;

   my $pages = $self->get ('pages');
   if ($pages =~ /[,+-]/)               # multiple pages?
   {
      $pages =~ s/([^-])-([^-])/$1--$2/g;
      return connect_words ("pages", $pages);
   }
   else
   {
      return connect_words ("page", $pages);
   }
}


sub format_vol_num_pages
{
   my $self = shift;

   my ($vol, $num, $pages) = $self->get ('volume', 'number', 'pages');
   my $vnp = '';
   $vnp .= $vol if defined $vol;
   $vnp .= "($num)" if defined $num;
   $vnp .= ":$pages" if defined $pages;
   return $vnp;
}


sub format_bvolume
{
   my $self = shift;
   my $volser;                          # potentially volume and series

   if ($self->exists ('volume'))
   {
      $volser = connect_words ('volume', $self->get ('volume'));
      $volser .= ' of ' . $self->markup_field ('btitle', 'series')
         if $self->exists ('series');
      return $volser;
   }
   else
   {
      return '';
   }
}


sub format_number_series
{
   my ($self, $mid_sentence) = @_;

   if ($self->exists ('volume'))
   {
      # if 'volume' field exists, then format_bvolume took care of
      # formatting it, so don't do anything here
      return '';
   }
   else
   {
      if ($self->exists ('number'))
      {
         my $numser;

         $numser = connect_words ($mid_sentence ? 'number' : 'Number',
                                  $self->get ('number'));
         if ($self->exists ('series'))
         {
            $numser .= ' in ' . $self->get ('series');
         }
         else
         {
            $self->warn ("there's a number but no series " .
                         "(is this warning redundant?!?)");
         }
         return $numser;
      }
      else
      {
         # No 'number' -- just return the 'series' (or undef if none)
         return $self->get ('series');
      }
   }  # no 'volume' field
}  # format_number_series


sub format_edition
{
   my ($self, $mid_sentence) = @_;

   # XXX more fodder for I18N here: the word 'edition'
   return '' unless $self->exists ('edition');
   my $case_transform = $mid_sentence ? 'l' : 't';
   return change_case ($case_transform, $self->get ('edition')) . ' edition';

}  # format_edition


sub format_date
{
   my $self = shift;

   my @date = grep ($_, $self->get ('month', 'year'));
   return join (' ', @date);
}


# ----------------------------------------------------------------------
# The actual entry-formatting methods:
#   format_article
#   format_book
#   format_inbook
#   ...and so on.

# Each of these returns a list of blocks.
# A block is a list of sentences.
# A sentence is either a string or a list of clauses.
# Any clause, sentence, or block in any list may be empty or undefined;
#   it should be removed before output.
# If a sentence consists of a list of clauses, they should be joined 
#   together with ", " to form the sentence-as-string.
#
# For example, the formatted entry for an article (in the absence of
# cross-references) consists of four blocks:
#   - the name block, which has a single sentence; this sentence 
#     has a single clause (the list of author names), and thus is
#     represented as a string like "Joe Blow, Fred Jones, and John Smith"
#   - the title block, which has a single sentence; this sentence 
#     has a single clause, the title of the article, eg. "The mating 
#     habits of foobars"
#   - the journal block, which consists of a single sentence that has
#     three clauses: the journal name, the volume/number/pages, and
#     the date.  When the three clauses are joined, we get something like
#     "Journal of Foo, 4(5):122--130, May 1996" for the single sentence
#     in the block.
#   - the note block -- if the entry has no `note' field, this block
#     will be an undefined value rather than a list of sentences
#
# These four blocks are returned from `format_article' (and thus from
# `format') as a list-of-lists-of-(strings or lists-of-strings.  That
# is, each format methods returns a list of blocks, each of which is in
# turn a list of sentences.  (Hence "list of lists of X".)  Each
# sentence is either a string ("list of lists of strings") or a list of
# clauses ("list of lists of lists of strings').  Clear?  Hope so!
#
#   [                                           # enter list of blocks
#    ["Joe Blow, Fred Jones, and John Smith"]   # name block:
#                                               # 1 sentence w/ 1 clause
#    ["The mating habits of foobars"]           # title block:
#                                               # 1 sentence w/ 1 clause
#    [["Journal of Foo",                        # journal block:
#      "4(5):122--130",                         # 1 sentence w/ 3 clauses
#      "May 1996"]]
#    undef
#   ]
#
# A note: the journal name will normally have a bit of markup around it,
# say to italicize it -- that's determined by the calling application,
# though; the default markups are all empty strings.  There could
# probably be arbitrary markup for every element of an entry, but I
# haven't gone that far yet.
# 
# It is then the responsibility of the calling application to apply the
# appropriate punctuation and munge all those lists of strings together
# into something worth printing.  The canonical application for doing
# this is btformat, which supports LaTeX 2.09, LaTeX2e, and HTML markup
# and output.


sub format_article
{
   my $self = shift;


   my $name_block = [$self->format_authors];
   my $title_block = [$self->format_atitle];
   my $journal_block = [[$self->markup_string('journal', $self->get ('journal')),
                         $self->format_vol_num_pages,
                         $self->format_date]];

#    if ($self->exists ('crossref'))
#    {
#       push (@blocks, [[$self->format_xref_article,
#                       $self->format_pages]]);
#    }
#    else
#    {
#    }

#    push (@blocks, [$self->get ('note')]) if $self->exists ('note');
#    @blocks;

   ($name_block, $title_block, $journal_block, $self->get ('note'));
}  # format_article


sub format_book
{
   my $self = shift;

   my $name_block =                     # author(s) or editor(s)
      ($self->exists ('author'))
         ? [$self->format_authors]
         : [$self->format_editors];
   my $title_block =                    # title (and volume)
      [[$self->format_btitle, $self->format_bvolume]];
   my $from_block =                     # number/series; publisher, address,
      [$self->format_number_series (0), # edition, date
       [$self->get ('publisher'), $self->get ('address'),
        $self->format_edition (0), $self->format_date]];

   ($name_block, $title_block, $from_block, $self->get('note'));

}  # format_book


# ----------------------------------------------------------------------
# Finally, the `format' method -- just calls one of the
# type-specific format methods (format_article, etc.)

=item format ()

Formats a single entry for inclusion in the bibliography of some
document.  The exact processing performed is highly dependent on the
entry type and the fields present; in general, you should be able to
join C<format>'s outputs together to create a single paragraph for
inclusion in a document of whatever markup language you're working with.

Returns a list of "blocks," which can either be jammed together like
sentences (for a traditional "tight" bibliography) or printed on
separate lines (for an "open" bibliography format).  Each block is a
reference to a list of sentences; sentences should be joined together
with an intervening period.  Each sentence is either a single string or
a list of clauses; clauses should be joined together with an intervening
comma.  Each clause is just a simple string.

See the source code for C<btformat> for an example of how to use the
output of C<format>.

=cut

sub format
{
   my $self = shift;

   my $type = $self->type;
   my $key = $self->key;
   my $method_name = 'format_' . $type;
   my $method = $self->can ($method_name);
   unless ($method)
   {
      $self->warn ("can't format entry: " .
                   "no method $method_name (for type $type)");
      return;
   }
      
   return &$method ($self);
}

1;

=back

=head1 SEE ALSO

L<Text::BibTeX::Structure>, L<Text::BibTeX::Bib>,
L<Text::BibTeX::BibSort>

=head1 AUTHOR

Greg Ward <gward@python.net>

=head1 COPYRIGHT

Copyright (c) 1997-2000 by Gregory P. Ward.  All rights reserved.  This file
is part of the Text::BibTeX library.  This library is free software; you
may redistribute it and/or modify it under the same terms as Perl itself.
