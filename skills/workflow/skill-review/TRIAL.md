# Trial

The `--trial` branch of [`skill-review`](SKILL.md). A **trial** is a fresh subagent building something real with the skill in an empty temp directory, judged by the main agent against criteria frozen beforehand. A harness without subagents skips the trial and says so in the report.

## Criteria

After the step 4 verdicts and before the first run, write the task and the criteria from the skill's own promises: every branch its description names, every done-condition, every rule that leaves a trace in files. A rule whose step 4 verdict is cut gives no criterion; a rule marked rewrite is judged in its rewritten form. The task fires every branch one run can reach; the branches it leaves out are named in the report. Each criterion is checkable by reading a file, reading the subagent's final message or running a command, and can go red on a plausible wrong run.

Stack: the skill's own. For a stack-neutral skill, `--stack` when given, otherwise the stack of the skill's examples.

The criteria are **frozen**: the same list judges every run. A criterion that goes red for something its rule does not cover is reworded once: the report shows both wordings, and the new one judges every run.

**Done when:** every branch the task fires is covered by at least one criterion, and the task and the list are written out in the conversation.

## A run

1. Create an empty directory under the system temp directory and print its path. When the skill works on existing material, seed the directory with a fixture that plants a case for each criterion.
2. Dispatch a fresh subagent. Its brief is exactly: the path of the skill folder with "read `SKILL.md` and follow it", the paths of the declared prerequisites that are installed, the task, the directory, the user's scripted answer for each point where the skill waits on the user, and a closing ask to list every point where the skill was silent and it had to guess.
3. Judge from the files in the directory and the subagent's final message. Install dependencies and run commands only for a criterion that reading cannot settle. Mark each criterion **green** or **red**; name the failure mode behind each red. The subagent's guess list goes to the gaps.

**Done when:** every criterion is green or red.

## Baseline

One run on the untouched skill, during step 4. Its reds and guesses enter the report as evidence; a red on a criterion in rewritten form is the evidence for that rewrite. A verdict that rests on this one run says so in its row.

## Confirm loop

After step 6, run again.

- All green, or every remaining red a gap → delete the trial directories and report.
- A red whose root is a decision the author never made, whichever edit exposed it → it goes to the gaps, and the skill stays unedited.
- Any other red → edit the skill, naming the failure mode each edit treats and listing the edit in the final report, then run again with a fresh subagent and a fresh directory.

Two fix rounds at most. Past that, stop: report what is still red, keep the last directory and print its path.

**Done when:** all criteria are green, or every remaining red is reported as a gap or as left after two fix rounds.
