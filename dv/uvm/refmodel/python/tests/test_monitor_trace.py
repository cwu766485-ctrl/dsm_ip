import unittest

from dsm_refmodel.monitor_trace import run_monitor_trace
from dsm_refmodel.thermo5 import (generate_source_vectors,
                                 run_centered_cubic_ef2_inputs,
                                 run_centered_cubic_frontend)


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

    def _append_stage_events(self, events, i_words, q_words, starts, gains,
                             seq, dpd_configs_by_frame=None):
        samples = [tuple(pair) for pair in zip(
            [sample for word in i_words for sample in word],
            [sample for word in q_words for sample in word])]
        for word_index, first in enumerate(range(0, len(samples), 8)):
            block = samples[first:first + 8]
            events.append({
                "type": "cdc_core_word", "epoch": 0, "seq": seq,
                "word_index": word_index,
                "i": [sample[0] for sample in block],
                "q": [sample[1] for sample in block],
            })
            seq += 1
        expected_ef2 = run_centered_cubic_ef2_inputs(
            i_words, q_words, starts, gains,
            dpd_configs_by_frame=dpd_configs_by_frame)
        for word_index, (word_i, word_q) in enumerate(expected_ef2):
            events.append({
                "type": "ef2_input_word", "epoch": 0, "seq": seq,
                "word_index": word_index, "i": list(word_i), "q": list(word_q),
            })
            seq += 1
        return seq

    def test_internal_observer_records_are_checked_against_independent_stages(self):
        i_words, q_words, starts, gains, source = self._source_events(words=56)
        expected = run_centered_cubic_frontend(i_words, q_words, starts, gains)
        events = []
        seq = 0
        for beat in source:
            beat["seq"] = seq
            events.append(beat)
            seq += 1
        events.append({"type": "dsp_observation", "epoch": 0, "seq": seq,
                       "probe_state": "0xffff", "dpd_samples": [0] * 16})
        seq += 1
        seq = self._append_stage_events(events, i_words, q_words, starts, gains, seq)
        seq = self._append_pa(events, expected, seq)

        result, = run_monitor_trace(events)
        self.assertTrue(result.passed)
        self.assertEqual(result.compared_words, 56)
        self.assertEqual(result.compared_cdc_words, 56)
        self.assertEqual(result.compared_ef2_words, 56)

    def test_stage_checker_mutations_report_first_divergent_boundary(self):
        i_words, q_words, starts, gains, source = self._source_events(words=56)
        expected = run_centered_cubic_frontend(i_words, q_words, starts, gains)
        events = []
        for seq, beat in enumerate(source):
            beat["seq"] = seq
            events.append(beat)
        seq = self._append_stage_events(events, i_words, q_words, starts, gains,
                                        len(events))
        seq = self._append_pa(events, expected, seq)

        cdc_mutation = [dict(event) for event in events]
        cdc = next(event for event in cdc_mutation if event["type"] == "cdc_core_word")
        cdc["i"] = list(cdc["i"])
        cdc["i"][3] ^= 1
        with self.assertRaisesRegex(AssertionError, "CDC mismatch at sample 3"):
            run_monitor_trace(cdc_mutation)

        ef2_mutation = [dict(event) for event in events]
        ef2 = next(event for event in ef2_mutation if event["type"] == "ef2_input_word")
        ef2["q"] = list(ef2["q"])
        ef2["q"][11] ^= 1
        with self.assertRaisesRegex(AssertionError, "EF2 mismatch at word 0, lane 11"):
            run_monitor_trace(ef2_mutation)

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
                               "config_pending": frame_id == 1})
                seq += 1
                if frame_id == 1:
                    events.append({"type": "config_ack_core", "epoch": 0,
                                   "seq": seq})
                    seq += 1
                    events.append({"type": "commit_done", "epoch": 0,
                                   "seq": seq})
                    seq += 1
        seq = self._append_pa(events, expected, seq)
        seq = self._append_stage_events(
            events, i_words, q_words, starts, gains, seq,
            dpd_configs_by_frame=[None] + [frame_config] * 7)

        result, = run_monitor_trace(events)
        self.assertTrue(result.passed)
        self.assertEqual(result.applied_config_frames, (1,))

    def test_trace_mutation_detects_frame_apply_before_cdc_pending(self):
        events = [
            {"type": "axil_write_fire", "epoch": 0, "seq": 0,
             "txn_id": 1, "addr": "0x10", "data": "0x00002000", "strb": "0xf"},
            {"type": "axil_write_response", "epoch": 0, "seq": 1,
             "txn_id": 1, "resp": 0},
            {"type": "axil_write_fire", "epoch": 0, "seq": 2,
             "txn_id": 2, "addr": "0x00", "data": "0x00000002", "strb": "0xf"},
            {"type": "axil_write_response", "epoch": 0, "seq": 3,
             "txn_id": 2, "resp": 0},
            {"type": "frame_boundary", "epoch": 0, "seq": 4,
             "frame_id": 0, "config_pending": True},
            {"type": "config_pending", "epoch": 0, "seq": 5, "commit_id": 1},
            {"type": "config_ack_core", "epoch": 0, "seq": 6},
            {"type": "commit_done", "epoch": 0, "seq": 7},
        ]
        with self.assertRaisesRegex(ValueError, "precedes recorded CDC pending"):
            run_monitor_trace(events)

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

    def test_monitor_trace_checks_accepted_prefix_before_midstream_reset(self):
        i_words, q_words, starts, gains = generate_source_vectors(
            words=42, seed=610802, frame_start_words=(1, 15, 36),
            frame_gains=(16384, 14336, 12288))
        i_samples = [sample for word in i_words for sample in word]
        q_samples = [sample for word in q_words for sample in word]
        source = []
        for beat in range(24):
            first = beat * 14
            word = first // 8
            source.append({
                "type": "source_beat", "epoch": 0, "seq": beat,
                "beat_index": beat, "packet_id": 0,
                "packet_beat_index": beat, "source_frame_id":
                    sum(starts[index] for index in range(word + 1)) - 1,
                "i": i_samples[first:first + 14],
                "q": q_samples[first:first + 14],
                "frame_start": bool(starts[word]),
                "frame_gain": gains[word], "tlast": False,
            })
        expected = run_centered_cubic_frontend(i_words, q_words, starts, gains)
        events = list(source)
        events.extend([
            {"type": "frame_boundary", "epoch": 0, "seq": 24,
             "frame_id": 0, "config_pending": False},
            {"type": "frame_boundary", "epoch": 0, "seq": 25,
             "frame_id": 1, "config_pending": False},
        ])
        seq = self._append_pa(events, expected[:9], 26)
        events.append({"type": "reset", "epoch": 0, "next_epoch": 1, "seq": seq})

        data_epoch, empty_epoch = run_monitor_trace(events)
        self.assertTrue(data_epoch.passed)
        self.assertTrue(data_epoch.reset_terminated)
        self.assertEqual(data_epoch.compared_words, 9)
        self.assertEqual(data_epoch.discarded_model_words, 33)
        self.assertEqual(empty_epoch.compared_words, 0)

    def test_monitor_trace_rejects_corrupt_pa_prefix_before_reset(self):
        i_words, q_words, starts, gains, source = self._source_events(words=56)
        expected = run_centered_cubic_frontend(i_words, q_words, starts, gains)
        events = []
        for seq, beat in enumerate(source):
            beat["seq"] = seq
            events.append(beat)
        seq = self._append_pa(events, expected[:3], len(events))
        events[-1]["planes"][0] = "0x0000000000000000"
        events.append({"type": "reset", "epoch": 0, "next_epoch": 1,
                       "seq": seq})
        with self.assertRaisesRegex(AssertionError, "PA mismatch"):
            run_monitor_trace(events)

    def test_partial_frame_reset_compares_only_causally_known_output(self):
        i_words, q_words, starts, gains = generate_source_vectors(
            words=14, seed=88201, frame_start_words=(1, 8),
            frame_gains=(16384, 16384))
        i_samples = [sample for word in i_words for sample in word]
        q_samples = [sample for word in q_words for sample in word]
        expected = run_centered_cubic_frontend(i_words, q_words, starts, gains)

        for accepted_beats in (1, 2, 3):
            with self.subTest(accepted_beats=accepted_beats):
                events = []
                for beat in range(accepted_beats):
                    first = beat * 14
                    events.append({
                        "type": "source_beat", "epoch": 0, "seq": beat,
                        "beat_index": beat, "packet_id": 0,
                        "packet_beat_index": beat, "source_frame_id": 0,
                        "i": i_samples[first:first + 14],
                        "q": q_samples[first:first + 14],
                        "frame_start": beat == 0, "frame_gain": gains[0],
                        "tlast": False,
                    })
                accepted_samples = accepted_beats * 14 // 8 * 8
                partial_samples = accepted_samples % 56
                safe_words = min(7, max(0, (partial_samples - 11) // 8 + 1))
                seq = self._append_pa(events, expected[:safe_words], len(events))
                events.append({"type": "reset", "epoch": 0,
                               "next_epoch": 1, "seq": seq})

                data_epoch, empty_epoch = run_monitor_trace(events)
                self.assertTrue(data_epoch.passed)
                self.assertEqual(data_epoch.safe_output_words, safe_words)
                self.assertEqual(data_epoch.compared_words, safe_words)
                self.assertEqual(empty_epoch.compared_words, 0)

    def test_partial_frame_reset_rejects_output_without_enough_lookahead(self):
        i_words, q_words, starts, gains = generate_source_vectors(
            words=14, seed=88202, frame_start_words=(1, 8),
            frame_gains=(16384, 16384))
        i_samples = [sample for word in i_words for sample in word]
        q_samples = [sample for word in q_words for sample in word]
        first_beat = {
            "type": "source_beat", "epoch": 0, "seq": 0,
            "beat_index": 0, "packet_id": 0, "packet_beat_index": 0,
            "source_frame_id": 0, "i": i_samples[:14], "q": q_samples[:14],
            "frame_start": True, "frame_gain": gains[0], "tlast": False,
        }
        expected = run_centered_cubic_frontend(i_words, q_words, starts, gains)
        events = [first_beat]
        seq = self._append_pa(events, expected[:1], 1)
        events.append({"type": "reset", "epoch": 0, "next_epoch": 1,
                       "seq": seq})
        with self.assertRaisesRegex(ValueError, "only 0 have sufficient"):
            run_monitor_trace(events)

    def test_trace_records_source_gap_length_and_underflow_separately(self):
        events = [{"type": "source_beat", "epoch": 0, "seq": 0,
                   "beat_index": 0, "packet_id": 0, "packet_beat_index": 0,
                   "source_frame_id": 0, "i": [0] * 14, "q": [0] * 14,
                   "frame_start": True, "frame_gain": 16384, "tlast": False,
                   "source_gap_cycles": 16},
                  {"type": "underflow", "epoch": 0, "seq": 1},
                  {"type": "reset", "epoch": 0, "next_epoch": 1, "seq": 2}]
        data_epoch, _ = run_monitor_trace(events)
        self.assertTrue(data_epoch.passed)
        self.assertFalse(data_epoch.normal_passed)
        self.assertEqual(data_epoch.source_gap_events, 1)
        self.assertEqual(data_epoch.source_gap_cycles, 16)
        self.assertEqual(data_epoch.underflow_events, 1)

    def test_status_predictor_uses_run_write_not_observed_core_status(self):
        events = [
            {"type": "axil_write_fire", "epoch": 0, "seq": 0,
             "event_cycle": 2, "txn_id": 1, "addr": "0x00",
             "data": "0x01", "strb": "0xf"},
            {"type": "axil_write_response", "epoch": 0, "seq": 1,
             "txn_id": 1, "resp": 0},
            {"type": "stop_state", "epoch": 0, "seq": 2,
             "axil_cycle": 8, "run": True, "active": True,
             "draining": False},
            {"type": "axil_read", "epoch": 0, "seq": 3,
             "event_cycle": 9, "txn_id": 2, "addr": "0x04"},
            {"type": "axil_read_response", "epoch": 0, "seq": 4,
             "txn_id": 2, "addr": "0x04", "rdata": "0x08", "resp": 0},
        ]
        (result,) = run_monitor_trace(events)
        self.assertEqual(result.status_reads_checked, 1)
        self.assertEqual(result.status_reads_transition_masked, 0)

        events[-1]["rdata"] = "0x00"
        with self.assertRaisesRegex(ValueError, "STATUS mismatch"):
            run_monitor_trace(events)

    def test_status_prediction_orders_same_cycle_commit_done_before_ar(self):
        events = [
            {"type": "axil_write_fire", "epoch": 0, "seq": 0,
             "event_cycle": 1, "txn_id": 1, "addr": "0x00",
             "data": "0x02", "strb": "0x01"},
            {"type": "axil_write_response", "epoch": 0, "seq": 1,
             "txn_id": 1, "resp": 0},
            {"type": "config_pending", "epoch": 0, "seq": 2,
             "axil_cycle": 3, "commit_id": 1},
            {"type": "frame_boundary", "epoch": 0, "seq": 3,
             "axil_cycle": 4, "frame_id": 0, "config_pending": True},
            {"type": "config_ack_core", "epoch": 0, "seq": 4,
             "axil_cycle": 5},
            # The two observers can publish these same-edge records in either
            # order. A sampled STATUS must already reflect the DONE transition.
            {"type": "axil_read", "epoch": 0, "seq": 5,
             "event_cycle": 7, "txn_id": 2, "addr": "0x04"},
            {"type": "commit_done", "epoch": 0, "seq": 6,
             "axil_cycle": 7},
            {"type": "axil_read_response", "epoch": 0, "seq": 7,
             "txn_id": 2, "addr": "0x04", "rdata": "0x02", "resp": 0},
        ]
        (result,) = run_monitor_trace(events)
        self.assertEqual(result.status_reads_checked, 1)

        events[-1]["rdata"] = "0x00"
        with self.assertRaisesRegex(ValueError, "STATUS mismatch"):
            run_monitor_trace(events)

    def test_trace_sequence_reordering_is_rejected(self):
        events = [
            {"type": "source_beat", "epoch": 0, "seq": 2,
             "i": [0] * 14, "q": [0] * 14, "frame_start": True,
             "frame_gain": 16384, "tlast": False},
            {"type": "reset", "epoch": 0, "next_epoch": 1, "seq": 1},
        ]
        with self.assertRaisesRegex(ValueError, "trace sequence reordered"):
            run_monitor_trace(events)


if __name__ == "__main__":
    unittest.main()
