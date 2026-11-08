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

// What the panel shows is cleaned up for the tooltip; what Apply and Ignore act
// on must be the path chezmoi reported, or a different file is acted on.
const odd = ".config/a&b<c>.conf"
const long = ".config/" + "d/".repeat(120) + "file"
r = Reading.parse(reading(counts.map(c => c[0] === "home" || c[0] === "total" ? [c[0], "2"] : c)
  .concat([["file", odd], ["file", long]])))
check("an action acts on the path chezmoi reported, not the cleaned-up one",
  r.ok && Array.isArray(r.detailPaths) && r.detailPaths[0] === odd)
check("an action acts on a long path in full, not cut at 200 characters",
  r.ok && Array.isArray(r.detailPaths) && r.detailPaths[1] === long)
check("every listed path has the path an action uses",
  r.ok && Array.isArray(r.detailPaths) && r.detailPaths.length === r.detail.length)

console.log("\n" + pass + " ok, " + fail + " failed")
process.exit(fail === 0 ? 0 : 1)
