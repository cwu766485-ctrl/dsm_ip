import unittest

from dsm_refmodel.monitor_trace import run_monitor_trace
from dsm_refmodel.thermo5 import generate_source_vectors, run_centered_cubic_frontend


class MonitorTraceOracleTests(unittest.TestCase):
    def _source_events(self, words=112):
        starts_words = tuple(range(1, words + 1, 7))
        gains_by_frame = (16384, 14336, 12288, 10240)
        i_words, q_words, starts, gains = generate_source_vectors(
            words=words, seed=77421, frame_start_words=starts_words,
            frame_gains=gains_by_frame)
        i_samples = [sample for word in i_words for sample in word]
        q_samples = [sample for word in q_words for sample in word]
        source = []
        for beat in range(len(i_samples) // 14):
            first = beat * 14
            word = first // 8
            source.append({
                "type": "source_beat", "epoch": 0,
                "beat_index": beat,
                "packet_id": beat // 32,
                "packet_beat_index": beat % 32,
                "source_frame_id": beat // 4,
                "i": i_samples[first:first + 14],
                "q": q_samples[first:first + 14],
                "frame_start": beat % 4 == 0,
                "frame_gain": gains[word],
                "tlast": beat % 32 == 31,
            })
        return i_words, q_words, starts, gains, source

    def _append_pa(self, events, pa_words, seq):
        for word_index, planes in enumerate(pa_words):
            events.append({"type": "pa_word", "epoch": 0, "seq": seq,
                           "word_index": word_index,
                           "planes": ["0x%016x" % int(value) for value in planes]})
            seq += 1
        return seq

    def test_monitor_trace_matches_static_oracle_across_two_packets(self):
        i_words, q_words, starts, gains, source = self._source_events()
        static = run_centered_cubic_frontend(i_words, q_words, starts, gains)
        events = []
        seq = 0
        for beat in source:
            beat["seq"] = seq
            events.append(beat)
            seq += 1
        seq = self._append_pa(events, static, seq)

        result, = run_monitor_trace(events)
        self.assertTrue(result.passed)
        self.assertEqual(result.compared_words, 112)
        self.assertEqual(result.applied_config_frames, ())

    def test_monitor_trace_uses_independently_reconstructed_commit_image(self):
        i_words, q_words, starts, gains, source = self._source_events(words=56)
        changed = {
            "c1_re": (8192, 0, 0, 0), "c1_im": (0, 0, 0, 0),
            "c3_re": (0, 0, 0, 0), "c3_im": (0, 0, 0, 0),
            "c5_re": (0, 0, 0, 0), "c5_im": (0, 0, 0, 0),
        }
        frame_config = {"active_taps": 1, "coefficients": changed}
        expected = run_centered_cubic_frontend(
            i_words, q_words, starts, gains,
            dpd_configs_by_frame=[None] + [frame_config] * 7)

        events = []
        seq = 0
        for beat in source:
            beat["seq"] = seq
            events.append(beat)
            seq += 1
            if beat["beat_index"] == 3:
                for txn_id, (addr, data) in enumerate(((0x10, 8192), (0x00, 2)), 1):
                    events.append({"type": "axil_write_fire", "epoch": 0,
                                   "seq": seq,
                                   "txn_id": txn_id,
                                   "addr": "0x%02x" % addr,
                                   "data": "0x%08x" % data,
                                   "strb": "0xf"})
                    seq += 1
                    events.append({"type": "axil_write_response", "epoch": 0,
                                   "seq": seq, "txn_id": txn_id, "resp": 0})
                    seq += 1
                events.append({"type": "config_pending", "epoch": 0,
                               "seq": seq, "commit_id": 1})
                seq += 1
            if beat["beat_index"] % 4 == 0:
                frame_id = beat["beat_index"] // 4
                events.append({"type": "frame_boundary", "epoch": 0,
                               "seq": seq, "frame_id": frame_id,
                               "config_pending": frame_id >= 1})
                seq += 1
                if frame_id == 1:
                    events.append({"type": "config_ack_core", "epoch": 0,
                                   "seq": seq})
                    seq += 1
                    events.append({"type": "commit_done", "epoch": 0,
                                   "seq": seq})
                    seq += 1
        seq = self._append_pa(events, expected, seq)

        result, = run_monitor_trace(events)
        self.assertTrue(result.passed)
        self.assertEqual(result.applied_config_frames, (1,))

    def test_monitor_trace_rejects_early_packet_tlast(self):
        events = [{"type": "source_beat", "epoch": 0, "seq": index,
                   "i": [0] * 14, "q": [0] * 14, "frame_start": index == 0,
                   "frame_gain": 16384, "tlast": index == 2}
                  for index in range(4)]
        with self.assertRaisesRegex(ValueError, "TLAST after 3 beats"):
            run_monitor_trace(events)

    def test_monitor_trace_rejects_noncontiguous_acceptance_ids(self):
        events = [{"type": "source_beat", "epoch": 0, "seq": 0,
                   "beat_index": 1, "packet_id": 0, "packet_beat_index": 0,
                   "source_frame_id": 0, "i": [0] * 14, "q": [0] * 14,
                   "frame_start": True, "frame_gain": 16384, "tlast": False}]
        with self.assertRaisesRegex(ValueError, "source beat index 1, expected 0"):
            run_monitor_trace(events)

    def test_monitor_trace_records_empty_reset_epoch(self):
        i_words, q_words, starts, gains, source = self._source_events(words=56)
        expected = run_centered_cubic_frontend(i_words, q_words, starts, gains)
        events = []
        for seq, beat in enumerate(source):
            beat["seq"] = seq
            events.append(beat)
        seq = self._append_pa(events, expected, len(events))
        events.append({"type": "reset", "epoch": 0, "next_epoch": 1,
                       "seq": seq})
        data_epoch, empty_epoch = run_monitor_trace(events)
        self.assertTrue(data_epoch.passed)
        self.assertEqual(data_epoch.compared_words, 56)
        self.assertEqual(empty_epoch.compared_words, 0)


if __name__ == "__main__":
    unittest.main()
