#!/usr/bin/env perl
# Moves one section of scripts/player.gd into its own component script
# (scripts/player/<file>.gd, class <Class>, held by the player in var <var>).
#   perl tools/split_section.pl <start_line> <end_line> <file> <Class> <var>
# Lines are 1-based and inclusive (a whole "# --- ... ---" section).
#
# In the moved code:   a player instance member -> p.member, a player const or
#                      static function -> Player.NAME, self -> p, members of an
#                      already split component -> p.<var>.member / <Class>.NAME.
# In player.gd:        a moved instance member -> <var>.member, a moved const or
#                      static -> <Class>.NAME; public functions other scripts may
#                      call (no leading _) get a one-line forward; public vars and
#                      consts read from outside get a forward too.
# In other components: p.member / Player.NAME of a moved member -> p.<var>.member / <Class>.NAME.
# Local variables, parameters, comments and strings are left alone.
# Afterwards: godot --headless --import, parse check, tools/test.sh.
use strict;
use warnings;

my ($start, $end, $file, $class, $var) = @ARGV;
die "usage: start end file Class var\n" unless defined $var;
my $root = ".";
my $player = "$root/scripts/player.gd";
my $kit_dir = "$root/scripts/player";
my $registry = "$kit_dir/kits.txt";   # one line per component: var Class file

open(my $fh, '<', $player) or die $!;
my @lines = <$fh>;
close $fh;
my @section = @lines[$start - 1 .. $end - 1];
my @rest = (@lines[0 .. $start - 2], @lines[$end .. $#lines]);

# --- Who is what -------------------------------------------------------------
my %BUILTIN = map { $_ => 1 } qw(global_position global_transform position rotation velocity transform
	is_inside_tree get_tree get_viewport get_node_or_null get_node get_instance_id is_in_group has_method
	get_parent add_child get_world_3d is_on_floor look_at name visible get_children set_meta get_meta has_meta
	add_to_group remove_from_group global_rotation basis scale is_queued_for_deletion);
# Consts every component already has (scripts/player/player_kit.gd).
my %KIT_CONSTS = map { $_ => 1 } qw(Combat Stats StatusContainer Abilities Balance ARROW Items Runes Macros
	DamageInfo SHIELDS PlayerDataScript);

sub members {
	my %m;
	for (@_) {
		if (/^static func (\w+)/) { $m{$1} = 'static'; }
		elsif (/^func (\w+)/) { $m{$1} = 'func'; }
		elsif (/^(?:\@\w+ )?var (\w+)/) { $m{$1} = 'var'; }
		elsif (/^const (\w+)/) { $m{$1} = 'const'; }
		elsif (/^enum (\w+)/) { $m{$1} = 'const'; }
		elsif (/^signal (\w+)/) { $m{$1} = 'signal'; }
	}
	return %m;
}
my %core = members(@rest);
my %mine = members(@section);
for (keys %mine) { delete $core{$_}; }

# Components already split: var -> Class, and their members.
my @kits;
if (open(my $r, '<', $registry)) {
	while (<$r>) { chomp; next unless /\S/; my ($v, $c, $f) = split /\s+/; push @kits, [$v, $c, $f]; }
	close $r;
}
my %other;   # member -> [var, Class, kind]
for my $k (@kits) {
	open(my $kf, '<', "$kit_dir/$k->[2]") or next;
	my %km = members(<$kf>);
	close $kf;
	$other{$_} = [$k->[0], $k->[1], $km{$_}] for keys %km;
}

# --- Rewriting identifiers outside strings and comments, minding locals --------
# $resolve->(name, \%locals) returns the replacement text or undef.
sub rewrite {
	my ($text_lines, $resolve, $dot_prefix) = @_;
	my @out;
	my %locals;
	for my $line (@$text_lines) {
		if ($line =~ /^(?:static )?func \w+\s*\(([^)]*)\)/) {
			%locals = ();
			for my $p (split /,/, $1) { $locals{$1} = 1 if $p =~ /^\s*(\w+)/; }
		}
		$locals{$1} = 1 while $line =~ /\bvar\s+(\w+)/g;
		$locals{$1} = 1 while $line =~ /\bfor\s+(\w+)\s+in\b/g;
		while ($line =~ /\bfunc\s*\(([^)]*)\)/g) {
			for my $p (split /,/, $1) { $locals{$1} = 1 if $p =~ /^\s*(\w+)/; }
		}
		my $new = '';
		my $i = 0;
		my $len = length $line;
		my $instr = '';
		while ($i < $len) {
			my $ch = substr($line, $i, 1);
			if ($instr ne '') {
				$new .= $ch;
				if ($ch eq '\\') { $new .= substr($line, $i + 1, 1); $i += 2; next; }
				$instr = '' if $ch eq $instr;
				$i++; next;
			}
			if ($ch eq '"' || $ch eq "'") { $instr = $ch; $new .= $ch; $i++; next; }
			if ($ch eq '#') { $new .= substr($line, $i); last; }
			if (substr($line, $i) =~ /^([A-Za-z_]\w*)/) {
				my $word = $1;
				my $prev = $i > 0 ? substr($line, $i - 1, 1) : '';
				my $prev_nonspace = '';
				if ($new =~ /(\S)\s*$/) { $prev_nonspace = $1; }
				my $rep;
				# A bare name (not after "." or "$" or "@" or "%"), or (for other components) after "p." / "Player."
				if ($prev ne '.' && $prev ne '$' && $prev ne '@' && $prev ne '%' && !$locals{$word}) {
					$rep = $resolve->($word, 'bare');
				} elsif ($dot_prefix && $prev eq '.') {
					$rep = $resolve->($word, 'dot', \$new);
				}
				$new .= defined $rep ? $rep : $word;
				$i += length $word;
				next;
			}
			$new .= $ch;
			$i++;
		}
		push @out, $new;
	}
	return @out;
}

# The moved code.
my @moved = rewrite(\@section, sub {
	my ($w, $how) = @_;
	return undef unless $how eq 'bare';
	return undef if $mine{$w} || $KIT_CONSTS{$w};
	return 'player' if $w eq 'self';
	if (my $o = $other{$w}) {
		return ($o->[2] eq 'const' || $o->[2] eq 'static') ? "$o->[1].$w" : "player.$o->[0].$w";
	}
	if (my $k = $core{$w}) {
		return ($k eq 'const' || $k eq 'static') ? "Player.$w" : "player.$w";
	}
	return "player.$w" if $BUILTIN{$w};
	return undef;
}, 0);

# player.gd without the section, references pointed at the component.
my @core_out = rewrite(\@rest, sub {
	my ($w, $how) = @_;
	return undef unless $how eq 'bare';
	my $k = $mine{$w} or return undef;
	return ($k eq 'const' || $k eq 'static') ? "$class.$w" : "$var.$w";
}, 0);

# --- Forwards on the player for what other scripts call --------------------------
my $outside = '';
for my $f (glob("$root/scripts/*.gd"), glob("$root/scripts/*/*.gd"), glob("$root/scripts/*/*/*.gd")) {
	next if $f =~ m{scripts/player\.gd$} || $f =~ m{scripts/player/};
	open(my $o, '<', $f) or next; local $/; $outside .= <$o>; close $o;
}
my @forwards;
for my $line (@section) {
	if ($line =~ /^func ([a-z]\w*)\s*\(([^)]*)\)\s*(->\s*[^:]+)?:/) {
		my ($n, $params, $ret) = ($1, $2, $3 // '');
		my @names = map { /^\s*(\w+)/ ? $1 : () } split /,/, $params;
		my $call = "$var.$n(" . join(', ', @names) . ")";
		my $body = ($ret =~ /void/) ? $call : "return $call";
		push @forwards, "func $n($params) $ret:\n\t$body\n";
	} elsif ($line =~ /^(?:\@\w+ )?var ([a-z]\w*)\s*(?::\s*([\w\[\]]+))?/ && $outside =~ /\.\Q$1\E\b/) {
		my ($n, $t) = ($1, $2);
		my $type = defined $t ? ": $t" : '';
		push @forwards, "var $n$type:\n\tget:\n\t\treturn $var.$n\n\tset(v):\n\t\t$var.$n = v\n";
	} elsif ($line =~ /^const ([A-Z]\w*)/ && $outside =~ /\b(?:player|p|pl|owner_node|_player)\.\Q$1\E\b/) {
		push @forwards, "const $1 = $class.$1\n";
	}
}
s/\s+:\n/:\n/ for @forwards;

# --- Write -------------------------------------------------------------------------
mkdir $kit_dir unless -d $kit_dir;
open(my $k, '>', "$kit_dir/$file") or die $!;
print $k "extends \"res://scripts/player/player_kit.gd\"\nclass_name $class\n\n";
print $k "# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from\n";
print $k "# player.gd through its var \"$var\".\n";
print $k @moved;
close $k;

# Hook the component up in player.gd: its var (made in _init via _kit) and the forwards.
my $text = join('', @core_out);
my $decl = "var $var: $class = _kit($class) as $class\n";
$text =~ s/(# --- Components[^\n]*\n(?:#[^\n]*\n)*)/$1$decl/ or die "No '# --- Components' section in player.gd\n";
if (@forwards) {
	my $fw = "\n# Forwards to $class (called from other scripts).\n" . join("\n", @forwards);
	$text =~ s/(# --- End of components ---[^\n]*\n)/$fw\n$1/ or die "No '# --- End of components ---' line in player.gd\n";
}
open(my $out, '>', $player) or die $!;
print $out $text;
close $out;

# Other components: p.member / Player.NAME of what moved.
for my $kk (@kits) {
	my $path = "$kit_dir/$kk->[2]";
	open(my $kf, '<', $path) or next;
	my @kl = <$kf>;
	close $kf;
	my $changed = 0;
	for (@kl) {
		my $before = $_;
		s/\bplayer\.(\w+)/exists $mine{$1} ? (($mine{$1} eq 'const' || $mine{$1} eq 'static') ? "$class.$1" : "player.$var.$1") : "player.$1"/ge;
		s/\bPlayer\.(\w+)/exists $mine{$1} ? "$class.$1" : "Player.$1"/ge;
		$changed ||= $_ ne $before;
	}
	if ($changed) { open(my $w, '>', $path) or die $!; print $w @kl; close $w; }
}

open(my $reg, '>>', $registry) or die $!;
print $reg "$var $class $file\n";
close $reg;

# The moved names, for rewriting tests: kind name
open(my $mv, '>', "$kit_dir/.last_moved") or die $!;
print $mv "$_ $mine{$_}\n" for sort keys %mine;
close $mv;
printf "Moved %d lines to scripts/player/%s (%s, var %s); %d forwards.\n", scalar(@section), $file, $class, $var, scalar(@forwards);
