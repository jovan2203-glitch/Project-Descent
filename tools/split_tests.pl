#!/usr/bin/env perl
# After tools/split_section.pl: points the tests at the components.
#   perl tools/split_tests.pl
# For every component in scripts/player/kits.txt:
#   - a static function or const read off the player script (_p().NAME, p.NAME,
#     _player().NAME, player_script.NAME) -> <Class>.NAME
#   - a private member reached on a player instance (pl.NAME, player.NAME) that the
#     player no longer has -> pl.<var>.NAME
# and every test that reads player.gd's source reads PlayerSource.text() instead
# (player.gd plus every component), so checks for code that moved still find it.
use strict;
use warnings;

my $kit_dir = "scripts/player";
open(my $r, '<', "$kit_dir/kits.txt") or die $!;
my @kits = map { chomp; [split /\s+/] } grep { /\S/ } <$r>;
close $r;
open(my $pf, '<', "scripts/player.gd") or die $!;
my $player_src = do { local $/; <$pf> };
close $pf;

my (%static, %inst);
for my $k (@kits) {
	my ($var, $class, $file) = @$k;
	open(my $f, '<', "$kit_dir/$file") or next;
	for (<$f>) {
		if (/^static func (\w+)/ || /^const (\w+)/ || /^enum (\w+)/) { $static{$1} = $class; }
		elsif (/^func (\w+)/ || /^(?:\@\w+ )?var (\w+)/) {
			my $n = $1;
			next if $n eq 'player';
			# Still reachable on the player (a forward)? Then leave the test alone.
			next if $player_src =~ /^(?:func|var|const) \Q$n\E\b/m;
			$inst{$n} = $var;
		}
	}
	close $f;
}

for my $t (glob("tests/test_*.gd")) {
	open(my $f, '<', $t) or next;
	my $src = do { local $/; <$f> };
	close $f;
	my $orig = $src;
	$src =~ s/FileAccess\.get_file_as_string\("res:\/\/scripts\/player\.gd"\)/PlayerSource.text()/g;
	$src =~ s/\b(?:_p\(\)|_player\(\)|player_script|p|ps)\.(\w+)/exists $static{$1} ? "$static{$1}.$1" : $&/ge;
	$src =~ s/\b(pl|player|me|guy|healer)\.(\w+)/exists $inst{$2} ? "$1.$inst{$2}.$2" : $&/ge;
	if ($src ne $orig) {
		open(my $w, '>', $t) or die $!;
		print $w $src;
		close $w;
		print "updated $t\n";
	}
}
