import { execFileSync } from 'node:child_process';

const REPOSITORY = 'sky-ecosystem/spells-mainnet';
const WORKFLOW = 'safeharbor.yaml';

function runCommand(command, args) {
    return execFileSync(command, args, { encoding: 'utf8' }).trim();
}

export function shouldDispatchSafeHarbor(args) {
    return args.includes('--safeharbor-ci');
}

export function prepareSafeHarborDispatch(run = runCommand) {
    const branch = run('git', ['branch', '--show-current']);
    if (!branch) {
        throw new Error('SafeHarbor CI requires a named branch');
    }

    if (run('git', ['status', '--porcelain'])) {
        throw new Error('SafeHarbor CI worktree must be clean');
    }

    const remote = run('git', ['config', `branch.${branch}.remote`]);
    const remoteRef = run('git', ['config', `branch.${branch}.merge`]);
    if (!remote || !remoteRef) {
        throw new Error('SafeHarbor CI branch must have an upstream');
    }

    const head = run('git', ['rev-parse', 'HEAD']);
    const remoteHead = run('git', [
        'ls-remote',
        '--exit-code',
        remote,
        remoteRef,
    ]).split(/\s/)[0];
    if (head !== remoteHead) {
        throw new Error('SafeHarbor CI branch must be pushed before casting');
    }

    run('gh', ['workflow', 'view', WORKFLOW, '--repo', REPOSITORY]);
    return branch;
}

export function dispatchSafeHarborValidation(
    { branch, rpcUrlPublic, explorerUrlPublic, spellAddress },
    run = runCommand,
) {
    return run('gh', [
        'workflow',
        'run',
        WORKFLOW,
        '--repo',
        REPOSITORY,
        '--ref',
        branch,
        '--raw-field',
        `rpc_url=${rpcUrlPublic}`,
        '--raw-field',
        `spell_address=${spellAddress}`,
        '--raw-field',
        `explorer_url=${explorerUrlPublic}`,
    ]);
}
