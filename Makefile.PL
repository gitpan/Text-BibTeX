require 5.004;
use ExtUtils::MakeMaker;
use File::Basename;

my $btparse_version = 0.3;
my $btparse_release = "btparse-${btparse_version}";
my $btparse_archive; # = "${btparse_release}.tar.gz";

sub find_btparse
{
   my ($version_pattern, $dirs) = @_;

   sub latest_file
   {
      my @files = @_;
      my %mtime = map (($_ => (stat $_)[9]), @files);
      return (sort { $mtime{$a} <=> $mtime{$b} } @files)[-1];
   }

   my ($dir, @files, @dirs);
   my $release = "btparse-$version_pattern";
   local *DIR;
   for my $dir (@$dirs)
   {
      opendir (DIR, $dir) || die "Couldn't open $dir: $!\n";
      my @all_files = map ("$dir/$_", readdir (DIR));
      push (@dirs, grep (-d && /\/$release$/, @all_files));
      push (@files, grep (-f && /\/$release\.tar(\.(g?z|Z))?$/, @all_files));
      closedir (DIR);
   }


   # If no release directories were found, try looking for archive files.

   if (@dirs == 0)
   {
      # If no archive files were found, we failed -- crash 
      if (@files == 0)                  # found nothing applicable
      {
         die <<MSG;
Couldn\'t find appropriate distribution directory ("$release")
or archive file "$release\\.tar" in @$dirs
MSG
      }

      # Multiple archive files found -- warn and pick the latest one
      # (according to file mtime)
      elsif (@files > 1)
      {
         my $file = latest_file (@files);
         warn <<WARN;
Found multiple files matching "$release\\.tar" in @$dirs 
-- using $file because it\'s the latest
WARN
         return $file;
      }

      # Good, exactly one archive file found -- return it
      else
      {
         return $files[0];
      }
   }

   # Multiple directories found -- warn and pick the latest one
   elsif (@dirs > 1)
   {
      my $dir = latest_file (@dirs);
      warn <<WARN;
Found multiple directories matching "$release" in @$dirs 
-- using $dir because it\'s the latest
WARN
      return $dir;
   }

   # Exactly one directory found -- return it
   else
   {
      return $dirs[0];
   }
      
}


# This stuff is arranged so that I don't need to keep a complete copy of
# the btparse distribution around for the development copy of Text::BibTeX,
# but can still have Makefile.PL take care of unpacking btparse for
# building anywhere else.

if (! -l "btparse")
{
   my $btparse_release = find_btparse ('0.30.*', ['.', '..']);
   print "Found btparse release in $btparse_release\n";

   if (-f $btparse_release)             # assume it's a tar file to unpack
   {
      $| = 1;
      print "Unpacking $btparse_release...";
      system "gzip -dc $btparse_release | tar xf -";
      die "unpacking failed\n" if $?;
      print "\n";

      # strip off directory and extension(s) -- this should just give
      # us the name of the directory we just unpacked to
      $btparse_release = fileparse ($btparse_release, '\.tar.*', '\.zip');
      die <<ERR
Directory "$btparse_release" doesn't exist, but it should have
been created when we unpacked the archive file.
ERR
         unless -d $btparse_release;
   }

   print "Creating symlink: btparse -> $btparse_release\n";
   symlink ($btparse_release, "btparse")
      || die "symlink failed: $!\n";

   print "Don't forget to configure btparse (if you haven't already) before continuing\n";
}


my @support_files = ('btxs_support$(OBJ_EXT)');

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile (
    'NAME'	=> 'Text::BibTeX',
    'VERSION_FROM' => 'BibTeX.pm',
    'XSPROTOARG' => '-prototypes',
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '-Ibtparse',
    'MYEXTLIB'  => 'btparse/libbtparse$(LIB_EXT)',
    'OBJECT'    => 'BibTeX$(OBJ_EXT) ' . join (' ', @support_files),
    'dynamic_lib' => { INST_DYNAMIC_DEP => join (' ', @support_files) },
    'dist'      => { COMPRESS => "gzip", SUFFIX => "gz" }
);


# -- Overrides ---------------------------------------------------------
package MY;

sub dist
{
   local $_ = shift->SUPER::dist;
   s/CI \s* = \s* .*/CI = true/mx;
   s/-Nv/-sRel -N\$(NAME_SYM)_v/m;
   return $_;
}

sub postamble
{
'
$(MYEXTLIB):
	cd btparse && $(MAKE)
';
}

sub manifypods
{
   local $_ = shift->SUPER::manifypods (@_);
   s/Text::btool_faq/btool_faq/;
   return $_;
}
