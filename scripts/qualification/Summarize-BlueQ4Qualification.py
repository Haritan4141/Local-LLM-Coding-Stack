"""Read-only raw-evidence summarizer; no remote access or runtime/config writes."""
import argparse
import hashlib
import json
from pathlib import Path


def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summarize(root):
    runs = []
    for path in sorted(root.glob('*/record.json')):
        data = json.loads(path.read_text(encoding='utf-8-sig'))
        mem_path = path.with_name('memory.jsonl')
        samples = [json.loads(line) for line in mem_path.read_text(encoding='utf-8').splitlines()] if mem_path.exists() else []
        groups = {}
        for test in data.get('tests', []):
            group = test['name'].rsplit('-', 1)[0] if test['name'].rsplit('-', 1)[-1].isdigit() else test['name']
            stat = groups.setdefault(group, {'pass': 0, 'total': 0})
            stat['pass'] += int(test.get('pass') is True)
            stat['total'] += 1
        tests = []
        for test in data.get('tests', []):
            timing = test.get('timings', {})
            tests.append({key: test.get(key) for key in ('name', 'pass', 'ttft_seconds', 'elapsed_seconds', 'usage', 'finish_reason')} | {
                'generation_tok_s': timing.get('predicted_per_second'),
                'prompt_tok_s': timing.get('prompt_per_second'),
                'cache_tokens': timing.get('cache_n'),
                'draft_tokens': timing.get('draft_n'),
                'accepted_draft_tokens': timing.get('draft_n_accepted'),
            })
        runs.append({key: data.get(key) for key in (
            'status', 'started_at_utc', 'ended_at_utc', 'quant', 'context_tokens', 'vision', 'kv', 'ubatch', 'split',
            'revision', 'model_sha256', 'projector_sha256', 'runtime_sha256', 'harness_sha256', 'memory_probe_sha256',
            'load_seconds', 'load_gate_reasons', 'monitor_error', 'long_fixture', 'protected_settings_unchanged',
            'memory_peak_shared_bytes', 'memory_min_headroom_mib', 'memory_loaded', 'error'
        )} | {
            'run_id': path.parent.name, 'raw_record': str(path), 'remote_root': data.get('root'),
            'raw_record_sha256': checksum(path), 'groups': groups, 'tests': tests,
            'raw_memory_sha256': checksum(mem_path) if mem_path.exists() else None,
            'empty_runtime_restored': None if 'after' not in data else (
                data['after'].get('loaded_instances') == 0 and data['after'].get('standalone_pids') == []),
            'ram_min_free_bytes': min((m['ram_free_bytes'] for m in samples), default=None),
            'temperature_peak_c': {name: max((g['temperature_c'] for m in samples for g in m['gpus'] if g['name'] == name), default=None)
                for name in ('NVIDIA GeForce RTX 3090', 'NVIDIA GeForce RTX 3060')},
        })
    return {'schema_version': 1, 'record_type': 'isolated_qualification_series',
            'experiment': 'blue-q4-vision-20261006', 'source_root': str(root),
            'production_promotion': False, 'main_model_experiment': False,
            'notes': ['Original failures and preliminary protocol retained.',
                      'Capacity-only is not quality acceptance.',
                      'Synthetic direct API tests are not Goose/Desktop acceptance.',
                      'Identical deterministic repeats are reproducibility checks, not independent quality samples.'],
            'runs': runs}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path)
    args = parser.parse_args()
    print(json.dumps(summarize(args.root), ensure_ascii=False, indent=2))
