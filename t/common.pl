my $err_file = 't/errors';

END { unlink $err_file }


sub setup_stderr
{
   open (SAVE_STDERR, ">&STDERR")
      || die "couldn't save stderr: $!\n";
   open (STDERR, ">$err_file")
      || die "couldn't redirect stderr to $err_file: $!\n";
   STDERR->autoflush (1);

#   $SIG{'__WARN__'} = sub { print SAVE_STDERR @_ };
   $SIG{'__DIE__'} = sub
   {
      open (STDERR, '>&=' . fileno (SAVE_STDERR));
      die @_;
   };
}

sub warnings
{
   my @err;
   open (ERR, $err_file) || die "couldn't open $err_file: $!\n";
   chomp (@err = <ERR>);                # ???
   open (STDERR, ">$err_file")
      || die "couldn't redirect stderr to $err_file: $!\n";
   STDERR->autoflush (1);
   @err;
}

sub list_equal
{
   my ($eq, $a, $b) = @_;

   die "lequal: \$a and \$b not lists" 
      unless ref $a eq 'ARRAY' && ref $b eq 'ARRAY';

   return 0 unless @$a == @$b;          # compare lengths
   my @eq = map { &$eq ($a->[$_], $b->[$_]) } (0 .. $#$a);
   return 0 unless (grep ($_ == 1, @eq)) == @eq;
}

sub slist_equal
{
   my ($a, $b) = @_;
   list_equal (sub { $_[0] eq $_[1] }, $a, $b);
}

my $i = 1;
sub test
{
   my ($result) = @_;

   ++$i;
   printf "%s %d\n", ($result ? "ok" : "not ok"), $i;
}

sub test_entry
{
   my ($entry, $type, $key, $fields, $values) = @_;
   my ($i, @vals);

   test ($entry->parse_ok);
   test ($entry->type eq $type);
   test ($entry->key eq $key) if defined $key;
   test (slist_equal ([$entry->fieldlist], $fields));
   for $i (0 .. $#$fields)
   {
      test ($entry->get ($fields->[$i]) eq $values->[$i]);
   }

   @vals = $entry->get (@$fields);
   test (slist_equal (\@vals, $values));
}

1;
