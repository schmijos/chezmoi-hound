import QtQml
import "../Reading.js" as Reading

// Proves Qt itself accepts Reading.js as a library import, which node cannot.
// Run with: qml -a core tests/ReadingImport.qml
QtObject {
  Component.onCompleted: {
    var r = Reading.parse("home\t0\nrepo\t0\nunpushed\t0\ntotal\t0\n")
    console.log(r.ok ? "ok   Qt imports Reading.js" : "FAIL Qt imports Reading.js")
    Qt.exit(r.ok ? 0 : 1)
  }
}
