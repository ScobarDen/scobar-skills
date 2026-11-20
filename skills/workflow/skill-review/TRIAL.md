# Trial

The `--trial` branch of [`skill-review`](SKILL.md). A **trial** is a fresh subagent building something real with the skill in an empty temp directory, judged by the main agent against criteria frozen beforehand. A harness without subagents skips the trial and says so in the report.

## Criteria

Before the first run, write the task and the criteria from the skill's own promises: every branch its description names, every done-condition, every rule that leaves a trace in files. The task makes each branch fire. Each criterion is checkable by reading a file or running a command.

Stack: the skill's own. For a stack-neutral skill, `--stack` when given, otherwise the stack of the skill's examples.

The criteria are **frozen**: the same list judges every run.

**Done when:** every branch of the skill is covered by at least one criterion, and the task and the list are written out in the conversation.

## A run

1. Create an empty directory under the system temp directory and print its path.
2. Dispatch a fresh subagent. Its brief is exactly: the path of the skill folder with "read `SKILL.md` and follow it", the paths of the declared prerequisites that are installed, the task, the directory, and a closing ask to list every point where the skill was silent and it had to guess.
3. Judge from the files in the directory. Install dependencies and run commands only for a criterion that reading cannot settle. Mark each criterion **green** or **red**; name the failure mode behind each red. The subagent's guess list goes to the gaps.

**Done when:** every criterion is green or red.

## Baseline

One run on the untouched skill, during step 4. Its reds and guesses enter the report as evidence.

## Confirm loop

After step 6, run again.

- All green → delete the trial directories and report.
- Any red → edit the skill, naming the failure mode each edit treats, then run again with a fresh subagent and a fresh directory.

Two fix rounds at most. Past that, stop: report what is still red, keep the last directory and print its path.

**Done when:** all criteria are green, or two fix rounds are spent and the remaining reds are reported.
