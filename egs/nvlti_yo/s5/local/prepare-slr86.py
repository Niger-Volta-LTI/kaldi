# Kaldi data preparation for Yoruba speech dataset from 
# https://openslr.org/86/

# This data set contains transcribed high-quality audio of Yoruba 
# sentences recorded by volunteers. The data set consists of wave files, 
# and a TSV file (line_index.tsv). The file line_index.tsv contains a 
# anonymized FileID and the transcription of audio in the file. The 
# file annotation_info contains information annotations included in the data set.
# The data set has been manually quality checked, but there might still be errors. 

import argparse
import csv
import os

utt_id, transcript, spk_id, wav_file = [], [], [], []


def prepare_gender_tsv(tsv, gender_folder_name):
    for row in tsv:
        print(row)
        utt_id.append(row[0])
        transcript.append(row[1])

        spk_id.append(row[0].split('_')[1])  # grab spkr_id from the utt_id
        wav_file.append(os.path.abspath(args.slr86_path + gender_folder_name) + "/" + row[0] + ".wav")


if __name__ == "__main__":

    print("Preparing OpenSLR86 data into Kaldi format")
    parser = argparse.ArgumentParser(description="""Prepare data.""")
    parser.add_argument('slr86_path', type=str, help='i.e. /Users/rebeiro/github/yoruba-asr/data/slr86/')
    parser.add_argument('out_dir', type=str, help='output directory, somewhere in the Kaldi recipe data directory')
    args = parser.parse_args()

    path_prefix = args.slr86_path
    print(path_prefix)

    with open(args.slr86_path + 'yo_ng_male/line_index.tsv', 'r', encoding='utf-8') as f_male, \
            open(args.slr86_path + 'yo_ng_female/line_index.tsv', 'r', encoding='utf-8') as f_female:

        male_tsv = csv.reader(f_male, delimiter="\t")
        female_tsv = csv.reader(f_female, delimiter="\t")

        prepare_gender_tsv(male_tsv, "yo_ng_male")
        prepare_gender_tsv(female_tsv, "yo_ng_female")

    # Make paths, we'll make SLR86 the training set (or we could mix it with Lagos-NWU and split it evenly)
    kaldi_data_path_train = args.out_dir + "/train-clean-5"
    if not os.path.exists(kaldi_data_path_train):
        os.makedirs(kaldi_data_path_train)

    # write files
    with open(kaldi_data_path_train + "/text", "wt", encoding='utf-8') as f_text, \
            open(kaldi_data_path_train + "/wav.scp", "wt", encoding='utf-8') as f_wav, \
            open(kaldi_data_path_train + "/utt2spk", "wt", encoding='utf-8') as f_utt2spk:
        for utt, transcript, spk, wav in zip(utt_id, transcript, spk_id, wav_file):
            f_text.write(utt + ' ' + transcript + '\n')     # text: utterance_id -> transcript
            f_wav.write(utt + ' ' + wav + '\n')             # wav scp: utterance_id -> audio path
            f_utt2spk.write(utt + ' ' + spk + '\n')         # utt2spk: utterance_id -> speaker
