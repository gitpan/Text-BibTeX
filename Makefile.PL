use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile (
    'NAME'	=> 'Text::BibTeX',
    'VERSION_FROM' => 'BibTeX.pm', # finds $VERSION
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '-Ibtparse',
    'MYEXTLIB'  => 'btparse/libbtparse$(LIB_EXT)',
    'dist'      => { COMPRESS => "gzip", SUFFIX => "gz" }
);

sub MY::postamble {
'
$(MYEXTLIB):
	cd btparse && $(MAKE)
';
}

my $btparse_version = 0.21;
my $btparse_release = "btparse-${btparse_version}";
my $btparse_archive = "${btparse_release}.tar.gz";


# This stuff is arranged so that I don't need to keep a complete copy of
# the btparse distribution around for the development copy of Text::BibTeX,
# but can still have Makefile.PL take care of unpacking btparse for
# building anywhere else.

if (! -l "btparse")
{
   if (! -d $btparse_release)           # btparse archive not unpacked?
   {
      $| = 1;
      if (! -e $btparse_archive)
      {
         die "Couldn't find $btparse_archive either in . or .. -- please\n" .
             "put it in one of those directories before proceeding\n"
            unless (-e "../$btparse_archive");
         $btparse_archive = "../$btparse_archive";
      }         

      print "Unpacking $btparse_archive...";
      system "gzip -dc $btparse_archive | tar xf -";
      die "unpacking failed\n" if $?;
      print "\n";
   }

   print "Creating symlink: btparse -> $btparse_release\n";
   symlink ($btparse_release, "btparse")
      || die "symlink failed: $!\n";
}
