#!/Users/iroro/anaconda3/bin/python

# Grapheme-to-phoneme (G2P) conversion for Yorùbá using epitran & file of vocab words => X-SAMPA phonetic spellings

import argparse

import epitran
from epitran.xsampa import XSampa


def g2p_epitran(word_list):
    epi = epitran.Epitran('yor-Latn')  # Set to Yorùbá
    ipa_words = []

    for w in word_list:
        # gbogbo eniyan => IPA string: ɡ͡boɡ͡bo enijan
        ipa_word = epi.transliterate(w)
        # print("{} => IPA string: {}".format(word, ipa_word))
        ipa_words.append(ipa_word)

    return ipa_words


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="""G2P""")
    parser.add_argument('vocab_file_path', type=str, help='a plaintext file with list of all words in the corpora, '
                                                          'for which we need phonetic spellings')
    args = parser.parse_args()

    word_list, xsampa_word_list = [], []
    with open(args.vocab_file_path, 'r') as vocab_reader:
        for word in vocab_reader:
            word_list.append(word.strip())

    ipa_word_spellings = g2p_epitran(word_list)

    # X-Sampa class to convert IPA spellings to X-SAMPA
    xs = XSampa()
    for ipa_word in ipa_word_spellings:
        s_a = xs.ipa2xs(ipa_word)
        xsampa_word_list.append(s_a)

    # debug: entire chain of transformations, does it look/sound legit?
    # zipped = zip(word_list, ipa_word_spellings, xsampa_word_list)
    zipped = zip(word_list, xsampa_word_list)
    for z in zipped:
        print("{} {}".format(z[0], z[1]))

    ########################################################
    # demo code from learning epitran

    # input_string = "gbogbo eniyan"

    # gbogbo eniyan => IPA string: b'\xc9\xa1\xcd\xa1bo\xc9\xa1\xcd\xa1bo enijan'
    # s = epi.transliterate(input_string).encode("utf-8")
    # print("{} => IPA string: {}".format(input_string, s))

    # # gbogbo eniyan => IPA string: ɡ͡boɡ͡bo enijan
    # s = epi.transliterate(input_string)
    # print("{} => IPA string: {}".format(input_string, s))