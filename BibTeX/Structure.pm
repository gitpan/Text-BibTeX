package Text::BibTeX::Structure;

# $Id: Structure.pm,v 1.1 1997/04/29 02:04:46 greg Exp $

use strict;
use vars qw(@ISA @EXPORT_OK);
use Carp;

require Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw(find_structure);

=head1 NAME

Text::BibTeX::Structure - check/enforce database structure in BibTeX entries

=head1 SYNOPSIS

=head1 DESCRIPTION

C<Text::BibTeX::Structure> takes care of checking that BibTeX entries
adhere to some pre-specified database structure, and optionally coercing
them into compliance with that structure.  It does this by maintaining,
for a given database structure, the list of allowed entry types, and
required and optional fields for each of the entry types.  

For example, the `bibliography' structure -- an extension of the
structure implicit in the original BibTeX's standard style files --
includes entry types such as C<article>, C<book>, and C<inproceedings>;
the required fields for C<article>-type entries are C<author>, C<title>,
C<journal>, and C<year>, and the optional fields are C<volume>,
C<number>, C<pages>, C<month>, and C<note>.  (Complete details of the
`bibliography' structure will be documented elsewhere.  Likewise, the
method for creating new database structures will be documented
elsewhere.  Neither of these documents yet exist, so don't bother
looking for them.)

Users can create new database structures using an as-yet-unspecified
definition file.  This allows the database structure to be defined
explicitly and independently of the output format (`style file'), in
contrast to the original BibTeX.

=cut

my (%structure);                        # it's the structure structure!


# Define the structure for bibliography databases.  I'm doing it here
# for now to avoid having to worry about the user-written structure
# definition file for now -- I just want to concentrate on the structure
# and how to work with it.

my $bibliography =
{
 name => 'bibliography',
# types => [qw(article book booklet inbook incollection inproceedings
#              manual mastersthesis misc phdthesis proceedings
#              techreport unpublished)]
 fields => 
 {
  article => 
  {
   required => [qw(author title journal year)],
   optional => [qw(volume number pages month note)]
  },
  book => 
  {
   required => [{ alt => 'xor', fields => [qw(author editor)]},
                qw(title publisher year)],
   optional => [{ alt => 'xor', fields => [qw(volume number)]},
                qw(series address edition month note)]
  },
  booklet => 
  {
   required => ['title'],
   optional => [qw(author howpublished address month year note)]
  },
  inbook => 
  {
   required => [{ alt => 'xor', fields => [qw(author editor)]},
                'title',
                { alt => 'or', fields => [qw(chapter pages)]},
                qw(publisher year)],
   optional => [{ alt => 'xor', fields => [qw(volume number)]},
                qw(series type address edition month note)]
  },
  incollection => 
  {
   required => [qw(author title booktitle publisher year)],
   optional => ['editor',
                { alt => 'xor', fields => [qw(volume number)]},
                qw(series type chapter pages address edition month note)]
  },
  inproceedings => 
  {
   required => [qw(author title booktitle year)],
   optional => ['editor',
                { alt => 'xor', fields => [qw(volume number)]},
                qw(series pages address month organization publisher note)]
  },
  manual => 
  {
   required => ['title'],
   optional => [qw(author organization address edition month year note)]
  },
  mastersthesis => 
  {
   required => [qw(author title school year)],
   optional => [qw(type address month note)] 
  },
  misc => 
  {
   required => [],
   optional => [qw(author title howpublished month year note)] 
  },
  phdthesis => 
  {
   required => [qw(author title school year)],
   optional => [qw(type address month note)]
  },
  proceedings => 
  {
   required => [qw(title year)],
   optional => ['editor',
                { alt => 'xor', fields => [qw(volume number)]},
                qw(series address month organization publisher note)]
  },
  techreport => 
  {
   required => [qw(author title school year)],
   optional => [qw(type number address month note)]
  },
  unpublished => 
  {
   required => [qw(author title note)],
   optional => [qw(month year)] 
  }
 }
};

bless $bibliography;

$structure{'bibliography'} = $bibliography;

=head1 DETAILS

=head2 Traditional subroutines

=over

=item find_structure (STRUCT)

Searches the space of known database structures for the one named by
STRUCT.  (STRUCT might itself be a description of a database structure, in
which case it is returned without further processing.)

Currently the only known database structure is `bibliography'; eventually
this will be extended to search a user-extendible collection of on-line
structure definitions.

=cut

sub find_structure
{
   my ($struct) = @_;

   return $struct if ref $struct && $struct->isa ('Text::BibTeX::Structure');
   $structure{$struct} || die "Unknown structure \"$struct\"\n";
}

=back

=head2 Methods of C<Text::BibTeX::Structure> class

=over

=item dump

Dumps a structure definition.  Format is suspiciously similar to that used
to describe the BibTeX structure in I<A Guide to LaTeX2e>, Appendix B.
Probably also quite similar to what I'll require the input file to look
like.

NAME is the name of the structure; it must be supplied.  STRUCTURE is a
complete structure definition, as returned by the mythical
C<read_structure>; if it is not supplied, then the structure associated
with NAME is looked up in the global list of known structures.  Croaks if
this lookup fails.

=cut


sub new 
{
   my $type = shift;
   my $self = bless {}, $type;
}


sub dump
{
   my ($self) = shift;
   my (%cvt_alt, $op, $name, $type, $group, $field);

   %cvt_alt = ('xor' => '|',
              'or'  => '/');

   $name = $self->{'name'};
   print "structure: $name\n\n";

   foreach $type (sort keys %{$self->{fields}})
   {
      print "\@${type}\n";

      foreach $group (qw(required optional))
      {
         my @fields = @{$self->{'fields'}{$type}{$group}};
         for $field (@fields)
         {
            if (ref $field eq 'HASH')   # list of alternates
            {
               $op = $cvt_alt{$field->{'alt'}};
               $field = join ($op, @{$field->{'fields'}});
            }
            elsif (ref $field)          # this should not happen!
            {
               confess "bogus structure definition!";
            }
         }

         print "$group: " . join (", ", @fields) . "\n";
      }

      print "\n";
   }
}


=item read FILE

Reads a structure definition from a file.  No clue how it'll work yet.

=cut


sub read
{
   my ($self, $file) = @_;
   my ($state, %cvt_alt, $type);

   $state = 0;                          # 0 = looking for "structure: "
                                        # 1 = looking for "@type"
                                        # 2 = reading fields for a type

   %cvt_alt = ('|' => 'xor',
               '/' => 'or');

   open (FILE, $file) || die "$file: $!\n";
   while (<FILE>)
   {
      chomp;
      s/[\#\%].*//;                     # strip comments
      next if /^\s*$/;                  # skip blanks
      ($_ .= <FILE>, redo)              # line continuation
         if s/\\$//;

      if ($state == 0)
      {
         die "$file, line $.: expected \"structure: structure_name\"\n"
            unless /^ \s* structure: \s* (\w+) \s* $/x;

         $self->{'name'} = $1;
         $state = 1;
      }
      elsif ($state == 1)
      {
         die "$file, line $.: expected \"\@entry_type\"\n"
            unless /^ \s* \@ (\w+) \s* $/x;

         $type = $1;
         die "$file, line $.: entry type $type already defined\n"
            if exists $self->{'fields'}{$type};
         $self->{'fields'}{$type} = { required => [], optional => [] };
         $state = 2;
      }
      elsif ($state == 2)
      {
         ($state = 1, redo)
            if /^ \s* \@/x;
         die "$file, line $.: expected \"required:\" or \"optional:\"\n"
            unless s/^ \s* (required|optional) \s* : \s* //x;

         my ($group, @fields, $field);

         $group = $1;
         @fields = split (',');
         grep { s/^\s+//; s/\s+$// } @fields;

         foreach $field (@fields)
         {
            # here we're assuming only 2 possible alternates!
            if ($field =~ /^(\w+) \s* ([\/|\|]) \s* (\w+)$/x)
            {
#               $alt = $cvt_alt{$2};
#               @alts = ($1, $3);
               $field = { alt => $cvt_alt{$2}, fields => [$1, $3] };
            }
            elsif ($field !~ /^\w+$/)
            {
               die "$file, line $.: illegal field name \"$field\"\n";
            }
         }

         $self->{'fields'}{$type}{$group} = \@fields;
      }
   }

   $self;
}

=item known_type

=item required_fields

=item optional_fields

=cut


# quicky query methods

sub known_type
{
   my ($self, $type) = @_;

   exists $self->{'fields'}{$type};
}

sub required_fields 
{
   my ($self, $type) = @_;

   croak "unknown entry type \"$type\" for $self->{'name'} structure"
      unless exists $self->{'fields'}{$type};
   @{$self->{'fields'}{$type}{'required'}};
}

sub optional_fields 
{
   my ($self, $type) = @_;

   croak "unknown entry type \"$type\" for $self->{'name'} structure"
      unless exists $self->{'fields'}{$type};
   @{$self->{'fields'}{$type}{'optional'}};
}


=back

=head2 Methods of C<Text::BibTeX::Entry> class

=over

=item check_type

=item check_required_fields

=item check_optional_fields

=item check

=item coerce

=item silently_corce

=cut



# ----------------------------------------------------------------------
# Text::BibTeX::Entry methods dealing with entry structure

package Text::BibTeX::Entry;

import Text::BibTeX::Structure qw(find_structure);

sub check_type
{
   my ($entry, $structure, $warn) = @_;

   $structure = find_structure ($structure);
   my $type = $entry->type;
   if (! $structure->known_type ($type))
   {
      $entry->warn ("unknown entry type \"$type\"") if $warn;
      return 0;
   }
   return 1;
}

sub check_required_fields
{
   my ($entry, $structure, $warn, $coerce) = @_;
   my ($field, $alt, $alt0, $alt1, $e_alt0, $e_alt1, $warning);
   my $num_errors = 0;

   $structure = find_structure ($structure);
   
   foreach $field ($structure->required_fields ($entry->type))
   {
      if (ref $field eq 'HASH')         # really a list of alternate fields
      {
         $alt = $field->{'alt'};
         confess ("can't handle more than two alternates")
            if @{$field->{'fields'}} > 2;
         confess ("bogus alternator \"$alt\"")
            unless $alt =~ /^(xor|or)$/;

         ($alt0,$alt1) = @{$field->{'fields'}}[0,1];
         $e_alt0 = $entry->exists ($alt0);
         $e_alt1 = $entry->exists ($alt1);

         if ($alt eq 'xor' && $e_alt0 == $e_alt1)
         {
            $warning = "exactly one of $alt0 and $alt1 must be given";
            if ($coerce)
            {
               $warning .= " (discarding $alt1)";
               $entry->delete_field ($alt1);
            }
            $entry->warn ("$warning");
            $num_errors++;
         }
         elsif ($alt eq 'or' && !($e_alt0 || $e_alt1))
         {
            $warning = "one or both of $alt0 and $alt1 must be given";
            if ($coerce)
            {
               $warning .= " (assuming empty string for $alt0)";
               $entry->set ($alt0, '');
            }
            $entry->warn ("$warning");
            $num_errors++;
         }
      }
      elsif (! ref $field)              # it's just a string
      {
         if (! $entry->exists ($field))
         {
            $warning = "required field $field not present";
            if ($coerce)
            {
               $warning .= " (assuming empty string)";
               $entry->set ($field, '');
            }
            $entry->warn ("$warning");
            $num_errors++;
         }
      }
      else                              # some other reference -- bogus!
      {
         confess ("found a non-hash ref -- corrupt data structure");
      }
   }

   return ($num_errors == 0);           # no errors = success
}


sub check_optional_fields
{
   my ($entry, $structure, $warn, $coerce) = @_;
   my ($field, $alt, $alt0, $alt1, $e_alt0, $e_alt1, $warning);
   my $num_errors = 0;
   
   $structure = find_structure ($structure);
   
   foreach $field ($structure->optional_fields ($entry->type))
   {
      if (ref $field eq 'HASH')         # really a list of alternate fields
      {
         $alt = $field->{'alt'};
         confess ("can't handle more than two alternates")
            if @{$field->{'fields'}} > 2;
         confess ("bogus alternator \"$alt\"")
            unless $alt =~ /^(xor|or)$/;

         ($alt0,$alt1) = @{$field->{'fields'}}[0,1];
         $e_alt0 = $entry->exists ($alt0);
         $e_alt1 = $entry->exists ($alt1);

         if ($alt eq 'xor' && $e_alt0 && $e_alt1)
         {
            $warning = "at most one of $alt0 and $alt1 may be present";
            if ($coerce)
            {
               $warning .= " (discarding $alt1)";
               $entry->delete_field ($alt1);
            }
            $entry->warn ("$warning");
         }
      }
      elsif (ref $field)                # bogus!
      {
         confess ("found a non-hash ref -- corrupt data structure");
      }

      # else, do nothing -- we don't care if an optional field is present
      # or not
   }

   return ($num_errors == 0);

}


sub check 
{
   my ($entry, $structure) = @_;
   my ($ok_req, $ok_opt);

   return 1 if $entry->type =~ /^(string|comment|preamble)$/;
   return unless $entry->check_type ($structure, 1);
   $ok_req = $entry->check_required_fields ($structure, 1, 0);
   $ok_opt = $entry->check_optional_fields ($structure, 1, 0);
   $ok_req && $ok_opt;
}


# Arg! -- need to think more about return value.  Bad type is a failed
# coercion, but if we actually found problems (and overrode them) is that
# still failure?

sub coerce
{
   my ($entry, $structure) = @_;
   my ($ok_req, $ok_opt);

   return 1 if $entry->type =~ /^(string|comment|preamble)$/;
   return unless $entry->check_type ($structure, 1);
   $ok_req = $entry->check_required_fields ($structure, 1, 1);
   $ok_opt = $entry->check_optional_fields ($structure, 1, 1);
   $ok_req && $ok_opt;
}


sub silently_coerce
{
   my ($entry, $structure) = @_;
   my ($ok_req, $ok_opt);

   return 1 if $entry->type =~ /^(string|comment|preamble)$/;
   return unless $entry->check_type ($structure, 1);
   $ok_req = $entry->check_required_fields ($structure, 0, 1);
   $ok_opt = $entry->check_optional_fields ($structure, 0, 1);
   $ok_req && $ok_opt;
}

1;
