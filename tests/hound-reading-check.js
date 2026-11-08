// Reading.js, the widget's parser for chezmoi-hound-check's line protocol.
// Run with: node tests/hound-reading-check.js
"use strict"
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const source = fs.readFileSync(path.join(__dirname, "..", "Reading.js"), "utf8")
  .replace(/^\.pragma library\s*$/m, "")
const Reading = {}
vm.runInNewContext(source, Reading)

let pass = 0
let fail = 0
function check(name, cond) {
  if (cond) { console.log("ok   " + name); pass++ }
  else { console.log("FAIL " + name); fail++ }
}

function reading(records) {
  return records.map(r => r.join("\t")).join("\n") + "\n"
}

const counts = [["home", "1"], ["repo", "0"], ["unpushed", "0"], ["total", "1"]]

console.log("Reading.parse:\n")

let r = Reading.parse(reading(counts.concat([["file", ".config/a.conf"]])))
check("a reading that adds up is accepted", r.ok && r.total === 1)
check("a drifted path is listed", r.detail.length === 1 && r.detail[0] === ".config/a.conf")

r = Reading.parse(reading([["home", "1"], ["repo", "0"], ["unpushed", "0"], ["total", "5"]]))
check("a reading that does not add up is refused", !r.ok)

r = Reading.parse(reading(counts.concat([["error", "chezmoi status failed"]])))
check("an error record is reported as the problem", !r.ok && r.problem === "chezmoi status failed")

r = Reading.parse(reading([["home", "x"], ["repo", "0"], ["unpushed", "0"], ["total", "0"]]))
check("a count that is not a number is refused", !r.ok)

r = Reading.parse("x".repeat(Reading.MAX_BYTES + 1))
check("an oversized reading is refused", !r.ok)

r = Reading.parse(reading(counts.concat([["file", "<b>&bold</b>"]])))
check("markup is stripped from what the tooltip shows", r.detail[0] === "bbold/b")

console.log("\n" + pass + " ok, " + fail + " failed")
process.exit(fail === 0 ? 0 : 1)
