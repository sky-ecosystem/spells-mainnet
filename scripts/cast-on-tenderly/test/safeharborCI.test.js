import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import {
    dispatchSafeHarborValidation,
    prepareSafeHarborDispatch,
    shouldDispatchSafeHarbor,
} from '../safeharborCI.js';

describe('SafeHarbor CI dispatch', () => {
    test('is opt-in', () => {
        assert.equal(shouldDispatchSafeHarbor(['0x1234']), false);
        assert.equal(
            shouldDispatchSafeHarbor(['0x1234', '--safeharbor-ci']),
            true,
        );
    });

    test('accepts a clean branch matching its remote', () => {
        const calls = [];
        const run = (command, args) => {
            calls.push([command, args]);
            const key = [command, ...args].join(' ');
            const results = {
                'git branch --show-current':
                    'maintenance/safeharbor-live-validation',
                'git status --porcelain': '',
                'git config branch.maintenance/safeharbor-live-validation.remote':
                    'origin',
                'git config branch.maintenance/safeharbor-live-validation.merge':
                    'refs/heads/maintenance/safeharbor-live-validation',
                'git rev-parse HEAD': 'abc123',
                'git ls-remote --exit-code origin refs/heads/maintenance/safeharbor-live-validation':
                    'abc123\trefs/heads/maintenance/safeharbor-live-validation',
                'gh workflow view safeharbor.yaml --repo sky-ecosystem/spells-mainnet':
                    'SafeHarbor Tests',
            };
            return results[key];
        };

        assert.equal(
            prepareSafeHarborDispatch(run),
            'maintenance/safeharbor-live-validation',
        );
        assert.ok(calls.some(([command]) => command === 'gh'));
    });

    test('rejects a dirty worktree', () => {
        const run = (command, args) => {
            const key = [command, ...args].join(' ');
            return {
                'git branch --show-current':
                    'maintenance/safeharbor-live-validation',
                'git status --porcelain':
                    ' M scripts/cast-on-tenderly/index.js',
            }[key];
        };

        assert.throws(
            () => prepareSafeHarborDispatch(run),
            /worktree must be clean/,
        );
    });

    test('rejects a branch whose HEAD is not on the remote', () => {
        const run = (command, args) => {
            const key = [command, ...args].join(' ');
            return {
                'git branch --show-current':
                    'maintenance/safeharbor-live-validation',
                'git status --porcelain': '',
                'git config branch.maintenance/safeharbor-live-validation.remote':
                    'origin',
                'git config branch.maintenance/safeharbor-live-validation.merge':
                    'refs/heads/maintenance/safeharbor-live-validation',
                'git rev-parse HEAD': 'local123',
                'git ls-remote --exit-code origin refs/heads/maintenance/safeharbor-live-validation':
                    'remote456\trefs/heads/maintenance/safeharbor-live-validation',
            }[key];
        };

        assert.throws(() => prepareSafeHarborDispatch(run), /must be pushed/);
    });

    test('dispatches the public VNet details on the selected branch', () => {
        let invocation;
        const run = (command, args) => {
            invocation = [command, args];
            return 'https://github.com/sky-ecosystem/spells-mainnet/actions/runs/1';
        };

        const runUrl = dispatchSafeHarborValidation(
            {
                branch: 'maintenance/safeharbor-live-validation',
                rpcUrlPublic: 'https://virtual.mainnet.rpc.tenderly.co/public',
                explorerUrlPublic:
                    'https://dashboard.tenderly.co/explorer/vnet/public',
                spellAddress: '0x1000000000000000000000000000000000000001',
            },
            run,
        );

        assert.equal(invocation[0], 'gh');
        assert.deepEqual(invocation[1], [
            'workflow',
            'run',
            'safeharbor.yaml',
            '--repo',
            'sky-ecosystem/spells-mainnet',
            '--ref',
            'maintenance/safeharbor-live-validation',
            '--raw-field',
            'rpc_url=https://virtual.mainnet.rpc.tenderly.co/public',
            '--raw-field',
            'spell_address=0x1000000000000000000000000000000000000001',
            '--raw-field',
            'explorer_url=https://dashboard.tenderly.co/explorer/vnet/public',
        ]);
        assert.equal(
            runUrl,
            'https://github.com/sky-ecosystem/spells-mainnet/actions/runs/1',
        );
    });
});
