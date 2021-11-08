#!/Users/iroro/anaconda3/bin/python

import argparse
import string
import unicodedata
import sys

# Remove punctuation from Unicode formatted strings:
# https://stackoverflow.com/questions/11066400/remove-punctuation-from-unicode-formatted-strings/21635971#21635971
tbl = dict.fromkeys(i for i in range(sys.maxunicode)
                    if unicodedata.category(chr(i)).startswith('P'))


def remove_punctuation(text):
    return text.translate(tbl)


if __name__ == "__main__":

    # print("Create a vocab file from a big text file, supporting accented & underdotted UTF-8 chars")
    parser = argparse.ArgumentParser(description="""Make Vocab file list""")
    parser.add_argument('big_text_file_path', type=str, help='i.e. ~/github/yoruba-asr/data/combined_text.txt')
    args = parser.parse_args()

    vocab_dict = {}
    punctuation_table = str.maketrans(dict.fromkeys(string.punctuation))  # OR {key: None for key in string.punctuation}
    with open(args.big_text_file_path) as f:
        for line in f:
            words = remove_punctuation(line).lower().split()
            for word in words:
                if word not in vocab_dict:
                    vocab_dict[word] = 1
                else:
                    vocab_dict[word] += 1

    # sort
    vocab_dict = sorted(vocab_dict)
    for key in vocab_dict:
        print(key)
