package Text::BibTeX::Entry;

# $Id: Entry.pm,v 1.1 1997/03/08 18:28:04 greg Exp $

use strict;
use Carp;

=head1 NAME

Text::BibTeX::Entry - read and parse BibTeX files

=head1 SYNOPSIS

   # Assume $bib and $newbib are both objects of class 
   # Text::BibTeX::File, and that $newbib was opened 
   # for writing.

   $entry = new Text::BibTeX::Entry ($bib);
   die "Errors in entry\n" unless $entry->parse_ok;
   
   $type = $entry->type;

   $entry->set_type ($new_type);

   $key = $entry->key;

   $entry->set_key ($new_key);

   $num_fields = $entry->num_fields ();

   @fields = $entry->fields ();

   %values = $entry->values ();

   $has_title = $entry->exists ('title');

   $title = $entry->value ('title');

   $entry->set_value ('title', $new_title);

   $entry->put ($newbib);

=head1 DESCRIPTION

C<Text::BibTeX::Entry> does all the real work of reading and parsing
BibTeX files.  (Well, actually it just provides an object-oriented Perl
front-end to a C library that does all that.  But that's not important
right now.)

BibTeX entries can be read either from C<Text::BibTeX::File> objects (using
the C<get> method), or directly from a filehandle (using the C<parse>
method).  The former is preferable, since you don't have to worry about
supplying the filename, and because I might add more functionality to that
method in the future.  Currently, though, the two are pretty much
identical.

Once you have the entry, you can query it or change it in a variety of
ways.  The query methods are C<parse_ok>, C<type>, C<key>, C<num_fields>,
C<fields>, C<values>, C<exists>, and C<value>.  Methods for changing the
entry are C<set_type>, C<set_key>, C<set_field> and C<set_fields>.

Finally, you can output BibTeX entries, again either to a filehandle or
an open C<Text::BibTeX::File> object.  (This object must, of course,
have been opened in write mode.)  Output to a filehandle is done with
the C<print> method, and to a C<Text::BibTeX::File> object via C<put>.
Again, the two are currently identical, but I may add interesting
functionality to the nice object-oriented way of doing things.  (In
spite of that advice, I often write utilities that read from
C<Text::BibTeX::File> objects created from command-line arguments, and
then just write to STDOUT, in the grand Unix filter fashion.)

=head1 METHODS

=head2 Entry creation/parsing methods

=over

=item new ([SOURCE])

Creates a new C<Text::BibTeX::Entry> object.  If the SOURCE parameter is
supplied, calls C<get> on the new object with it.  Returns the new
object, unless SOURCE is supplied and C<get> fails (e.g. due to end of
file) -- then it returns a false value.

=cut

sub new
{
   my ($class, $source) = @_;

   my $class = ref ($class) || $class;
   my $self = bless {}, $class;
   if ($source)
   {
      my $status = $self->get ($source);
      return $status unless $status;    # get failed -- tell our caller
   }
   $self;
}

=item get (SOURCE)

Reads and parses an entry from SOURCE.  SOURCE can be either a
C<Text::BibTeX::File> object (or descendant), in which case the next entry
will be read from the file associated with that object.  Otherwise, SOURCE
should be a string containing an entire BibTeX entry, which will be parsed.
(SOURCE could in fact contain multiple entries, but only the first one is
seen, and the string is I<not> modified to `pop' off this first entry.)

Returns the same as C<parse> (or C<parse_s>): false if no entry found
(e.g., at end-of-file), true otherwise.  To see if the parse itself failed
(due to errors in the input), call the C<parse_ok> method.

=cut

sub get
{
   my ($self, $source) = @_;

   if (ref $source)                     # assume a Text::BibTeX::File object
   {
      croak "Bad `source' argument: should be ref to open Text::BibTeX::File object (or descendant)"
         unless exists $source->{'filename'} && exists $source->{'handle'};

      my $fn = $source->{'filename'};
      my $fh = $source->{'handle'};
      $self->parse ($fn, $fh);
   }
   else                                 # assume $source is just the entry text
   {
      $self->parse_s ($source);
   }
}


=item parse (FILENAME, FILEHANDLE)

Reads and parses the next entry from FILEHANDLE.  (That is, it scans the
input until an '@' sign is seen, and then slurps up to the next '@'
sign.  Everything between the two '@' signs [including the first one,
but not the second one -- it's pushed back onto the input stream for the
next entry] is parsed as a BibTeX entry, with the simultaneous
construction of an abstract syntax tree [AST].  The AST is traversed to
ferret out the most interesting information, and this is stuffed into a
Perl hash, which coincidentally is the C<Text::BibTeX::Entry> object
you've been tossing around.  But you don't need to know any of that -- I
just figured if you've read this far, you might want to know something
about the inner workings of this module.)

The success of the parse is stored internally so that you can later
query it with the C<parse_ok> method.  Even in the presence of syntax
errors, you'll usually get something resembling your input, but it's
usually not wise to try to do anything with it.  Just call C<parse_ok>,
and if it returns false then silently skip to the next entry.  (The
error messages printed out by the parser should be quite adequate for
the user to figure out what's wrong.  And no, there's currently no way
for you to capture or redirect those error messages -- they're always
printed to C<stderr> by the underlying C code.  That should change in
future releases.)

If no '@' signs are seen on the input before reaching end-of-file, then
we've exhausted all the entries in the file, and C<parse> returns a
false value.  Otherwise, it returns a true value -- even if there were
syntax errors.  Hence, it's important to check C<parse_ok>.

The FILENAME parameter is only used for generating error messages, but
your users will certainly appreciate you setting it correctly!

=item parse_s (TEXT)

Parses a BibTeX entry (using the above rules) from the string TEXT.  The
string is not modified; repeatedly calling C<parse_s> with the same string
will give you the same results.  Thus, there's no point in putting multiple
entries in one string.

=back

=cut

# see BibTeX.xs for the implementation of the `parse' method


=head2 Entry query methods

=over

=item parse_ok

Returns false if there were any serious errors encountered while parsing
the entry.  (A "serious" error is a lexical or syntax error; currently,
warnings such as "undefined macro" result in an error message being
printed to C<stderr> for the user's edification, but no notice is
available to the calling code.)

=item type

Returns the type of the entry.  (The `type' is the word that follows the
'@' sign; e.g. `article', `book', `inproceedings', etc. for the standard
BibTeX styles.)

=item key

Returns the key of the entry.  (The key is the token immediately
following the opening `{' or `('.)

=item num_fields

Returns the number of fields in the entry.  (Note that, currently, this is
I<not> equivalent to putting C<scalar> in front of a call to C<fields>.
See below for the consequences of calling C<fields> in a scalar context.)

=item fields

Returns the list of fields in the entry.  (In a scalar context, returns a
reference to the object's own list of fields.  That way, you can change or
reorder the field list with minimal interference from the class.  I'm not
entirely sure if this is a good idea, so don't rely on it existing in the
future; feel free to play around with it and let me know if you get bitten
in dangerous ways.)

=item values

Returns a hash mapping field name to field value for the entire entry.  (In
a scalar context, returns a reference to the object's own field value hash.
The same caveats as for C<fields> apply.)

=cut

sub parse_ok   { shift->{'status'}; }

sub type       { shift->{'type'}; }

sub key        { shift->{'key'}; }

sub num_fields { scalar @{shift->{'fields'}}; }

sub fields     { wantarray ? @{shift->{'fields'}} : shift->{'fields'}; }

sub values     { wantarray ? %{shift->{'values'}} : shift->{'values'}; }

=item exists (FIELD)

Returns true if a field named FIELD is present in the entry, false
otherwise.  

=item value (FIELD)

Returns the value of FIELD.  If FIELD is not present in the entry, C<undef>
will be returned.  However, you can't trust this as a test for presence or
absence of a field; it is possible for a field to be present but undefined.
Currently this can only happen due to certain syntax errors in the input,
or if you pass an undefined value to C<set_field>, or if you implicitly
create a new field with C<set_fields>.

Currently, the field value is what the input looks like after "maximal
processing"--quote characters are removed, whitespace is collapsed (the
same way that BibTeX itself does it), macros are expanded, and multiple
tokens are pasted together.  For example, if your input file has the
following:

   @string{of = "of"}
   @string{foobars = "Foobars"}

   @article{foobar,
     title = {   The Mating Habits      } # of # " Adult   " # foobars
   }

then querying the value of the C<title> field from the C<foobar> entry
would give the string "The Mating Habits of Adult Foobars".  I have plans
up my sleeve for giving access to the data at various stages of processing
(the underlying C library is quite flexible in this regard; I just have to
translate the flexibility to Perl), but haven't finalized anything yet.  If
you have ideas, feel free to email me!  (I also have plans for
documenting what exactly is done to strings in my BibTeX parser; that'll
probably be distributed with the C library, btparse.)

=item names ([FIELD, [DELIM]])   *currently unimplemented*

Splits the value of FIELD (default: `author') on DELIM (default: `and').
This is a bit trickier than it sounds because we have to exclude delimiters
encased in braces, which mandates scanning a character at a time and
keeping track of brace-depth.  (That's why this is currently
unimplemented.)

=back

=cut

sub exists 
{
   my ($self, $field) = @_;

   exists $self->{'values'}{$field};
}

sub value
{
   my ($self, $field) = @_;

   $self->{'values'}{$field};
}

# sub names
# {
#    my ($self, $field, $delim) = @_;

#    $field = 'author' unless $field;
#    $delim = 


#
# Entry modification methods
#

=head2 Entry modification methods

=over

=item set_type (TYPE)

Sets the entry's type.

=item set_key (KEY)

Sets the entry's key.

=item set_field (FIELD, VALUE)

Sets the value of field FIELD.  (VALUE might be C<undef> or unsupplied, in
which FIELD will simply be set to C<undef> -- this is where the difference
between the C<exists> method and testing the definedness of field values
becomes clear.)

=item set_fields (FIELD1, ..., FIELDn)

Sets the entry's list of fields.  If any of the field names supplied to
C<set_fields> are not currently present in the entry, they are created
with the value C<undef> and a warning is printed.  Conversely, if any of
the fields currently present in the entry are not named in the list of
fields supplied to C<set_fields>, they are deleted from the entry and
another warning is printed.

=back

=cut

sub set_type
{
   my ($self, $type) = @_;

   $self->{'type'} = $type;
}

sub set_key
{
   my ($self, $key) = @_;

   $self->{'key'} = $key;
}

sub set_field
{
   my ($self, $field, $value) = @_;

   push (@{$self->{'fields'}}, $field)
      unless exists $self->{'values'}{$field};
   $self->{'values'}{$field} = $value;
}

sub set_fields
{
   my ($self, @fields) = @_;

   # Warn if any of the caller's fields aren't already present in the entry

   my ($field, %in_list);
   foreach $field (@fields)
   {
      $in_list{$field} = 1;
      unless (exists $self->{'values'}{$field})
      {
         carp "Implicitly adding undefined field \"$field\"";
         $self->{'values'}{$field} = undef;
      }
   }

   # And see if there are any fields in the entry that aren't in the user's
   # list; delete them from the entry if so

   foreach $field (keys %{$self->{'values'}})
   {
      unless ($in_list{$field})
      {
         carp "Implicitly deleting field \"$field\"";
         delete $self->{'values'}{$field};
      }
   }

   # Now we can install the caller's desired field list;

   $self->{'fields'} = \@fields;
}


=head2 Entry output methods

=over

=item put (BIBFILE)

Prints a BibTeX entry on the filehandle associated with BIBFILE (which
should be a C<Text::BibTeX::File> object, opened for output).  Currently
the printout is not particularly human-friendly; a highly configurable
pretty-printer will be developed eventually.

=item print (FILEHANDLE)

Prints a BibTeX entry on FILEHANDLE.

=cut

sub put
{
   my ($self, $bibfile) = @_;

   my $fh = $bibfile->{'handle'};
   $self->print ($fh);
}

sub print
{
   my ($self, $handle) = @_;
   my ($save, $field);

   $save = select $handle;           # how 'bout $handle->select ???
   printf "@%s{%s,\n", $self->{'type'}, $self->{'key'};
   foreach $field (@{$self->{'fields'}})
   {
      printf "  %s = {%s},\n", $field, $self->{'values'}{$field};
   }
   print "}\n\n";
}

1;

=head1 AUTHOR

Greg Ward <greg@bic.mni.mcgill.ca>

=head1 COPYRIGHT

Copyright (c) 1997 by Gregory P. Ward.  All rights reserved.  This is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself.

=cut
