
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
