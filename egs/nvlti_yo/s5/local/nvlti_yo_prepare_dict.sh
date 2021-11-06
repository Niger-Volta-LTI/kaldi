#!/usr/bin/env bash

# Copyright 2021 Niger-Volta Language Technologies Institute
# Apache 2.0

# Prepares the dictionary and auto-generates the pronunciations for the words,
# that are in our vocabulary

stage=0
cmd=run.pl

. utils/parse_options.sh || exit 1;
. ./path.sh || exit 1


if [ $# -ne 3 ]; then
  echo "Usage: $0 [options] <train_text_path> <dev_text_path> <dst-dir>"
  echo "e.g.: data/local/lm data/train_clean_5 data/dev_clean_2 data/local/dict_nosp"
  echo "Options:"
  echo "  --cmd '<command>'    # script to launch jobs with, default: run.pl"
  exit 1
fi


############################################################################################
# Setup 
train_text_path=$1
dev_text_path=$2
dst_dir=$3      # data/local/dict_nosp

tempdir=data/temp_working_dir
mkdir -p $tempdir || exit 1;

vocab=$tempdir/raw_vocab.txt
combined_text=$tempdir/combined_text.txt

# this file is created by the G2P steps below
lexicon_raw_nosil=$dst_dir/lexicon_raw_nosil.txt

mkdir -p $dst_dir || exit 1;


############################################################################################
# Prepare text, generate vocabulary file
if [ $stage -le 0 ]; then
  echo "Combining and filtering text from train & dev"
  awk '{$1=""}1' $train_text_path/text | awk '{$1=$1}1'  > $combined_text  || exit 1;
  awk '{$1=""}1' $dev_text_path/text   | awk '{$1=$1}1' >> $combined_text  || exit 1;

  # Lowercasing broken with underdot diacritics. grep broken for non-ascii accented chars, 
  # underdots, umlauts, etc. Moving to python to filter, lowercase, sort & deduping to make $vocab
  # cat $combined_text | grep -o -E '\w+' | tr '[A-Z]' '[a-z]' | sort | uniq > $vocab
  local/nvlti_yo_create_vocab_from_text.py $combined_text > $vocab

  [ ! -f $vocab ] && echo "$0: vocabulary file not found at $vocab" && exit 1;
  vocab_size=$(wc -l <$vocab)
  echo "Vocabulary size: $vocab_size"
fi


############################################################################################
# g2p in X-SAMPA
if [ $stage -le 2 ]; then
  local/g2p.py $vocab > $lexicon_raw_nosil || exit 1
fi

############################################################################################
# Generate other random files for Kaldi
if [ $stage -le 3 ]; then
  silence_phones=$dst_dir/silence_phones.txt
  optional_silence=$dst_dir/optional_silence.txt
  nonsil_phones=$dst_dir/nonsilence_phones.txt
  extra_questions=$dst_dir/extra_questions.txt

  echo "Preparing phone lists and clustering questions"
  (echo SIL; echo SPN;) > $silence_phones
  echo SIL > $optional_silence
  # nonsilence phones; on each line is a list of phones that correspond
  # really to the same base phone.
  awk '{for (i=2; i<=NF; ++i) { print $i; gsub(/[0-9]/, "", $i); print $i}}' $lexicon_raw_nosil |\
    sort -u |\
    perl -e 'while(<>){
      chop; m:^([^\d]+)(\d*)$: || die "Bad phone $_";
      $phones_of{$1} .= "$_ "; }
      foreach $list (values %phones_of) {print $list . "\n"; } ' | sort \
      > $nonsil_phones || exit 1;
  # A few extra questions that will be added to those obtained by automatically clustering
  # the "real" phones.  These ask about stress; there's also one for silence.
  cat $silence_phones| awk '{printf("%s ", $1);} END{printf "\n";}' > $extra_questions || exit 1;
  cat $nonsil_phones | perl -e 'while(<>){ foreach $p (split(" ", $_)) {
    $p =~ m:^([^\d]+)(\d*)$: || die "Bad phone $_"; $q{$2} .= "$p "; } } foreach $l (values %q) {print "$l\n";}' \
    >> $extra_questions || exit 1;
  echo "$(wc -l <$silence_phones) silence phones saved to: $silence_phones"
  echo "$(wc -l <$optional_silence) optional silence saved to: $optional_silence"
  echo "$(wc -l <$nonsil_phones) non-silence phones saved to: $nonsil_phones"
  echo "$(wc -l <$extra_questions) extra triphone clustering-related questions saved to: $extra_questions"
fi

if [ $stage -le 4 ]; then
  (echo '!SIL SIL'; echo '<SPOKEN_NOISE> SPN'; echo '<UNK> SPN'; ) |\
  cat - $lexicon_raw_nosil | sort | uniq >$dst_dir/lexicon.txt
  echo "Lexicon text file saved as: $dst_dir/lexicon.txt"
fi

exit 0
