package Text::BibTeX::Entry;

require 5.004;                          # for isa, and delete on a slice

# $Id: Entry.pm,v 1.9 1997/10/05 23:46:28 greg Exp $

use strict;
use Carp;
use UNIVERSAL 'isa';
import Text::BibTeX qw(:metatypes);

=head1 NAME

Text::BibTeX::Entry - read and parse BibTeX files

=head1 SYNOPSIS

   # ...assuming that $bibfile and $newbib are both objects of class
   # Text::BibTeX::File, opened for reading and writing (respectively):

   # Entry creation/parsing methods:
   $entry = new Text::BibTeX::Entry;
   $entry->read ($bibfile);
   $entry->parse ($filename, $filehandle);
   $entry->parse_s ($entry_text);

   # or:
   $entry = new Text::BibTeX::Entry $bibfile;
   $entry = new Text::BibTeX::Entry $filename, $filehandle;
   $entry = new Text::BibTeX::Entry $entry_text;
   
   # Entry query methods
   warn "error in input" unless $entry->parse_ok;
   $metatype = $entry->metatype;
   $type = $entry->type;

   # if metatype is BTE_REGULAR or BTE_MACRODEF:
   $key = $entry->key;                  # BTE_REGULAR only, actually
   $num_fields = $entry->num_fields;
   @fieldlist = $entry->fieldlist;
   $has_title = $entry->exists ('title');
   $title = $entry->get ('title');
   # or:
   ($val1,$val2,...$valn) = $entry->get ($field1, $field2, ..., $fieldn);

   # if metatype is BTE_COMMENT or BTE_PREAMBLE:
   $value = $entry->value;

   # Author name methods 
   @authors = $entry->split ('author');
   ($first_author) = $entry->names ('author');

   # Entry modification methods
   $entry->set_type ($new_type);
   $entry->set_key ($new_key);
   $entry->set ('title', $new_title);
   # or:
   $entry->set ($field1, $val1, $field2, $val2, ..., $fieldn, $valn);
   $entry->delete (@fields);
   $entry->set_fieldlist (\@fieldlist);

   # Entry output methods
   $entry->write ($newbib);
   $entry->print ($filehandle);
   $entry_text = $entry->print_s;

   # Miscellaneous methods
   $entry->warn ($entry_warning);
   # or:
   $entry->warn ($field_warning, $field);

=head1 DESCRIPTION

C<Text::BibTeX::Entry> does all the real work of reading and parsing
BibTeX files.  (Well, actually it just provides an object-oriented Perl
front-end to a C library that does all that.  But that's not important
right now.)

BibTeX entries can be read either from C<Text::BibTeX::File> objects (using
the C<read> method), or directly from a filehandle (using the C<parse>
method), or from a string (using C<parse_s>).  The first is preferable,
since you don't have to worry about supplying the filename, and because I
might add more functionality to that method in the future.  Currently,
though, the two are pretty much identical.

Once you have the entry, you can query it or change it in a variety of
ways.  The query methods are C<parse_ok>, C<type>, C<key>, C<num_fields>,
C<fieldlist>, C<exists>, and C<get>.  Methods for changing the entry are
C<set_type>, C<set_key>, C<set_fieldlist>, C<delete>, and C<set>.

Finally, you can output BibTeX entries, again either to an open
C<Text::BibTeX::File> object, a filehandle or a string.  (A
C<Text::BibTeX::File> object or filehandle must, of course, have been
opened in write mode.)  Output to a C<Text::BibTeX::File> object is done
with the C<write> method, to a filehandle via C<print>, and to a string
with C<print_s>.  Again, the nice object-oriented way of doing things is
recommended for future extensibility.

=head1 METHODS

=head2 Entry creation/parsing methods

=over 4

=item new ([SOURCE])

Creates a new C<Text::BibTeX::Entry> object.  If the SOURCE parameter is
supplied, it must be one of the following: a C<Text::BibTeX::File> (or
descendant class) object, a filename/filehandle pair, or a string.  Calls
C<read> to read from a C<Text::BibTeX::File> object, C<parse> to read from
a filehandle, and C<parse_s> to read from a string.

A filehandle can be specified as a GLOB reference, or as an
C<IO::Handle> (or descendants) object, or as a C<FileHandle> (or
descendants) object.  (But there's really no point in using
C<FileHandle> objects, since C<Text::BibTeX> requires Perl 5.004, which
always includes the C<IO> modules.)  You can I<not> pass in the name of
a filehandle as a string, though, because F<Text::BibTeX::Entry>
conforms to the C<use strict> pragma (which disallows such symbolic
references).

The corresponding filename should be supplied in order to allow for
accurate error messages; if you simply don't have the filename, you can
pass C<undef> and you'll get error messages without a filename.  (It's
probably better to rearrange your code so that the filename is
available, though.)

Thus, the following are equivalent to read from a file named by
C<$filename> (error handling ignored):

   # good ol' fashioned filehandle and GLOB ref
   open (BIBFILE, $filename);
   $entry = new Text::BibTeX::Entry ($filename, \*BIBFILE);

   # newfangled IO::File thingy
   $file = new IO::File $filename;
   $entry = new Text::BibTeX::Entry ($filename, $file);

But using a C<Text::BibTeX::File> object is preferred:

   $file = new Text::BibTeX::File $filename;
   $entry = new Text::BibTeX::Entry $file;

Returns the new object, unless SOURCE is supplied and reading/parsing
the entry fails (e.g., due to end of file) -- then it returns false.

=cut

sub new
{
   my ($class, @source) = @_;

   $class = ref ($class) || $class;
   my $self = {file   => undef,
               type   => undef,
               key    => undef,
               status => undef,
               'fields' => [],
               'values' => {}};

   bless $self, $class;
   if (@source)
   {
      my $status;

      if (@source == 1 && isa ($source[0], 'Text::BibTeX::File'))
      { 
         # XXX err... what if $file doesn't have a structure, or the
         # structure doesn't have an entry_class???

         my $file = $source[0];
         $status = $self->read ($file);
         bless $self, $file->structure->entry_class
            if ($file->structure);
      }
      elsif (@source == 2 && ! ref $source[0] && fileno ($source[1]))
          { $status = $self->parse ($source[0], $source[1]) }
      elsif (@source == 1 && ! ref $source[0])
          { $status = $self->parse_s ($source[0]) }
      else
          { croak "new: source argument must be either a Text::BibTeX::File " .
                  "(or descendant) object, filename/filehandle pair, or " .
                  "a string"; }

      return $status unless $status;    # parse failed -- tell our caller
   }
   $self;
}

=item read (BIBFILE)

Reads and parses an entry from BIBFILE, which must be a
C<Text::BibTeX::File> object (or descendant).  The next entry will be read
from the file associated with that object.

Returns the same as C<parse> (or C<parse_s>): false if no entry found
(e.g., at end-of-file), true otherwise.  To see if the parse itself failed
(due to errors in the input), call the C<parse_ok> method.

=cut

sub read
{
   my ($self, $source) = @_;
   croak "`source' argument must be ref to open Text::BibTeX::File " .
         "(or descendant) object"
      unless (isa ($source, 'Text::BibTeX::File'));

   my $fn = $source->{'filename'};
   my $fh = $source->{'handle'};
   $self->{'file'} = $source;        # store File object for later use
   return $self->parse ($fn, $fh);
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
anybody using your program will certainly appreciate your setting it
correctly!

=item parse_s (TEXT)

Parses a BibTeX entry (using the above rules) from the string TEXT.  The
string is not modified; repeatedly calling C<parse_s> with the same string
will give you the same results each time.  Thus, there's no point in
putting multiple entries in one string.

=back

=cut

# see BibTeX.xs for the implementation of the `parse' and `parse_s' methods


=head2 Entry query methods

=over 4

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

=item metatype

Returns the metatype of the entry.  (The `metatype' is a numeric value used
to classify entry types into four groups: comment, preamble, macro
definition (C<@string> entries), and regular (all other entry types).
Text::BibTeX exports four constants for these metatypes: BTE_COMMENT,
BTE_PREAMBLE, BTE_MACRODEF, and BTE_REGULAR.)

=item key

Returns the key of the entry.  (The key is the token immediately
following the opening `{' or `(' in "regular" entries.  Returns C<undef>
for entries that don't have a key, such as macro definition (C<@string>)
entries.)

=item num_fields

Returns the number of fields in the entry.  (Note that, currently, this is
I<not> equivalent to putting C<scalar> in front of a call to C<fieldlist>.
See below for the consequences of calling C<fieldlist> in a scalar
context.)

=item fieldlist

Returns the list of fields in the entry.  In a scalar context, returns a
reference to the object's own list of fields.  That way, you can change or
reorder the field list with minimal interference from the class.  I'm not
entirely sure if this is a good idea, so don't rely on it existing in the
future; feel free to play around with it and let me know if you get bitten
in dangerous ways or find this enormously useful.

=cut

sub parse_ok   { shift->{'status'}; }

sub metatype   { shift->{'metatype'}; }

sub type       { shift->{'type'}; }

sub key        { shift->{'key'}; }

sub num_fields { scalar @{shift->{'fields'}}; }

sub fieldlist  { wantarray ? @{shift->{'fields'}} : shift->{'fields'}; }

=item exists (FIELD)

Returns true if a field named FIELD is present in the entry, false
otherwise.  

=item get (FIELD, ...)

Returns the value of one or more FIELDs, as a list of values.  For example:

   $author = $entry->get ('author');
   ($author, $editor) = $entry->get ('author', 'editor');

If a FIELD is not present in the entry, C<undef> will be returned at its
place in the return list.  However, you can't completely trust this as a
test for presence or absence of a field; it is possible for a field to be
present but undefined.  Currently this can only happen due to certain
syntax errors in the input, or if you pass an undefined value to C<set>, or
if you create a new field with C<set_fieldlist> (the new field's value is
implicitly set to C<undef>).

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

=item value

Retuns the single string associated with C<@comment> and C<@preamble>
entries.  For instance, the entry

   @preamble{" This is   a preamble" # 
             {---the concatenation of several strings}}

would return a value of "This is a preamble---the concatenation of
several strings".

=back

=cut

sub exists 
{
   my ($self, $field) = @_;

   exists $self->{'values'}{$field};
}

sub get
{
   my ($self, @fields) = @_;

   @{$self->{'values'}}{@fields};
}

sub value { shift->{'value'} }


=head2 Author name methods

This is the only part of the module that makes any assumption about the
nature of the data, namely that certain fields are lists delimited by a
simple word such as "and", and that the delimited sub-strings are human
names of the "First von Last" or "von Last, Jr., First" style used by
BibTeX.  If you are using this module for anything other than
bibliographic data, you can most likely forget about these two methods.
However, if you are in fact hacking on BibTeX-style bibliographic data,
these could come in very handy -- the name-parsing done by BibTeX is not
trivial, and the list-splitting would also be a pain to implement in
Perl because you have to pay attention to brace-depth.  (Not that it
wasn't a pain to implement in C -- it's just a lot more efficient than a
Perl implementation would be.)

Incidentally, both of these methods assume that the strings being split
have already been "collapsed" in the BibTeX way, i.e. all leading and
trailing whitespace removed and internal whitespace reduced to single
spaces.  This should always be the case when using these two methods on
a C<Text::BibTeX::Entry> object, but these are actually just front ends
to more general functions in C<Text::BibTeX>.  (More general in that you
supply the string to be parsed, rather than supplying the name of an
entry field.)  Should you ever use those more general functions
directly, you might have to worry about collapsing whitespace; see
L<Text::BibTeX> (the C<split_list> and C<split_name> functions in
particular) for more information.

Please note that the interface to author name parsing is experimental,
subject to change, and open to discussion.  Please let me know if you
have problems with it, think it's just perfect, or whatever.

=over 4

=item split (FIELD [, DELIM [, DESC]])

Splits the value of FIELD on DELIM (default: `and').  Don't assume that,
just because the names are the same, this works the same as Perl's
builtin C<split>: in particular, DELIM must be a simple string (no
regexps), and delimiters that are at the beginning or end of the string,
or at non-zero brace depth, or not surrounded by whitespace, are
ignored.  Some examples might illuminate matters:

   if field F is...                then split (F) returns...
   'Name1 and Name2'               ('Name1', 'Name2')
   'Name1 and and Name2'           ('Name1', undef, 'Name2')
   'Name1 and'                     ('Name1 and')
   'and Name2'                     ('and Name2')
   'Name1 {and} Name2 and Name3'   ('Name1 {and} Name2', 'Name3')
   '{Name1 and Name2} and Name3'   ('{Name1 and Name2}', 'Name3')

Note that a warning will be issued for empty names (as in the second
example above).  A warning ought to be issued for delimiters at the
beginning or end of a string, but currently this isn't done.  (Hmmm.)

DESC is a one-word description of the substrings; it defaults to 'name'.
It is only used for generating warning messages.

=item names (FIELD)

Splits FIELD as described above, and further splits each name into four
components: first, von, last, and jr.  The rules for this are described
colloquially in any BibTeX documentation, and will eventually be spelled
out more formally in the documentation for the F<btparse> library.

Returns a list of structures representing the names.  Each structure is
a hash with at most four keys (C<first>, C<von>, C<last>, and C<jr>);
the values are either C<undef> or lists of the tokens that make up that
component of the name.  For example, the following entry:

   @article{foo,
            author = {John Smith and 
                      Hacker, J. Random and
                      Ludwig van Beethoven and
                      {Foo, Bar and Company}}}

would result in the following list of name-structures being returned by
C<names>:

   ( { first => ['John'],
       von   => undef,
       last  => ['Smith'],
       jr    => undef },
     { first => ['J.', 'Random'],
       von   => undef,
       last  => ['Hacker'],
       jr    => undef },
     { first => ['Ludwig'],
       von   => ['van'],
       last  => ['Beethoven']
       jr    => undef },
     { first => undef,
       von   => undef,
       last  => ['{Foo, Bar and Company}'],
       jr    => undef } )

and some example code might look like

   @names = $entry->names ('author');
   $sort_key = $names[0]->{'last'} . ' ' . $names[0]->{'first'};

=cut

sub split
{
   my ($self, $field, $delim, $desc) = @_;

   return unless $self->exists ($field);
   $delim ||= 'and';
   $desc ||= 'name';

   my $filename = ($self->{'file'} && $self->{'file'}{'filename'});
   my $line = $self->{'lines'}{$field};

   local $^W = 0                        # suppress spurious warning from 
      unless defined $filename;         # undefined $filename
   Text::BibTeX::split_list ($self->{'values'}{$field}, $delim,
                             $filename, $line, $desc);
}

sub names
{
   my ($self, $field) = @_;
   my (@names, $i);

   my $filename = ($self->{'file'} && $self->{'file'}{'filename'});
   my $line = $self->{'lines'}{$field};

   @names = $self->split ($field);
   local $^W = 0                        # suppress spurious warning from 
      unless defined $filename;         # undefined $filename
   for $i (0 .. $#names)
   {
      $names[$i] = Text::BibTeX::split_name ($names[$i], $filename, $line, $i);
   }
   @names;
}

=head2 Entry modification methods

=over 4

=item set_type (TYPE)

Sets the entry's type.

=item set_key (KEY)

Sets the entry's key.

=item set (FIELD, VALUE, ...)

Sets the value of field FIELD.  (VALUE might be C<undef> or unsupplied,
in which case FIELD will simply be set to C<undef> -- this is where the
difference between the C<exists> method and testing the definedness of
field values becomes clear.)

Multiple (FIELD, VALUE) pairs may be supplied; they will be processed in
order (i.e. the input is treated like a list, not a hash).  For example:

   $entry->set ('author', $author);
   $entry->set ('author', $author, 'editor', $editor);

=item delete (FIELD)

Deletes field FIELD from an entry.

=item set_fieldlist (FIELDLIST)

Sets the entry's list of fields to FIELDLIST, which must be a list
reference.  If any of the field names supplied in FIELDLIST are not
currently present in the entry, they are created with the value C<undef>
and a warning is printed.  Conversely, if any of the fields currently
present in the entry are not named in the list of fields supplied to
C<set_fields>, they are deleted from the entry and another warning is
printed.

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

sub set
{
   my $self = shift;
   croak "set: must supply an even number of arguments"
      unless (@_ % 2 == 0);
   my ($field, $value);

   while (@_)
   {
      ($field,$value) = (shift,shift);
      push (@{$self->{'fields'}}, $field)
         unless exists $self->{'values'}{$field};
      $self->{'values'}{$field} = $value;
   }
}

sub delete
{
   my ($self, @fields) = @_;
   my (%gone);

   %gone = map {$_, 1} @fields;
   @{$self->{'fields'}} = grep (! $gone{$_}, @{$self->{'fields'}});
   delete @{$self->{'values'}}{@fields};
}

sub set_fieldlist
{
   my ($self, $fields) = @_;

   # Warn if any of the caller's fields aren't already present in the entry

   my ($field, %in_list);
   foreach $field (@$fields)
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

   # Now we can install (a copy of) the caller's desired field list;

   $self->{'fields'} = [@$fields];
}


=head2 Entry output methods

=over 4

=item write (BIBFILE)

Prints a BibTeX entry on the filehandle associated with BIBFILE (which
should be a C<Text::BibTeX::File> object, opened for output).  Currently
the printout is not particularly human-friendly; a highly configurable
pretty-printer will be developed eventually.

=item print (FILEHANDLE)

Prints a BibTeX entry on FILEHANDLE.

=item print_s

Prints a BibTeX entry to a string, which is the return value.

=cut

sub write
{
   my ($self, $bibfile) = @_;

   my $fh = $bibfile->{'handle'};
   $self->print ($fh);
}

sub print
{
   my ($self, $handle) = @_;

   print $handle $self->print_s;
}

sub print_s
{
   my $self = shift;
   my ($field, $output);

   carp "entry type undefined" unless defined $self->{'type'};

   # Regular and macro-def entries have to be treated differently when
   # printing the first line, because the former have keys and the latter
   # do not.
   if ($self->{'metatype'} == &BTE_REGULAR)
   {
      carp "entry key undefined" unless defined $self->{'key'};
      $output = sprintf ("@%s{%s,\n",
                         $self->{'type'} || '', 
                         $self->{'key'} || '');
   }
   elsif ($self->{'metatype'} == &BTE_MACRODEF)
   {
      $output = sprintf ("@%s{\n",
                         $self->{'type'} || '');
   }

   # Comment and preamble entries are treated the same -- we print out
   # the entire entry, on one line, right here.
   else                                 # comment or preamble
   {
      return sprintf ("@%s{%s}\n\n", $self->{'type'}, $self->{'value'});
   }

   # Here we print out all the fields/values of a regular or macro-def entry
   foreach $field (@{$self->{'fields'}})
   {
      carp "field \"$field\" has undefined value\n"
         unless defined $self->{'values'}{$field};
      $output .= sprintf ("  %s = {%s},\n",
                          $field, 
                          $self->{'values'}{$field} || '');
   }

   # Tack on the last line, and we're done!
   $output .= "}\n\n";
   $output;
}


=head2 Miscellaneous methods

=over 4

=item warn (WARNING [, FIELD])

Prepends a bit of location information (filename and line number(s)) to
WARNING, appends a newline, and passes it to Perl's C<warn>.  If FIELD is
supplied, the line number given is just that of the field; otherwise, the
range of lines for the whole entry is given.  (Well, almost -- currently,
the line number of the last field is used as the last line of the whole
entry.  This is a bug.)

For example, if lines 10-15 of file F<foo.bib> look like this:

   @article{homer97,
     author = {Homer Simpson and Ned Flanders},
     title = {Territorial Imperatives in Modern Suburbia},
     journal = {Journal of Suburban Studies},
     year = 1997
   }

then, after parsing this entry to C<$entry>, the calls

   $entry->warn ('what a silly entry');
   $entry->warn ('what a silly journal', 'journal');

would result in the following warnings being issued:

   foo.bib, lines 10-14: what a silly entry
   foo.bib, line 13: what a silly journal

=cut

sub warn
{
   my ($self, $warning, $field) = @_;

   my $location = '';
   if ($self->{'file'})
   {
      $location = $self->{'file'}{'filename'} . ", ";
   }

   my $lines = $self->{'lines'};
   my $entry_range = ($lines->{'START'} == $lines->{'STOP'})
      ? "line $lines->{'START'}"
      : "lines $lines->{'START'}-$lines->{'STOP'}";

   if (defined $field)
   {
      $location .= (exists $lines->{$field})
         ? "line $lines->{$field}: "
         : "$entry_range (unknown field \"$field\"): ";
   }
   else
   {
      $location .= "$entry_range: ";
   }

   warn "$location$warning\n";
}


1;

=head1 AUTHOR

Greg Ward <greg@bic.mni.mcgill.ca>

=head1 COPYRIGHT

Copyright (c) 1997 by Gregory P. Ward.  All rights reserved.  This is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself.

=cut
