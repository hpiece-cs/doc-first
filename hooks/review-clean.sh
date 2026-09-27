#!/usr/bin/env bash
#
# doc-first change-review cleaner
#
# Removes change-review markup from src-notes documents so that a document
# reviewed before a source change becomes the current source guide again.
#
# Usage:
#   review-clean.sh FILE...           # clean each file in place
#   review-clean.sh --check FILE...   # report remaining markup, change nothing
#
# Exit codes:
#   0  no markup / cleaned
#   1  markup remains (check mode, or malformed markup left after cleaning)
#   2  usage error, perl missing, file missing, read/write failure,
#      unclosed review block
#
# Markup format: references/src-note-contract.md ("Change-review markup
# rules"). Fenced code blocks and inline code are never touched, except
# Mermaid blocks, where review class definitions and "<br/>current ..."
# hints are removed.

set -o pipefail

usage() {
  cat <<'USAGE'
Usage: review-clean.sh [--check] FILE...
  (no option)  remove change-review markup in place
  --check      report remaining change-review markup without changing files
USAGE
}

# Perl does the per-file work: clean_file [F-02] and find_markup [F-03].
read -r -d '' PERL_PROG <<'PERL' || true
use strict;
use warnings;
use Encode qw(decode);

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

my ($mode, $path) = @ARGV;
my $display_path = decode('UTF-8', $path);

# Line markers: U+1F7E2 green (added), U+1F7E0 orange (changed), U+1F534 red (removed)
my $KEEP_MARK      = qr/[\x{1F7E2}\x{1F7E0}]/;
my $DELETE_MARK    = qr/\x{1F534}/;
my $ANY_MARK       = qr/[\x{1F7E2}\x{1F7E0}\x{1F534}]/;
my $LINE_LEAD      = qr/^(\s*(?:[-*+]\s+|>\s*)?)/;
# Review block marker lines: "🔍 **리뷰 블록 시작/끝**" or "🔍 **Review block start/end**".
# Bold and surrounding spaces are optional.
my $SEARCH_ICON    = "\x{1F50D}";
my $BLOCK_WORDS_KO = "\x{B9AC}\x{BDF0} \x{BE14}\x{B85D}";   # Korean "review block"
my $START_WORD_KO  = "\x{C2DC}\x{C791}";                     # Korean "start"
my $END_WORD_KO    = "\x{B05D}";                              # Korean "end"
my $REVIEW_START   = qr/^\s*$SEARCH_ICON\s*(?:\*\*)?\s*(?:$BLOCK_WORDS_KO $START_WORD_KO|Review block start)\s*(?:\*\*)?\s*$/i;
my $REVIEW_END     = qr/^\s*$SEARCH_ICON\s*(?:\*\*)?\s*(?:$BLOCK_WORDS_KO $END_WORD_KO|Review block end)\s*(?:\*\*)?\s*$/i;
my $CHANGE_WORD    = qr/(?:\x{BCC0}\x{ACBD}|change)/;   # Korean "byeongyeong" | "change"
my $CURRENT_WORD   = qr/(?:\x{D604}\x{C7AC}|current)/;  # Korean "hyeonjae" | "current"
my $REVIEW_CLASSES = qr/(?:added|changed|removed|same)/;
my $EM_DASH        = "\x{2014}";
my $MIDDLE_DOT     = "\x{00B7}";
my $CODE_OPEN      = "\x{E000}";   # private-use placeholders for inline code
my $CODE_CLOSE     = "\x{E001}";
my $STRUCK         = qr/~~(?:[^~]|~(?!~))+?~~/;   # ~~text~~, single ~ allowed inside

sub read_lines {
  open(my $in, '<:encoding(UTF-8)', $path)
    or do { print STDERR "[doc-first] cannot read $display_path: $!\n"; exit 2 };
  my @lines = <$in>;
  close $in;
  return @lines;
}

# Replace inline code spans with placeholders so markup rules never touch them.
sub protect_inline_code {
  my ($line) = @_;
  my @spans;
  $line =~ s{(`+)(?:.*?[^`])?\1(?!`)}{ push @spans, $&; $CODE_OPEN . $#spans . $CODE_CLOSE }ge;
  return ($line, \@spans);
}

sub restore_inline_code {
  my ($line, $spans) = @_;
  $line =~ s{\Q$CODE_OPEN\E(\d+)\Q$CODE_CLOSE\E}{$spans->[$1]}g;
  return $line;
}

sub indent_width {
  my ($text) = @_;
  $text =~ /^(\s*)/;
  return length $1;
}

# Tag every line with its context: review_start, review_end, fence
# (fence line or inside a non-Mermaid code block), mermaid, text.
sub classify_lines {
  my (@lines) = @_;
  my @tagged;
  my $fence = '';
  my $in_mermaid = 0;
  for my $index (0 .. $#lines) {
    my $raw = $lines[$index];
    (my $text = $raw) =~ s/\r?\n\z//;
    my $kind;
    if ($fence eq '') {
      if    ($text =~ $REVIEW_START) { $kind = 'review_start'; }
      elsif ($text =~ $REVIEW_END)   { $kind = 'review_end'; }
      elsif ($text =~ /^\s*(`{3,}|~{3,})\s*([\w-]*)/) {
        $fence = $1;
        $in_mermaid = (lc($2) eq 'mermaid') ? 1 : 0;
        $kind = 'fence';
      }
      else { $kind = 'text'; }
    } else {
      my $fence_char = substr($fence, 0, 1);
      if ($text =~ /^\s*(\Q$fence_char\E{3,})\s*$/ && length($1) >= length($fence)) {
        $fence = '';
        $in_mermaid = 0;
        $kind = 'fence';
      } else {
        $kind = $in_mermaid ? 'mermaid' : 'fence';
      }
    }
    push @tagged, { number => $index + 1, raw => $raw, text => $text, kind => $kind };
  }
  return @tagged;
}

sub is_review_mermaid_line {
  my ($text) = @_;
  return $text =~ /^\s*classDef\s+$REVIEW_CLASSES\b/
      || $text =~ /^\s*class\s+\S+\s+$REVIEW_CLASSES\s*;?\s*$/;
}

# F-03: line numbers and text of remaining change-review markup.
sub find_markup {
  my (@lines) = @_;
  my @found;
  for my $line (classify_lines(@lines)) {
    my ($kind, $text) = ($line->{kind}, $line->{text});
    my $hit = 0;
    if ($kind eq 'review_start' || $kind eq 'review_end') {
      $hit = 1;
    } elsif ($kind eq 'mermaid') {
      $hit = is_review_mermaid_line($text) || $text =~ /<br\s*\/?>$CURRENT_WORD /;
    } elsif ($kind eq 'text') {
      my ($protected) = protect_inline_code($text);
      $hit = $protected =~ /$LINE_LEAD$ANY_MARK/
          || $protected =~ $STRUCK
          || $protected =~ /<\/?ins>/;
    }
    push @found, [$line->{number}, $text] if $hit;
  }
  return @found;
}

sub report {
  my ($title, @found) = @_;
  print "[doc-first] $title: $display_path\n";
  print "  line $_->[0]: $_->[1]\n" for @found;
}

# Remove markers, the TOC change suffix, and old values from one text line.
sub clean_text_line {
  my ($protected) = @_;
  $protected =~ s/$LINE_LEAD$KEEP_MARK+[ \t]/$1/;
  $protected =~ s/\s+$EM_DASH\s+$CHANGE_WORD\s+\d+(?:$MIDDLE_DOT\d+)*\s*$//;
  $protected =~ s/$STRUCK \*\*(.+?)\*\*/$1/g;   # pair first: keep the new value
  $protected =~ s/<\/?ins>//g;
  $protected =~ s/ ?$STRUCK//g;                      # then lone deletions
  return $protected;
}

# F-02: clean one file in place. Returns the cleaned lines.
sub clean_file {
  my (@lines) = @_;
  my @output;
  my $last_was_blank = 0;
  my $in_review = 0;
  my $review_start_line = 0;
  my $deleted_item_indent = -1;

  my $emit = sub {
    my ($line, $inside_code) = @_;
    my $is_blank = ($line =~ /^\s*$/) ? 1 : 0;
    return if !$inside_code && $is_blank && $last_was_blank;
    $last_was_blank = (!$inside_code && $is_blank) ? 1 : 0;
    push @output, $line;
  };

  for my $line (classify_lines(@lines)) {
    my ($kind, $text, $raw) = ($line->{kind}, $line->{text}, $line->{raw});
    my $newline = substr($raw, length $text);

    # (1) review block
    if ($in_review) {
      $in_review = 0 if $kind eq 'review_end';
      next;
    }
    if ($kind eq 'review_start') {
      $in_review = 1;
      $review_start_line = $line->{number};
      next;
    }
    next if $kind eq 'review_end';   # stray end marker

    # (2) code blocks
    if ($kind eq 'fence') {
      $deleted_item_indent = -1;
      $emit->($raw, 1);
      next;
    }
    if ($kind eq 'mermaid') {
      next if is_review_mermaid_line($text);
      $text =~ s/<br\s*\/?>$CURRENT_WORD [^"]*//g;
      $emit->($text . $newline, 1);
      next;
    }

    # (3) continuation lines of a deleted item
    if ($deleted_item_indent >= 0) {
      next if $text =~ /\S/ && indent_width($text) > $deleted_item_indent;
      $deleted_item_indent = -1;
    }

    # (4) deleted item
    my ($protected, $spans) = protect_inline_code($text);
    if ($protected =~ /$LINE_LEAD$KEEP_MARK*$DELETE_MARK/) {
      $deleted_item_indent = indent_width($text);
      next;
    }

    # (5) markers, TOC suffix, old values
    $emit->(restore_inline_code(clean_text_line($protected), $spans) . $newline, 0);
  }

  if ($in_review) {
    print STDERR "[doc-first] unclosed review block starting at line $review_start_line: $display_path\n";
    exit 2;
  }
  return @output;
}

sub write_file {
  my ($content) = @_;
  my $temp_path = "$path.review-clean.$$";
  open(my $out, '>:encoding(UTF-8)', $temp_path)
    or do { print STDERR "[doc-first] cannot write $display_path: $!\n"; exit 2 };
  print $out $content;
  close($out)
    or do { print STDERR "[doc-first] cannot write $display_path: $!\n"; unlink $temp_path; exit 2 };
  rename($temp_path, $path)
    or do { print STDERR "[doc-first] cannot replace $display_path: $!\n"; unlink $temp_path; exit 2 };
}

my @lines = read_lines();

if ($mode eq 'check') {
  my @found = find_markup(@lines);
  if (@found) {
    report('review markup found', @found);
    exit 1;
  }
  exit 0;
}

my @cleaned = clean_file(@lines);
my $before = join('', @lines);
my $after  = join('', @cleaned);
write_file($after) if $after ne $before;

my @left = find_markup(@cleaned);
if (@left) {
  report('markup left after cleanup (fix these lines to the documented format and re-run)', @left);
  exit 1;
}
if ($after ne $before) {
  print "[doc-first] cleaned: $display_path\n";
} else {
  print "[doc-first] no review markup: $display_path\n";
}
exit 0;
PERL

# ---- main [F-01] ----------------------------------------------------------

MODE="clean"
FILES=()
for arg in "$@"; do
  case "$arg" in
    --check)   MODE="check" ;;
    -h|--help) usage; exit 0 ;;
    --*)       usage >&2; exit 2 ;;
    *)         FILES+=("$arg") ;;
  esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  usage >&2
  exit 2
fi

if ! command -v perl >/dev/null 2>&1; then
  echo "[doc-first] perl not found" >&2
  exit 2
fi

worst_status=0
for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "[doc-first] file not found: $file" >&2
    file_status=2
  else
    perl -e "$PERL_PROG" -- "$MODE" "$file"
    file_status=$?
  fi
  if (( file_status > worst_status )); then
    worst_status=$file_status
  fi
done

exit "$worst_status"
