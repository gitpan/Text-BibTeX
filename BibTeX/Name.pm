# ----------------------------------------------------------------------
# NAME       : BibTeX/Name.pm
# CLASSES    : Text::BibTeX::Name
# RELATIONS  : 
# DESCRIPTION: Provides an object-oriented interface to the BibTeX-
#              style author names (parsing them, that is; formatting
#              them is done by the Text::BibTeX::NameFormat class).
# CREATED    : Nov 1997, Greg Ward
# MODIFIED   : 
# VERSION    : $Id: Name.pm,v 1.6 1999/03/11 04:54:06 greg Exp $
# COPYRIGHT  : Copyright (c) 1997-98 by Gregory P. Ward.  All rights
#              reserved.
# 
#              This file is part of the Text::BibTeX library.  This
#              library is free software; you may redistribute it and/or
#              modify it under the same terms as Perl itself.
# ----------------------------------------------------------------------

package Text::BibTeX::Name;

require 5.004;

use strict;
use Carp;

=head1 NAME

Text::BibTeX::Name - interface to BibTeX-style author names

=head1 SYNOPSIS

   $name = new Text::BibTeX::Name;
   $name->split('J. Random Hacker');
   # or:
   $name = new Text::BibTeX::Name ('J. Random Hacker');

   @firstname_tokens = $name->part ('first');
   $lastname = join (' ', $name->part ('last'));

   $format = new Text::BibTeX::NameFormat;
   # ...customize $format...
   $formatted = $name->format ($format);

=head1 DESCRIPTION

F<Text::BibTeX::Name> provides an abstraction for BibTeX-style names and
some basic operations on them.  A name, in the BibTeX world, consists of
a list of I<tokens> which are divided amongst four I<parts>: `first',
`von', `last', and `jr'.

Tokens are separated by whitespace or commas at brace-level zero.  Thus
the name

   van der Graaf, Horace Q.

has five tokens, whereas the name

   {Foo, Bar, and Sons}

consists of a single token.

How tokens are divided into parts depends on the form of the name.  If
the name has no commas at brace-level zero (as in the second example),
then it is assumed to be in either "first last" or "first von last"
form.  If there are no tokens that start with a lower-case letter, then
"first last" form is assumed: the final token is the last name, and all
other tokens form the first name.  Otherwise, the earliest contiguous
sequence of tokens with initial lower-case letters is taken as the `von'
part; if this sequence includes the final token, then a warning is
printed and the final token is forced to be the `last' part.

If a name has a single comma, then it is assumed to be in "von last,
first" form.  A leading sequence of tokens with initial lower-case
letters, if any, forms the `von' part; tokens between the `von' and the
comma form the `last' part; tokens following the comma form the `first'
part.  Again, if there are no token following a leading sequence of
lowercase tokens, a warning is printed and the token immediately
preceding the comma is taken to be the `last' part.

If a name has more than two commas, a warning is printed and the name is
treated as though only the first two commas were present.

Finally, if a name has two commas, it is assumed to be in "von last, jr,
first" form.  (This is the only way to represent a name with a `jr'
part.)  The parsing of the name is the same as for a one-comma name,
except that tokens between the two commas are taken to be the `jr' part.

=head1 EXAMPLES

The names C<'van der Graaf, Horace Q.'> and 
C<'Horace Q. van der Graaf'> split into identical sets of token lists:

   first => ('Horace', 'Q.')
   von   => ('van', 'der')
   last  => ('Graaf')

with no `jr' part.

Since C<'{Foo, Bar, and Sons}'> consists of a single token with no
commas at brace-level zero (if there were any, it would have more than
one token!), it falls under the "first last" rule: the whole name
becomes the only token in the `last' part, and no other parts exist.

=head1 METHODS

=over 4

=item new (CLASS [, NAME [, FILENAME, LINE, NAME_NUM]])

Creates a new F<Text::BibTeX::Name> object.  If NAME is supplied, it
must be a string containing a single name, and it will be be passed to
the C<split> method for further processing.  FILENAME, LINE, and
NAME_NUM, if present, are all also passed to C<split> to allow better
error messages.

=cut

sub new
{
   my ($class, $name, $filename, $line, $name_num) = @_;

   $class = ref ($class) || $class;
   my $self = bless {}, $class;
   $self->split ($name, $filename, $line, $name_num, 1)
      if (defined $name);
   $self;
}


sub DESTROY
{
   my $self = shift;
   $self->free;                         # free the C structure kept by `split'
}


=item split (NAME [, FILENAME, LINE, NAME_NUM])

Splits NAME (a string containing a single name) into tokens and
subsequently into the four parts of a BibTeX-style name (first, von,
last, and jr).  (Each part is a list of tokens, and tokens are separated
by whitespace or commas at brace-depth zero.  See above for full details
on how a name is split into its component parts.)

The token-lists that make up each part of the name are then stored in
the F<Text::BibTeX::Name> object for later retrieval or formatting with
the C<part> and C<format> methods.

=cut

sub split
{
   my ($self, $name, $filename, $line, $name_num) = @_;

   # Call the XSUB with default values if necessary
   $self->_split ($name, $filename, 
                  defined $line ? $line : -1,
                  defined $name_num ? $name_num : -1,
                  1);
}


=item part (PARTNAME)

Returns the list of tokens in part PARTNAME of a name previously split with
C<split>.  For example, suppose a F<Text::BibTeX::Name> object is created and
initialized like this:

   $name = new Text::BibTeX::Name;
   $name->split ('Charles Louis Xavier Joseph de la Vall{\'e}e Poussin');

Then this code:

   $name->part ('von');

would return the list C<('de','la')>.

=cut

sub part
{
   my ($self, $partname) = @_;

   croak "unknown name part" 
      unless $partname =~ /^(first|von|last|jr)$/;
   exists $self->{$partname} ? @{$self->{$partname}} : ();
}


=item format (FORMAT)

Formats a name according to the specifications encoded in FORMAT, which
should be a F<Text::BibTeX::NameFormat> (or descendant) object.  (In short,
it must supply a method C<apply> which takes a F<Text::BibTeX::NameFormat>
object as its only argument.)  Returns the formatted name as a string.

See L<Text::BibTeX::NameFormat> for full details on formatting names.

=cut

sub format
{
   my ($self, $format) = @_;

   $format->apply ($self);
}

1;

=back

=head1 SEE ALSO

L<Text::BibTeX::Entry>, L<Text::BibTeX::NameFormat>, L<bt_split_names>.

=head1 AUTHOR

Greg Ward <gward@python.net>

=head1 COPYRIGHT

Copyright (c) 1997-98 by Gregory P. Ward.  All rights reserved.  This file
is part of the Text::BibTeX library.  This library is free software; you
may redistribute it and/or modify it under the same terms as Perl itself.
