require 5.004;
use ExtUtils::MakeMaker;
use File::Basename;

# $Id: Makefile.PL,v 1.12 1999/11/29 02:31:24 greg Exp $

my @btparse_versions = qw(0.30 0.31 0.32);


# Searches the specified @$search_dirs for either release directories or
# archive files of any of the btparse versions listed in @$versions;
# returns the name of whatever it finds (a single string, might be either a
# directory or file name).
sub find_btparse
{
   my ($versions, $search_dirs) = @_;

   # We'll look for things in reverse order by version, so be sure
   # we have a version list sorted that way.
   @versions = sort { $b <=> $a } @$versions;

   sub latest_file
   {
      my @files = @_;
      my %mtime = map (($_ => (stat $_)[9]), @files);
      return (sort { $mtime{$a} <=> $mtime{$b} } @files)[-1];
   }

   my ($dir, @archive_files, @release_dirs);
   local *DIR;
   DIR:
   for my $dir (@$search_dirs)
   {
      opendir (DIR, $dir) || die "Couldn't open $dir: $!\n";
      my @all_files = map ("$dir/$_", readdir (DIR));
      closedir (DIR);

      VERSION:
      for my $version (@versions)
      {
         my $release = "btparse-$version";
         @release_dirs = grep (-d && m+/$release$+, @all_files);
         @archive_files = grep (-f && m+/$release\.(tar(\.(g?z|Z))|tgz|zip)$+,
                                @all_files);
         last DIR if @release_dirs || @archive_files;
      }
   }

   my $extra_versions = join (", ", @versions[1..$#versions]);
   my $wanted_dirs = "btparse-$versions[0]";
   $wanted_dirs .= " or $extra_versions" if $extra_versions;

   my $search_dirs = join (" ", @$search_dirs);

   # If no release directories were found, try looking for archive files.

   if (@release_dirs == 0)
   {
      # If no archive files were found, we failed -- crash 
      if (@archive_files == 0)                  # found nothing applicable
      {
         warn <<MSG;
I couldn't find an acceptable version of btparse nearby, either
as a release directory ($wanted_dirs)
or archive file.  I'll try to download it from CPAN now.

MSG

         return download_btparse ($versions[0]);
      }

      # Multiple archive files found -- warn and pick the latest one
      # (according to file mtime)
      elsif (@archive_files > 1)
      {
         my $file = latest_file (@archive_files);
         warn <<WARN;
Found multiple archive files in @$search_dirs
-- using $file because it\'s the latest
WARN
         return $file;
      }

      # Good, exactly one archive file found -- return it
      else
      {
         return $archive_files[0];
      }
   }

   # Multiple directories found -- warn and pick the latest one
   elsif (@release_dirs > 1)
   {
      my $dir = latest_file (@release_dirs);
      warn <<WARN;
Found multiple release directories
-- using $dir because it\'s the latest
WARN
      return $dir;
   }

   # Exactly one directory found -- return it
   else
   {
      return $release_dirs[0];
   }
      
}  # find_btparse()


sub download_btparse
{
   my ($version) = @_;

   # Try to find a preferred CPAN mirror from the CPAN.pm config.
   my $cpan_url;
   eval { require CPAN::Config; $cpan_url = $CPAN::Config->{'urllist'}[0]; };
   if ($@ || !$cpan_url)
   {
      $cpan_url = 'http://www.cpan.org/';
      print "CPAN module not fully configured -- " .
            "using default CPAN site at $cpan_url\n";
   }
   else
   {
      $cpan_url .= '/' unless substr($cpan_url,-1,1) eq '/';
      print "Using your preferred CPAN mirror at $cpan_url\n";
   }

   my $cpan_dir = 'modules/by-authors/id/GWARD/';
   my $archive_file = "btparse-${version}.tar.gz";
   my $whole_url = $cpan_url . $cpan_dir . $archive_file;
   my $saved_archive = "../$archive_file";

   my $final = <<MSG;

You\'ll have to download it yourself and put it in the current
directory or its parent.
MSG

   # Use LWP::Simple for HTTP URLs
   if ($cpan_url =~ /^http:/)
   {
      eval { require LWP::Simple; require HTTP::Status; };
      if ($@)
      {
         die <<MSG;
I couldn't load the LWP::Simple and HTTP::Status modules, so I can't
download btparse from $whole_url
$final
MSG
      }
     
      print "Downloading btparse from $whole_url...\n";
      my $response = LWP::Simple::getstore ($whole_url, $saved_archive);
      unless (LWP::Simple::is_success ($response))
      {
         my $message = HTTP::Status::status_message ($response);
         die <<MSG;
I tried to download btparse from $whole_url,
but the download failed.  (The HTTP response was $response: $message.)
$final
MSG
      }

      print "Successfully downloaded btparse to $saved_archive\n";
      return $saved_archive;
   }

   elsif ($cpan_url =~ m|^ftp://([^/]+)(/.*)|)
   {
      my ($host, $dir) = ($1, $2);

      eval { require Net::FTP; };
      if ($@)
      {
         die <<MSG;
I couldn't load the Net::FTP module, so I can't download
btparse from $whole_url
$final
MSG
      }

      eval
      {
         print "Connecting to $cpan_url...\n";
         my $ftp = Net::FTP->new ($host) or die "$@\n";
         $ftp->login or die "login failed\n";
         $ftp->binary or die "couldn't set binary mode\n";
         $ftp->cwd ($dir) or die "couldn't chdir to $dir\n";
         $ftp->cwd ($cpan_dir) or die "couldn't chdir to $cpan_dir\n";

         print "Downloading $whole_url...\n";
         $ftp->get ($archive_file, $saved_archive)
            or die "download failed (file not there?)\n";
      };
      if ($@)
      {
         die <<MSG;
I was unable to download btparse from
$whole_url
The error message I got was: $@$final
MSG
      }

      print "Successfully downloaded btparse to $saved_archive\n";
      return $saved_archive;
   }

   else
   {
      die <<MSG;
I can't download btparse, because I don't know how to deal with the URL
$whole_url
$final
MSG
   }
            
}  # download_btparse()


# Takes the directory or filename returned by 'find_btparse()' and
# ensures that it is unpacked and ready to build.
sub unpack_btparse
{
   my ($versions, $search_dirs) = @_;

   if (-d "btparse")
   {
      print "btparse already unpacked to 'btparse' -- " .
            "no further detective work needed\n";
      return;
   }

   my $btparse_release = find_btparse ($versions, $search_dirs);
   print "Found btparse release in $btparse_release\n";

   if (-f $btparse_release)
   {
      $| = 1;
      my $cmd;
      if ($btparse_release =~ /\.tar\.(g?z|Z)$/)
         { $cmd = "gzip -dc $btparse_release | tar xf -"; }
      elsif ($btparse_release =~ /\.tar$/)
         { $cmd = "tar xf $btparse_release"; }
      elsif ($btparse_release =~ /\.zip$/)
         { $cmd = "unzip -d $btparse_release"; }
      
         
      print "Unpacking $btparse_release: $cmd\n";
      system $cmd;
      die "unpacking failed\n" if $?;

      # strip off directory and extension(s) -- this should just give
      # us the name of the directory we just unpacked to
      $btparse_release = fileparse ($btparse_release, '\.tar.*', '\.zip');
      if (! -d $btparse_release)
      {
         die <<ERR
Directory "$btparse_release" doesn't exist, but it should have
been created when we unpacked the archive file.
ERR
      }
   }

   print "Creating symlink: btparse -> $btparse_release\n";
   symlink ($btparse_release, "btparse")
      || die "symlink failed: $!\n";

}  # unpack_btparse ()


sub configure_btparse
{
   my ($dir) = @_;

   chdir $dir or die "couldn't chdir to $dir: $!\n";
   unless (-f "config.status" && -f "config.cache" &&
           -M "config.status" < -M "configure" &&
           -M "config.cache" < -M "configure")
   {
      print "btparse distribution in '$dir' is not configured; doing so now:\n";
      @cmd = ('sh', './configure');
      print "@cmd\n";
      system @cmd;
      die "configure failed\n" unless $? == 0;

   }

   chdir ".." or die "couldn't chdir to ..: $!\n";
   print "btparse distribution in '$dir' is configured and ready to build\n";
}

# -- BEGIN main --------------------------------------------------------


# This stuff is arranged so that I do not need to keep a complete copy of
# the btparse distribution around for the development copy of Text::BibTeX,
# but can still have Makefile.PL take care of unpacking btparse for
# building anywhere else.

unpack_btparse (\@btparse_versions, ['.', '..']);

my @support_files = ('btxs_support$(OBJ_EXT)');

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile (
    'NAME'	=> 'Text::BibTeX',
    'VERSION'   => '0.32',
    'XSPROTOARG' => '-prototypes',
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '-Ibtparse',
    'MYEXTLIB'  => 'btparse/libbtparse$(LIB_EXT)',
    'OBJECT'    => 'BibTeX$(OBJ_EXT) ' . join (' ', @support_files),
    'dynamic_lib' => { INST_DYNAMIC_DEP => join (' ', @support_files) },
    'dist'      => { COMPRESS => "gzip", SUFFIX => "gz" }
);

configure_btparse ('btparse');

# -- END main ----------------------------------------------------------


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
