#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORT_DIR="$AUDIT_DIR/reports"
LATEST_DIR="$REPORT_DIR/latest"

mkdir -p "$LATEST_DIR"

CUSTOM_FILE="${1:-$LATEST_DIR/custom.txt}"
LYNIS_FILE="${2:-$LATEST_DIR/lynis.txt}"
TRIVY_FILE="${3:-$LATEST_DIR/trivy.txt}"
TESTSSL_FILE="${4:-$LATEST_DIR/testssl.txt}"

OUTPUT="$LATEST_DIR/index.html"

HOST="$(hostname)"
DATE="$(date '+%d/%m/%Y %H:%M:%S')"

html_escape() {
    sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g'
}

# ==========================================================
# CUSTOM AUDIT
# ==========================================================

PASS=0
FAIL=0
MANUAL=0
TOTAL=0

if [ -f "$CUSTOM_FILE" ]; then
    PASS="$(grep -c '^\[PASS\]' "$CUSTOM_FILE" || true)"
    FAIL="$(grep -c '^\[FAIL\]' "$CUSTOM_FILE" || true)"
    MANUAL="$(grep -c '^\[MANUAL\]' "$CUSTOM_FILE" || true)"
    TOTAL=$((PASS + FAIL + MANUAL))
fi

if [ "$TOTAL" -gt 0 ]; then
    COMPLIANCE=$((PASS * 100 / TOTAL))
else
    COMPLIANCE=0
fi

# ==========================================================
# LYNIS
# ==========================================================

LYNIS_INDEX="N/A"
LYNIS_TESTS="N/A"
LYNIS_WARNINGS=0
LYNIS_SUGGESTIONS=0

if [ -f "$LYNIS_FILE" ]; then

    TMP="$(
        grep -m1 'Hardening index' "$LYNIS_FILE" |
        grep -oE '[0-9]+' |
        head -1 || true
    )"
    [ -n "$TMP" ] && LYNIS_INDEX="$TMP"

    TMP="$(
        grep -m1 'Tests performed' "$LYNIS_FILE" |
        grep -oE '[0-9]+' |
        head -1 || true
    )"
    [ -n "$TMP" ] && LYNIS_TESTS="$TMP"

    LYNIS_WARNINGS="$(
        grep -c 'Warning' "$LYNIS_FILE" || true
    )"

    LYNIS_SUGGESTIONS="$(
        grep -cE '^  \* ' "$LYNIS_FILE" || true
    )"
fi

# ==========================================================
# TRIVY
# ==========================================================

TRIVY_TOTAL=0
TRIVY_HIGH=0
TRIVY_CRITICAL=0

if [ -f "$TRIVY_FILE" ]; then

    TRIVY_SUMMARY="$(
        grep -m1 -E 'Total: [0-9]+ \(HIGH:' "$TRIVY_FILE" || true
    )"

    if [ -n "$TRIVY_SUMMARY" ]; then

        TRIVY_TOTAL="$(
            echo "$TRIVY_SUMMARY" |
            sed -E 's/.*Total: ([0-9]+).*/\1/'
        )"

        TRIVY_HIGH="$(
            echo "$TRIVY_SUMMARY" |
            sed -E 's/.*HIGH: ([0-9]+).*/\1/'
        )"

        TRIVY_CRITICAL="$(
            echo "$TRIVY_SUMMARY" |
            sed -E 's/.*CRITICAL: ([0-9]+).*/\1/'
        )"
    fi
fi

# ==========================================================
# TESTSSL
# ==========================================================

TLS12="UNKNOWN"
TLS13="UNKNOWN"
TLS10="UNKNOWN"
TLS11="UNKNOWN"

if [ -f "$TESTSSL_FILE" ]; then

    grep -Eiq 'TLS 1\.2.*offered|TLSv1\.2.*offered' \
        "$TESTSSL_FILE" && TLS12="ENABLED"

    grep -Eiq 'TLS 1\.3.*offered|TLSv1\.3.*offered' \
        "$TESTSSL_FILE" && TLS13="ENABLED"

    if grep -Eiq 'TLS 1\.0.*not offered|TLSv1.*not offered' \
        "$TESTSSL_FILE"; then
        TLS10="DISABLED"
    fi

    if grep -Eiq 'TLS 1\.1.*not offered|TLSv1\.1.*not offered' \
        "$TESTSSL_FILE"; then
        TLS11="DISABLED"
    fi
fi

# ==========================================================
# HTML HEADER
# ==========================================================

cat > "$OUTPUT" <<EOF
<!DOCTYPE html>
<html lang="fr">

<head>

<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">

<title>DNC - $HOST</title>

<style>

* {
    box-sizing: border-box;
}

html {
    scroll-behavior: smooth;
}

body {
    margin: 0;
    font-family:
        Inter,
        -apple-system,
        BlinkMacSystemFont,
        "Segoe UI",
        Arial,
        sans-serif;
    background: #f5f7fb;
    color: #18202f;
}

/* SIDEBAR */

.sidebar {
    position: fixed;
    width: 230px;
    height: 100vh;
    background: #ffffff;
    border-right: 1px solid #e7ebf1;
    padding: 26px 18px;
}

.brand {
    font-size: 18px;
    font-weight: 750;
    margin-bottom: 35px;
}

.brand span {
    color: #2563eb;
}

.nav-title {
    color: #9ca3af;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    margin: 25px 12px 10px;
}

.nav a {
    display: block;
    padding: 11px 13px;
    margin: 4px 0;
    color: #596273;
    text-decoration: none;
    border-radius: 8px;
    font-size: 14px;
}

.nav a:hover,
.nav a.active {
    background: #eef4ff;
    color: #2563eb;
}

/* CONTENT */

.content {
    margin-left: 230px;
    padding: 34px 42px 60px;
    max-width: 1650px;
}

.topbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 30px;
}

.title h1 {
    font-size: 25px;
    margin: 0;
}

.title p {
    margin: 7px 0 0;
    color: #7a8494;
    font-size: 13px;
}

.server {
    background: white;
    padding: 10px 16px;
    border: 1px solid #e5e9f0;
    border-radius: 8px;
    font-size: 13px;
}

/* CARDS */

.kpis {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 18px;
}

.card {
    background: white;
    border: 1px solid #e9edf3;
    border-radius: 12px;
    padding: 20px;
    box-shadow: 0 3px 12px rgba(20, 30, 50, .035);
}

.label {
    color: #7a8494;
    font-size: 12px;
}

.big {
    font-size: 31px;
    font-weight: 750;
    margin-top: 7px;
}

.sub {
    color: #8c95a4;
    font-size: 12px;
    margin-top: 5px;
}

.blue { color: #2563eb; }
.green { color: #16a34a; }
.red { color: #dc2626; }
.orange { color: #ea580c; }

/* SECTIONS */

.section {
    margin-top: 30px;
}

.section-title {
    font-size: 16px;
    margin-bottom: 14px;
}

/* OVERVIEW */

.overview {
    display: grid;
    grid-template-columns: 330px 1fr;
    gap: 18px;
}

.score-card {
    text-align: center;
}

.score-ring {
    --score: ${COMPLIANCE};

    width: 180px;
    height: 180px;
    margin: 18px auto;

    border-radius: 50%;

    background:
        conic-gradient(
            #2563eb calc(var(--score) * 1%),
            #e9eef8 0
        );

    display: flex;
    align-items: center;
    justify-content: center;
}

.score-inner {
    width: 135px;
    height: 135px;
    background: white;
    border-radius: 50%;

    display: flex;
    align-items: center;
    justify-content: center;
    flex-direction: column;
}

.score-value {
    font-size: 35px;
    font-weight: 800;
}

.score-label {
    color: #8992a2;
    font-size: 11px;
}

.bar-row {
    display: grid;
    grid-template-columns: 90px 1fr 45px;
    align-items: center;
    gap: 12px;
    margin: 18px 0;
    font-size: 13px;
}

.bar {
    height: 9px;
    background: #edf0f5;
    border-radius: 20px;
    overflow: hidden;
}

.bar > div {
    height: 100%;
    border-radius: 20px;
}

.passbar {
    width: $(( TOTAL > 0 ? PASS * 100 / TOTAL : 0 ))%;
    background: #22c55e;
}

.failbar {
    width: $(( TOTAL > 0 ? FAIL * 100 / TOTAL : 0 ))%;
    background: #ef4444;
}

.manualbar {
    width: $(( TOTAL > 0 ? MANUAL * 100 / TOTAL : 0 ))%;
    background: #f59e0b;
}

/* TABLE */

.table-card {
    padding: 0;
    overflow: hidden;
}

.table-tools {
    padding: 17px;
    border-bottom: 1px solid #edf0f4;
    display: flex;
    gap: 8px;
}

.filter {
    border: 1px solid #dfe4ec;
    background: white;
    padding: 7px 12px;
    border-radius: 7px;
    cursor: pointer;
}

.filter:hover {
    background: #f5f7fb;
}

table {
    width: 100%;
    border-collapse: collapse;
}

th {
    background: #fafbfc;
    color: #7b8493;
    font-size: 11px;
    text-transform: uppercase;
}

th,
td {
    padding: 13px 17px;
    text-align: left;
    border-bottom: 1px solid #edf0f4;
}

td {
    font-size: 13px;
}

.badge {
    display: inline-block;
    padding: 5px 9px;
    border-radius: 20px;
    font-size: 10px;
    font-weight: 750;
}

.badge-pass {
    background: #dcfce7;
    color: #15803d;
}

.badge-fail {
    background: #fee2e2;
    color: #b91c1c;
}

.badge-manual {
    background: #fef3c7;
    color: #b45309;
}

.badge-high {
    background: #ffedd5;
    color: #c2410c;
}

.badge-critical {
    background: #fee2e2;
    color: #b91c1c;
}

/* TOOL GRID */

.tool-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 18px;
}

.metric {
    margin-top: 18px;
    display: flex;
    justify-content: space-between;
    border-bottom: 1px solid #edf0f4;
    padding-bottom: 10px;
}

.metric:last-child {
    border-bottom: 0;
}

/* TLS */

.tls-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    margin-top: 18px;
}

.tls {
    background: #f8fafc;
    border: 1px solid #e8edf3;
    border-radius: 9px;
    padding: 15px;
}

.tls-name {
    font-weight: 700;
    margin-bottom: 8px;
}

/* RAW */

details {
    background: white;
    border: 1px solid #e5e9ef;
    border-radius: 9px;
    margin-bottom: 10px;
}

summary {
    padding: 14px;
    cursor: pointer;
    font-weight: 600;
}

pre {
    margin: 0;
    padding: 18px;
    max-height: 450px;
    overflow: auto;
    background: #111827;
    color: #d1d5db;
    font-size: 11px;
}

/* MOBILE */

@media(max-width: 1000px) {

    .sidebar {
        display: none;
    }

    .content {
        margin-left: 0;
        padding: 20px;
    }

    .kpis,
    .tool-grid {
        grid-template-columns: 1fr 1fr;
    }

    .overview {
        grid-template-columns: 1fr;
    }
}

</style>

</head>

<body>

<aside class="sidebar">

<div class="brand">
    DebianNginx<span>Compliance</span>
</div>

<div class="nav">

<div class="nav-title">Overview</div>

<a class="active" href="#dashboard">Dashboard</a>
<a href="#controls">Controls</a>

<div class="nav-title">Security tools</div>

<a href="#lynis">Lynis</a>
<a href="#trivy">Trivy</a>
<a href="#tls">TLS Security</a>

<div class="nav-title">Evidence</div>

<a href="#raw">Raw Reports</a>

</div>

</aside>

<main class="content" id="dashboard">

<div class="topbar">

<div class="title">
<h1>Debian 13 / Nginx Compliance</h1>
<p>Repository by Hukago</p>
</div>

<div class="server">
$HOST · $DATE
</div>

</div>

<!-- KPI -->

<div class="kpis">

<div class="card">
<div class="label">Compliance score</div>
<div class="big blue">${COMPLIANCE}%</div>
<div class="sub">$PASS of $TOTAL controls passed</div>
</div>

<div class="card">
<div class="label">Failed controls</div>
<div class="big red">$FAIL</div>
<div class="sub">Baseline deviations</div>
</div>

<div class="card">
<div class="label">Lynis hardening</div>
<div class="big">${LYNIS_INDEX}</div>
<div class="sub">${LYNIS_TESTS} tests performed</div>
</div>

<div class="card">
<div class="label">Critical vulnerabilities</div>
<div class="big red">${TRIVY_CRITICAL}</div>
<div class="sub">${TRIVY_TOTAL} HIGH / CRITICAL findings</div>
</div>

</div>

<!-- OVERVIEW -->

<div class="section">

<h2 class="section-title">Compliance overview</h2>

<div class="overview">

<div class="card score-card">

<div class="label">Baseline compliance</div>

<div class="score-ring">

<div class="score-inner">
<div class="score-value">${COMPLIANCE}%</div>
<div class="score-label">of 100 points</div>
</div>

</div>

<div class="sub">
Custom Debian 13 / Nginx baseline
</div>

</div>

<div class="card">

<div class="label">Control distribution</div>

<div class="bar-row">
<div>Passed</div>
<div class="bar"><div class="passbar"></div></div>
<strong>$PASS</strong>
</div>

<div class="bar-row">
<div>Failed</div>
<div class="bar"><div class="failbar"></div></div>
<strong>$FAIL</strong>
</div>

<div class="bar-row">
<div>Manual</div>
<div class="bar"><div class="manualbar"></div></div>
<strong>$MANUAL</strong>
</div>

</div>

</div>

</div>

<!-- CONTROLS -->

<div class="section" id="controls">

<h2 class="section-title">Baseline controls</h2>

<div class="card table-card">

<div class="table-tools">

<button class="filter" onclick="filterControls('ALL')">All</button>
<button class="filter" onclick="filterControls('PASS')">Pass</button>
<button class="filter" onclick="filterControls('FAIL')">Fail</button>
<button class="filter" onclick="filterControls('MANUAL')">Manual</button>

</div>

<table>

<thead>
<tr>
<th>#</th>
<th>Reference</th>
<th>Control result</th>
<th>Status</th>
</tr>
</thead>

<tbody id="controlsTable">
EOF

# ==========================================================
# CUSTOM CONTROLS -> HTML
# ==========================================================

if [ -f "$CUSTOM_FILE" ]; then

while IFS= read -r line; do

    STATUS="$(echo "$line" | sed -E 's/^\[([^]]+)\].*/\1/')"

    CONTENT="$(echo "$line" | sed -E 's/^\[[^]]+\][[:space:]]*//')"

    NUMBER="$(echo "$CONTENT" | cut -d'|' -f1 | xargs)"
    REFERENCE="$(echo "$CONTENT" | cut -d'|' -f2 | xargs)"
    DESCRIPTION="$(echo "$CONTENT" | cut -d'|' -f3- | xargs)"

    NUMBER="$(printf '%s' "$NUMBER" | html_escape)"
    REFERENCE="$(printf '%s' "$REFERENCE" | html_escape)"
    DESCRIPTION="$(printf '%s' "$DESCRIPTION" | html_escape)"

    case "$STATUS" in
        PASS)
            BADGE="badge-pass"
            ;;
        FAIL)
            BADGE="badge-fail"
            ;;
        *)
            BADGE="badge-manual"
            ;;
    esac

cat >> "$OUTPUT" <<EOF
<tr data-status="$STATUS">
<td>$NUMBER</td>
<td>$REFERENCE</td>
<td>$DESCRIPTION</td>
<td>
<span class="badge $BADGE">$STATUS</span>
</td>
</tr>
EOF

done < <(
    grep -E '^\[(PASS|FAIL|MANUAL)\][[:space:]]+[0-9]+' \
        "$CUSTOM_FILE" || true
)

fi

cat >> "$OUTPUT" <<EOF

</tbody>
</table>

</div>
</div>

<!-- SECURITY TOOLS -->

<div class="section">

<h2 class="section-title">Security tools</h2>

<div class="tool-grid">

<div class="card" id="lynis">

<div class="label">Lynis</div>
<div class="big">${LYNIS_INDEX}</div>
<div class="sub">Hardening index</div>

<div class="metric">
<span>Tests performed</span>
<strong>${LYNIS_TESTS}</strong>
</div>

<div class="metric">
<span>Warnings</span>
<strong>${LYNIS_WARNINGS}</strong>
</div>

<div class="metric">
<span>Suggestions</span>
<strong>${LYNIS_SUGGESTIONS}</strong>
</div>

</div>

<div class="card" id="trivy">

<div class="label">Trivy vulnerability scan</div>
<div class="big red">${TRIVY_TOTAL}</div>
<div class="sub">HIGH / CRITICAL findings</div>

<div class="metric">
<span>High</span>
<span class="badge badge-high">${TRIVY_HIGH}</span>
</div>

<div class="metric">
<span>Critical</span>
<span class="badge badge-critical">${TRIVY_CRITICAL}</span>
</div>

</div>

<div class="card">

<div class="label">Assessment scope</div>

<div class="metric">
<span>Operating system</span>
<strong>Debian 13</strong>
</div>

<div class="metric">
<span>Web server</span>
<strong>Nginx</strong>
</div>

<div class="metric">
<span>Controls</span>
<strong>${TOTAL}</strong>
</div>

<div class="metric">
<span>Automated</span>
<strong>${TOTAL}</strong>
</div>

</div>

</div>

</div>

<!-- TLS -->

<div class="section" id="tls">

<h2 class="section-title">TLS Security</h2>

<div class="card">

<div class="label">
Protocol availability observed by testssl.sh
</div>

<div class="tls-grid">

<div class="tls">
<div class="tls-name">TLS 1.0</div>
<strong>$TLS10</strong>
</div>

<div class="tls">
<div class="tls-name">TLS 1.1</div>
<strong>$TLS11</strong>
</div>

<div class="tls">
<div class="tls-name">TLS 1.2</div>
<strong>$TLS12</strong>
</div>

<div class="tls">
<div class="tls-name">TLS 1.3</div>
<strong>$TLS13</strong>
</div>

</div>

</div>

</div>

<!-- RAW -->

<div class="section" id="raw">

<h2 class="section-title">Raw evidence</h2>

<p class="sub">
Original outputs are preserved for audit traceability.
</p>

EOF

add_raw() {

    TITLE="$1"
    FILE="$2"

    {
        echo "<details>"
        echo "<summary>$TITLE</summary>"
        echo "<pre>"

        if [ -f "$FILE" ]; then
            html_escape < "$FILE"
        else
            echo "Report unavailable"
        fi

        echo "</pre>"
        echo "</details>"

    } >> "$OUTPUT"
}

add_raw "Custom audit" "$CUSTOM_FILE"
add_raw "Lynis" "$LYNIS_FILE"
add_raw "Trivy" "$TRIVY_FILE"
add_raw "testssl.sh" "$TESTSSL_FILE"

cat >> "$OUTPUT" <<'EOF'

</div>

</main>

<script>

function filterControls(status) {

    const rows =
        document.querySelectorAll(
            "#controlsTable tr"
        );

    rows.forEach(row => {

        if (
            status === "ALL" ||
            row.dataset.status === status
        ) {
            row.style.display = "";
        }
        else {
            row.style.display = "none";
        }

    });

}

</script>

</body>
</html>
EOF

echo "[OK] Dashboard généré : $OUTPUT"