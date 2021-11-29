#!/usr/bin/env bash

# Change this location to somewhere where you want to put the data.
data=./data/

. ./cmd.sh
. ./path.sh

# Setup paths per operating system
if [ "$(uname)" == "Darwin" ]; then                           #  Mac OS X platform

  lagos_nwu_corpus=/Users/iroro/github/yoruba-asr/data/lagos-nwu-corpus/
  slr86_corpus=/Users/iroro/github/yoruba-asr/data/slr86/

elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then    # GNU/Linux platform (AWS Spot)

  lagos_nwu_corpus=/home/ubuntu/github/yoruba-asr/data/lagos-nwu-corpus/
  slr86_corpus=/home/ubuntu/github/yoruba-asr/data/slr86/
  export LD_LIBRARY_PATH=/home/ubuntu/github/Kaldi/tools/openfst-1.7.2/lib:/home/ubuntu/github/Kaldi/src/base:/home/ubuntu/github/Kaldi/src/chain:/home/ubuntu/github/Kaldi/src/decoder:/home/ubuntu/github/Kaldi/src/feat:/home/ubuntu/github/Kaldi/src/fstext:/home/ubuntu/github/Kaldi/src/gmm:/home/ubuntu/github/Kaldi/src/hmm:/home/ubuntu/github/Kaldi/src/ivector:/home/ubuntu/github/Kaldi/src/kws:/home/ubuntu/github/Kaldi/src/lat:/home/ubuntu/github/Kaldi/src/lm:/home/ubuntu/github/Kaldi/src/matrix:/home/ubuntu/github/Kaldi/src/nnet:/home/ubuntu/github/Kaldi/src/nnet2:/home/ubuntu/github/Kaldi/src/nnet3:/home/ubuntu/github/Kaldi/src/online2:/home/ubuntu/github/Kaldi/src/rnnlm:/home/ubuntu/github/Kaldi/src/sgmm2:/home/ubuntu/github/Kaldi/src/transform:/home/ubuntu/github/Kaldi/src/tree:/home/ubuntu/github/Kaldi/src/util
fi


stage=0
. utils/parse_options.sh

set -euo pipefail
mkdir -p $data

# [IOHAVOC] don't yet need to download or untar into the right folder
# for part in dev_clean_2 train_clean_5; do
#   local/download_and_untar.sh $data $data_url $part
# done

#######################################################################
if [ $stage -le 0 ]; then
  # format the data as Kaldi data directories
  local/prepare-lagos-nwu.py $lagos_nwu_corpus $data
  local/prepare-slr86.py $slr86_corpus $data

  # don't forget spk2utt
  utils/utt2spk_to_spk2utt.pl $data/train_clean_5/utt2spk > $data/train_clean_5/spk2utt
  utils/utt2spk_to_spk2utt.pl $data/dev_clean_2/utt2spk > $data/dev_clean_2/spk2utt
  echo "$0: Prepared lagos-nwu & slr86 datasets into ${data}"
fi


#######################################################################
if [ $stage -le 1 ]; then

  local/nvlti_yo_prepare_dict.sh --stage 0 --cmd "$train_cmd" data/train_clean_5 data/dev_clean_2 data/local/dict_nosp

  # Make L.fst
  utils/prepare_lang.sh data/local/dict_nosp "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

  # Make G.fst for (3gram small, med)
  local/format_lms.sh --src-dir data/lang_nosp data/local/lm
  
  # Create ConstArpaLm format language model, G.fst for full 3-gram and 4-gram LMs
  local/build_const_arpa_lm.sh data/local/lm/yo_lm_tglarge.arpa data/lang_nosp data/lang_nosp_test_tglarge
fi


#######################################################################
if [ $stage -le 2 ]; then
  mfccdir=mfcc
  for part in dev_clean_2 train_clean_5; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 10 data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
  done

  # Get the shortest 500 utterances first because those are more likely
  # to have accurate alignments.
  utils/subset_data_dir.sh --shortest data/train_clean_5 500 data/train_500short
fi


#######################################################################
# train a monophone system
if [ $stage -le 3 ]; then
  # TODO(galv): Is this too many jobs for a smaller dataset?
  steps/train_mono.sh --boost-silence 1.25 --nj 5 --cmd "$train_cmd" data/train_500short data/lang_nosp exp/mono

  steps/align_si.sh --boost-silence 1.25 --nj 5 --cmd "$train_cmd" data/train_clean_5 data/lang_nosp exp/mono exp/mono_ali_train_clean_5
fi

# train a first delta + delta-delta triphone system on all utterances
if [ $stage -le 4 ]; then
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" 2000 10000 data/train_clean_5 data/lang_nosp exp/mono_ali_train_clean_5 exp/tri1

  steps/align_si.sh --nj 5 --cmd "$train_cmd" data/train_clean_5 data/lang_nosp exp/tri1 exp/tri1_ali_train_clean_5
fi


#######################################################################
# train an LDA+MLLT system.
if [ $stage -le 5 ]; then
  steps/train_lda_mllt.sh --cmd "$train_cmd" --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
    data/train_clean_5 data/lang_nosp exp/tri1_ali_train_clean_5 exp/tri2b

  # Align utts using the tri2b model
  steps/align_si.sh  --nj 5 --cmd "$train_cmd" --use-graphs true data/train_clean_5 data/lang_nosp exp/tri2b exp/tri2b_ali_train_clean_5
fi


#######################################################################
# Train tri3b, which is LDA+MLLT+SAT
if [ $stage -le 6 ]; then
  steps/train_sat.sh --cmd "$train_cmd" 2500 15000 data/train_clean_5 data/lang_nosp exp/tri2b_ali_train_clean_5 exp/tri3b
fi


#######################################################################
# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
if [ $stage -le 7 ]; then
  steps/get_prons.sh --cmd "$train_cmd" data/train_clean_5 data/lang_nosp exp/tri3b

  utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict_nosp \
    exp/tri3b/pron_counts_nowb.txt exp/tri3b/sil_counts_nowb.txt \
    exp/tri3b/pron_bigram_counts_nowb.txt data/local/dict

  utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang_tmp data/lang

  local/format_lms.sh --src-dir data/lang data/local/lm

  # utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz data/lang data/lang_test_tglarge
  local/build_const_arpa_lm.sh data/local/lm/yo_lm_tglarge.arpa data/lang data/lang_test_tglarge


  steps/align_fmllr.sh --nj 5 --cmd "$train_cmd" data/train_clean_5 data/lang exp/tri3b exp/tri3b_ali_train_clean_5
fi


#######################################################################
if [ $stage -le 8 ]; then
  # Test the tri3b system with the silprobs and pron-probs.

  # decode using the tri3b model
  utils/mkgraph.sh data/lang_test_tgsmall exp/tri3b exp/tri3b/graph_tgsmall

  for test in dev_clean_2; do
    steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" \
                          exp/tri3b/graph_tgsmall data/$test \
                          exp/tri3b/decode_tgsmall_$test
    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
                       data/$test exp/tri3b/decode_{tgsmall,tgmed}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
      data/$test exp/tri3b/decode_{tgsmall,tglarge}_$test
  done
fi


#######################################################################
# Train a chain model
if [ $stage -le 9 ]; then
  local/chain2/run_tdnn.sh
fi

# local/grammar/simple_demo.sh
