#!/Users/iroro/anaconda3/bin/python

# Kaldi data preparation for Lagos-NWU Speech Corpus from
# https://repo.sadilar.org/handle/20.500.12185/431

# This speech corpus consisting of 16 female speakers and 17 male speakers was 
# recorded in Lagos, Nigeria for the purpose of speech recognition research. 
# Each speaker recorded about 130 utterances read from short texts selected for 
# phonetic coverage. Recordings were done using a microphone connected to a 
# laptop computer in a quiet office environment.


import argparse
import glob
import os
import unicodedata

# ...lagos-nwu-corpus/male/024/recordings/024_yoruba_male_headset_0074.wav
# ...lagos-nwu-corpus/<gender>/<spkid>/recordings/utterance.wav

wav_path_suffix = '*/*/*/*.wav'
transcript_path_suffix = '*/*/*.data.orig'
all_info = []


# index all transcripts, converted from NFC to NFD
def make_transcript_dictionary(paths):
    h = {}
    all_transcript_paths = glob.glob(paths)
    # print(all_transcript_paths)

    for path in all_transcript_paths:
        with open(path, 'r') as file_reader:
            for line in file_reader:
                line_split = line.split("\"")
                utterance_id = line_split[0].split("(")[1].strip()
                transcript = line_split[1]
                h[utterance_id] = unicodedata.normalize("NFC", transcript)      #  because data is NFC
    return h


def write_text(file_infos):
    results = []
    for info in file_infos:
        utt_id = info[1]
        transcript = info[3]
        results.append("{} {}".format(utt_id, transcript))
    return '\n'.join(sorted(results))


def write_wavscp(file_infos):
    results = []
    for info in file_infos:
        utt_id = info[1]
        utterance_filename = info[2]
        results.append("{} {}".format(utt_id, utterance_filename))
    return '\n'.join(sorted(results))


def write_utt2spk(file_infos):
    results = []
    for info in file_infos:
        spkr = info[0]
        utt_id = info[1]
        results.append("{} {}".format(utt_id, spkr))
    return '\n'.join(sorted(results))


if __name__ == "__main__":

    print("Preparing Lagos-NWU data into Kaldi format")
    parser = argparse.ArgumentParser(description="""Prepare data.""")
    parser.add_argument('lagos_nwu_path', type=str, help='i.e. /Users/iroro/github/yoruba-asr/data/lagos-nwu-corpus/')
    parser.add_argument('out_dir', type=str, help='output directory, somewhere in the Kaldi recipe data directory')
    args = parser.parse_args()

    path_prefix = args.lagos_nwu_path
    utt2transcript_dict = make_transcript_dictionary(path_prefix + transcript_path_suffix)
    print('All transcript utterances: {0}'.format(len(utt2transcript_dict)))

    all_info = []
    all_wavpath_utterances = glob.glob(path_prefix + wav_path_suffix)

    count = 0
    for utterance_extended_filename in all_wavpath_utterances:
        count += 1
        spkr_id = utterance_extended_filename.split("/")[7] + "-" + utterance_extended_filename.split("/")[8]
        utterance_id = utterance_extended_filename.split("/")[10].split(".")[0]
        all_info.append([spkr_id, utterance_id, utterance_extended_filename, utt2transcript_dict[utterance_id]])

    # Make paths, we'll make Lagos-NWU the dev set (or we could mix it with OpenSLR and split it evenly)
    kaldi_data_path_test = args.out_dir + "/dev_clean_2"
    if not os.path.exists(kaldi_data_path_test):
        os.makedirs(kaldi_data_path_test)

    # write files
    with open(kaldi_data_path_test + "/text", "wt", encoding='utf-8') as f_text, \
        open(kaldi_data_path_test + "/wav.scp", "wt", encoding='utf-8') as f_wav, \
        open(kaldi_data_path_test + "/utt2spk", "wt", encoding='utf-8') as f_utt2spk:
        f_text.writelines(write_text(all_info))         # text: utterance_id -> transcript
        f_wav.writelines(write_wavscp(all_info))        # wav scp: utterance_id -> audio path
        f_utt2spk.writelines(write_utt2spk(all_info))   # utt2spk: utterance_id -> speaker
