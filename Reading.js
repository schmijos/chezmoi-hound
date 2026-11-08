.pragma library

// The reading from bin/chezmoi-hound-check, parsed. Kept out of BarWidget.qml so
// it can be tested without a running shell.

var MAX_BYTES = 65536

// -1 means "the record was there but was not a count", which is different
// from 0 and must not be mistaken for a valid reading.
function countOf(value) {
  var n = Number(String(value))
  return (isFinite(n) && n >= 0 && n <= 100000) ? Math.floor(n) : -1
}

// bar.showTooltip renders with AutoText, which this plugin cannot pin to
// PlainText, so markup and control characters are stripped before handoff.
function plain(value) {
  return String(value)
    .replace(/[<>&]/g, "")
    .replace(/[\u0000-\u001f\u007f-\u009f‎‏‪-‮⁦-⁩]/g, "")
    .substring(0, 200)
}

// The reading is a line protocol - "key<TAB>value", one record per line, in
// no particular order. Returns { ok, problem, ... }: `problem` is set for an
// error record, `ok` only for a reading whose counts add up.
function parse(raw) {
  var text = String(raw || "")
  var out = { ok: false, problem: "" }
  if (text.length === 0 || text.length > MAX_BYTES) return out

  var lines = text.split("\n")
  var home = -1, repo = -1, unpushed = -1, total = -1
  var detail = [], commits = [], repoDetail = [], notes = [], recent = []
  var src = "", branch = "", upstream = "", stamp = "", problem = ""

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line === "") continue
    var tab = line.indexOf("\t")
    var key = tab < 0 ? line : line.substring(0, tab)
    var value = tab < 0 ? "" : line.substring(tab + 1)

    if (key === "home") home = countOf(value)
    else if (key === "repo") repo = countOf(value)
    else if (key === "unpushed") unpushed = countOf(value)
    else if (key === "total") total = countOf(value)
    else if (key === "file") { if (detail.length < 8) detail.push(plain(value)) }
    else if (key === "commit") { if (commits.length < 8) commits.push(plain(value)) }
    else if (key === "repofile") { if (repoDetail.length < 8) repoDetail.push(plain(value)) }
    else if (key === "recent") {
      // One record, three tabs: <sha> <when> <subject>. The age is dropped;
      // --render still prints it.
      var parts = value.split("\t")
      if (recent.length < 20 && parts.length >= 3)
        recent.push(plain(parts[0] + "  " + parts[2]))
    }
    else if (key === "note") { if (notes.length < 4) notes.push(plain(value)) }
    else if (key === "error") problem = plain(value)
    else if (key === "source") src = plain(value)
    else if (key === "branch") branch = plain(value)
    else if (key === "upstream") upstream = plain(value)
    else if (key === "stamp") stamp = value.substring(0, 32)
  }

  if (problem !== "") {
    out.problem = problem
    return out
  }
  // The three parts must add up; a reading that disagrees with itself is
  // rejected rather than shown half-believed.
  if (home < 0 || repo < 0 || unpushed < 0 || total < 0) return out
  if (home + repo + unpushed !== total) return out

  out.ok = true
  out.home = home
  out.repo = repo
  out.unpushed = unpushed
  out.total = total
  out.detail = detail
  out.commits = commits
  out.repoDetail = repoDetail
  out.recent = recent
  out.notes = notes
  out.source = src
  out.branch = branch
  out.upstream = upstream
  out.stamp = stamp
  return out
}
