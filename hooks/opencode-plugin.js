// doc-first edit gate for OpenCode
//
// OpenCode has no shell-command hooks, only JS/TS plugins. This plugin runs
// the shared gate script (pre-tool-use.sh) right before a file-editing tool
// and throws when the script denies the edit. All judgement lives in the
// script so that every AI tool applies the same rules.
//
// Installed by install.sh as <opencode config>/plugins/doc-first-gate.js

import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import { join } from "node:path"

const EDIT_TOOLS = ["write", "edit", "apply_patch"]
const DATA_HOME = process.env.XDG_DATA_HOME || join(process.env.HOME || "", ".local", "share")
const GATE_SCRIPT = join(DATA_HOME, "doc-first", "bin", "pre-tool-use.sh")

export const DocFirstGate = async ({ directory }) => ({
  "tool.execute.before": async (input, output) => {
    if (!EDIT_TOOLS.includes(input.tool)) return

    // Not installed (or removed): the gate is off, tools keep working.
    if (!existsSync(GATE_SCRIPT)) return

    const payload = JSON.stringify({
      tool: input.tool,
      sessionID: input.sessionID,
      args: output.args,
    })

    const result = spawnSync("bash", [GATE_SCRIPT, "--tool=opencode"], {
      input: payload,
      cwd: directory,
      encoding: "utf8",
    })

    // The script itself passes when it cannot judge; lean the same way here.
    if (result.status !== 0) return

    let decision
    try {
      decision = JSON.parse(result.stdout)
    } catch {
      return // empty stdout = pass
    }

    if (decision && decision.decision === "deny") {
      throw new Error(decision.reason)
    }
  },
})
