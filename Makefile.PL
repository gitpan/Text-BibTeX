use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile (
    'NAME'	=> 'Text::BibTeX',
    'VERSION_FROM' => 'BibTeX.pm', # finds $VERSION
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '',     # e.g., '-I/usr/include/other' 
    'MYEXTLIB'  => 'btparse/libbtparse$(LIB_EXT)',
    'dist' => { COMPRESS=>"gzip", SUFFIX=>"gz" }
);

sub MY::postamble {
'
$(MYEXTLIB): btparse-0.1/Makefile
	cd btparse-0.1 && $(MAKE)
';
}

if (! -d "btparse-0.1")
{
   warn <<ERR;

You haven't unpacked and built the btparse package.  Please read the README
file for instructions on building btparse and Text::BibTeX before proceeding.
ERR
}

if (! -l "btparse")
{
   warn "\nCreating symlink: btparse -> btparse-0.1\n";
   symlink ("btparse-0.1", "btparse")
      || warn "symlink failed: $!\n";
}
