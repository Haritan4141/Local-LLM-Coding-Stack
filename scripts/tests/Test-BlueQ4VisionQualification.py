import importlib.util
import ast
import json
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

path = Path(__file__).resolve().parents[1] / 'qualification' / 'blue_q4_vision.py'
spec = importlib.util.spec_from_file_location('blue_q4_qualification', path)
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)
summary_path = path.with_name('Summarize-BlueQ4Qualification.py')
summary_spec = importlib.util.spec_from_file_location('blue_q4_summary', summary_path)
summary = importlib.util.module_from_spec(summary_spec)
summary_spec.loader.exec_module(summary)


class QualificationTests(unittest.TestCase):
    def row(self, shared=0, headroom=2048):
        return {'all_adapter_shared_bytes': shared, 'gpus': [
            {'name': '3090', 'shared_bytes': shared//2, 'headroom_mib': headroom},
            {'name': '3060', 'shared_bytes': shared//2, 'headroom_mib': headroom}]}

    def test_strict_combined_boundary(self):
        self.assertEqual(harness.gate(self.row(4*1024**3-1)), [])
        self.assertIn('combined Shared >= 4 GiB', harness.gate(self.row(4*1024**3)))

    def test_per_gpu_boundary(self):
        row = self.row(3*1024**3)
        row['gpus'][0]['shared_bytes'] = 2*1024**3
        self.assertEqual(harness.gate(row), [])
        row['gpus'][0]['shared_bytes'] += 1
        self.assertTrue(harness.gate(row))

    def test_dedicated_exhaustion(self):
        self.assertTrue(harness.gate(self.row(headroom=0)))

    def test_image_deterministic(self):
        image = harness.png_fixture()
        self.assertTrue(image.startswith(b'\x89PNG\r\n\x1a\n'))
        self.assertEqual(image, harness.png_fixture())

    def test_long_input_is_bounded_and_six_facts(self):
        with patch.object(harness, 'api', side_effect=lambda b,r,p,timeout: {'tokens': [0]*len(p['content'].split())}):
            text, expected, actual = harness.long_prompt('unused', 10000, 'controlled')
        self.assertLessEqual(actual, 10000)
        self.assertEqual(len(expected), 6)
        for key, value in expected.items():
            self.assertIn(f'{key} = {value}', text)

    def test_no_operational_mutators(self):
        source = path.read_text(encoding='utf-8')
        for forbidden in ('unload --all', 'nvidia-smi -pl', 'config.yaml'):
            self.assertNotIn(forbidden, source)
        tree = ast.parse(source)
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'main')
        self.assertNotIn('Start-ManagedTurbo.ps1', ast.get_source_segment(source, main))
        self.assertIn('process.terminate()', source)
        self.assertNotIn('taskkill', source)
        self.assertIn("'127.0.0.1'", source)

    def test_wrong_host_fails_before_api(self):
        with patch.object(harness.socket, 'gethostname', return_value='DESKTOP-5NPLIIV'), patch.object(harness, 'api') as api:
            with self.assertRaisesRegex(RuntimeError, 'BLUE only'):
                harness.assert_empty()
            api.assert_not_called()

    def test_json_answer(self):
        self.assertEqual(harness.json_content({'content': '```json\n{"a":1}\n```'}), {'a': 1})

    def test_malformed_answer_is_failure_not_controller_crash(self):
        self.assertFalse(harness.matches_json({'content': ''}, {'a': 1}))
        self.assertFalse(harness.matches_json({'content': 'not json'}, {'a': 1}))
        self.assertTrue(harness.matches_json({'content': '{"a":1}'}, {'a': 1}))
        self.assertFalse(harness.matches_tool({'tool_calls': [{'name': 'lookup_inventory', 'arguments': ''}]}, {'a': 1}))

    def test_unrequested_tool_history_preserved_with_explicit_mock_error(self):
        messages = []
        result = {'content': '', 'tool_calls': [{'name': 'lookup_inventory', 'arguments': '{"sku":"vault_0"}'}]}
        harness.append_actual_assistant(messages, result)
        self.assertEqual(messages[0]['tool_calls'][0]['function']['arguments'], result['tool_calls'][0]['arguments'])
        self.assertEqual(messages[1]['role'], 'tool')
        self.assertIn('not executed', messages[1]['content'])
        self.assertNotIn('available', messages[1]['content'])

    def memory_fixture(self):
        gpus = [{'name': name, 'bus': bus, 'uuid': gpu_uuid, 'power_w': str(watts),
                 'total_mib': str(total), 'used_mib': '100', 'temperature_c': '45'}
                for name, (bus,gpu_uuid,watts,total) in harness.EXPECTED_GPU.items()]
        adapters = [{'name': name, 'vendor': 0x10de, 'instance': 'luid-'+str(i)}
                    for i, name in enumerate(harness.EXPECTED_GPU)]
        counters = [{'Name': a['instance'].upper(), 'DedicatedUsage': 100,
                     'SharedUsage': 123, 'TotalCommitted': 223} for a in adapters]
        return adapters, {'gpus': gpus, 'adapters': counters, 'ram_free_bytes': 1000, 'ram_total_bytes': 2000}

    def test_stale_duplicate_ignored_by_exact_luid(self):
        adapters, row = self.memory_fixture()
        adapters.insert(0, {**adapters[0], 'instance': 'stale-luid'})
        with patch.object(harness, 'ps', return_value=row):
            result = harness.memory(adapters)
        self.assertEqual(result['gpus'][0]['luid'], 'luid-0')

    def test_two_live_luids_fail_closed(self):
        adapters, row = self.memory_fixture()
        adapters.insert(0, {**adapters[0], 'instance': 'second-live'})
        row['adapters'].append({'Name': 'second-live', 'DedicatedUsage': 0, 'SharedUsage': 0})
        with patch.object(harness, 'ps', return_value=row), self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            harness.memory(adapters)

    def test_summary_preserves_failure_and_cache_metrics(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            run = root / 'one-run'
            run.mkdir()
            record = run / 'record.json'
            record.write_text(json.dumps({'status': 'QUALITY_FAIL', 'tests': [
                {'name': 'coding-0', 'pass': False},
                {'name': 'long-tool-followup', 'pass': True, 'timings': {'cache_n': 100000}}
            ], 'after': {'loaded_instances': 0, 'standalone_pids': []}}), encoding='utf-8')
            original = record.read_bytes()
            result = summary.summarize(root)['runs'][0]
            self.assertEqual(result['status'], 'QUALITY_FAIL')
            self.assertEqual(result['groups']['coding'], {'pass': 0, 'total': 1})
            self.assertEqual(result['tests'][1]['cache_tokens'], 100000)
            self.assertTrue(result['empty_runtime_restored'])
            self.assertEqual(record.read_bytes(), original)

    def test_capacity_not_invented_as_quality(self):
        with tempfile.TemporaryDirectory() as temp:
            run = Path(temp) / 'capacity'
            run.mkdir()
            (run / 'record.json').write_text('{"status":"CAPACITY_PASS"}', encoding='utf-8')
            result = summary.summarize(Path(temp))['runs'][0]
            self.assertEqual(result['tests'], [])
            self.assertIsNone(result['empty_runtime_restored'])
            self.assertIsNone(result['memory_peak_shared_bytes'])

    def test_coding_evaluator_original_contract_not_weakened(self):
        source = 'function mergeIntervals(input){const a=input.map(p=>p.slice()).sort((a,b)=>a[0]-b[0]);const out=[];for(const p of a){const q=out[out.length-1];if(q&&p[0]<=q[1])q[1]=Math.max(q[1],p[1]);else out.push(p);}return out;}'
        with tempfile.TemporaryDirectory() as temp:
            self.assertTrue(harness.evaluate_coding(Path(temp), 'valid', source)['pass'])
            self.assertFalse(harness.evaluate_coding(Path(temp), 'bad-adjacency', source.replace('p[0]<=q[1]', 'p[0]<=q[1]+1'))['pass'])
            self.assertFalse(harness.evaluate_coding(Path(temp), 'alias', 'function mergeIntervals(input){return input;}')['pass'])

    def test_coding_fixture_rejects_escape_surfaces(self):
        with tempfile.TemporaryDirectory() as temp:
            result = harness.evaluate_coding(Path(temp), 'escape', 'function mergeIntervals(input){return input.constructor.constructor("return process")();}')
            self.assertFalse(result['pass'])
            self.assertIn('Disallowed', result['evaluator_stderr'])


if __name__ == '__main__':
    unittest.main()
