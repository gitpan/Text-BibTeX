package Text::BibTeX::File;

# $Id: File.pm,v 1.3 1997/09/24 14:42:45 greg Exp $

# BEGIN { print "compiling Text::BibTeX::File\n"; }

use strict;
use Carp;
use IO::File;

=head1 NAME

Text::BibTeX::File - interface to whole BibTeX files

=head1 SYNOPSIS

   use Text::BibTeX;     # this loads Text::BibTeX::File

   $bib = new Text::BibTeX::File "foo.bib" or die "foo.bib: $!\n";

OR

   $bib = new Text::BibTeX::File;
   $bib->open ("foo.bib") || die "foo.bib: $!\n";

   $bib->set_structure ($structure_name,
                        $option1 => $value1, ...);

   $at_eof = $bib->eof;

   $bib->close;

=head1 DESCRIPTION

C<Text::BibTeX::File> provides a gratuitous object-oriented interface to
BibTeX files.  It really doesn't do much apart from keep track of a
filename and filehandle together for use by the C<Text::BibTeX::Entry>
module (which is much more interesting), but it provides a nice clean
interface to which I might add functionality at some point.

=head1 METHODS

=over 4

=item new ([FILENAME [,MODE [,PERMS]]]) 

Creates a new C<Text::BibTeX::File> object.  If C<FILENAME> is supplied,
passes it to the C<open> method (along with C<MODE> and C<PERMS> if they
are supplied).  If the C<open> fails, C<new> fails and returns false; if
the C<open> succeeds (or if C<FILENAME> isn't supplied), C<new> returns the
new object reference.

=item open (FILENAME [,MODE [,PERMS]])

Opens the file specified by C<FILENAME>, possibly using C<MODE> and
C<PERMS> (see L<IO::File> for full semantics; this C<open> is just a front
end for C<IO::File::open>).

=item close

Closes the filehandle associated with the object.  If there is no such
filehandle (ie. if you never called C<open> on the object), does nothing.

=back

=cut

# Object creation/destruction, file operations

sub new
{
   my $class = shift;

   $class = ref ($class) || $class;
   my $self = bless {}, $class;
   ($self->open (@_) || return undef) if @_; # filename [, mode [, perms]]
   $self;
}

sub open
{
   my $self = shift;

   $self->{filename} = $_[0];
   $self->{handle} = new IO::File;
   $self->{handle}->open (@_);          # filename, maybe mode, maybe perms
}

sub close
{
   my $self = shift;
   $self->{handle}->close if $self->{handle};   
}

sub eof
{
   eof (shift->{handle});
}
      
sub DESTROY
{
   my $self = shift;
   $self->close;
}


# Set/query various properties

sub set_structure 
{
   my ($self, $structure, @options) = @_;

   require Text::BibTeX::Structure;
   croak "Text::BibTeX::File::set_structure: options list must have even " .
         "number of elements"
      unless @options % 2 == 0;
   $self->{structure} = new Text::BibTeX::Structure ($structure, @options);
#   $self->{structure_opts} = \%options;
}

sub structure { shift->{structure} }


1;

=head1 AUTHOR

Greg Ward <greg@bic.mni.mcgill.ca>

=head1 COPYRIGHT

Copyright (c) 1997 by Gregory P. Ward.  All rights reserved.  This is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself.
