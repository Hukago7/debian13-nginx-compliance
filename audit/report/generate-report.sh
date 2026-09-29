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

HOSTNAME_VALUE="$(hostname)"
DATE_VALUE="$(date '+%d/%m/%Y %H:%M:%S')"

# ----------------------------------------------------------
# CUSTOM AUDIT
# ----------------------------------------------------------

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

# ----------------------------------------------------------
# LYNIS
# ----------------------------------------------------------

LYNIS_INDEX="N/A"
LYNIS_WARNINGS="N/A"
LYNIS_SUGGESTIONS="N/A"

if [ -f "$LYNIS_FILE" ]; then
    LYNIS_INDEX="$(
        grep -m1 'Hardening index' "$LYNIS_FILE" |
        sed -E 's/.*Hardening index[^0-9]*([0-9]+).*/\1/' || true
    )"

    LYNIS_WARNINGS="$(
        grep -m1 -E 'Warnings \([0-9]+\)' "$LYNIS_FILE" |
        sed -E 's/.*Warnings \(([0-9]+)\).*/\1/' || true
    )"

    LYNIS_SUGGESTIONS="$(
        grep -m1 -E 'Suggestions \([0-9]+\)' "$LYNIS_FILE" |
        sed -E 's/.*Suggestions \(([0-9]+)\).*/\1/' || true
    )"
fi

[ -z "$LYNIS_INDEX" ] && LYNIS_INDEX="N/A"
[ -z "$LYNIS_WARNINGS" ] && LYNIS_WARNINGS="N/A"
[ -z "$LYNIS_SUGGESTIONS" ] && LYNIS_SUGGESTIONS="N/A"

# ----------------------------------------------------------
# HTML ESCAPE
# ----------------------------------------------------------

html_escape() {
    sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g'
}

# ----------------------------------------------------------
# GENERATION
# ----------------------------------------------------------

cat > "$OUTPUT" <<EOF
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>Debian 13 / Nginx Compliance Report</title>

<style>
    * {
        box-sizing: border-box;
    }

    body {
        margin: 0;
        font-family: Arial, sans-serif;
        background: #f4f6f8;
        color: #1f2937;
    }

    header {
        background: #111827;
        color: white;
        padding: 32px;
    }

    header h1 {
        margin: 0 0 8px 0;
    }

    header p {
        margin: 0;
        color: #d1d5db;
    }

    main {
        max-width: 1200px;
        margin: auto;
        padding: 30px;
    }

    .grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
        gap: 18px;
        margin-bottom: 30px;
    }

    .card {
        background: white;
        border-radius: 10px;
        padding: 22px;
        box-shadow: 0 2px 8px rgba(0,0,0,.08);
    }

    .card .value {
        font-size: 32px;
        font-weight: bold;
        margin-top: 8px;
    }

    .success {
        color: #15803d;
    }

    .danger {
        color: #b91c1c;
    }

    .warning {
        color: #b45309;
    }

    h2 {
        margin-top: 35px;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        background: white;
        border-radius: 10px;
        overflow: hidden;
        box-shadow: 0 2px 8px rgba(0,0,0,.08);
    }

    th, td {
        text-align: left;
        padding: 13px;
        border-bottom: 1px solid #e5e7eb;
    }

    th {
        background: #f9fafb;
    }

    pre {
        background: #111827;
        color: #e5e7eb;
        padding: 20px;
        border-radius: 10px;
        overflow-x: auto;
        max-height: 500px;
    }

    details {
        margin: 20px 0;
    }

    summary {
        cursor: pointer;
        font-weight: bold;
        padding: 10px 0;
    }

    footer {
        text-align: center;
        color: #6b7280;
        padding: 30px;
    }
</style>
</head>

<body>

<header>
    <h1>Debian 13 / Nginx Compliance Report</h1>
    <p>$HOSTNAME_VALUE — $DATE_VALUE</p>
</header>

<main>

<div class="grid">

    <div class="card">
        <div>Conformité</div>
        <div class="value success">${COMPLIANCE}%</div>
        <div>${PASS}/${TOTAL} contrôles PASS</div>
    </div>

    <div class="card">
        <div>Contrôles en échec</div>
        <div class="value danger">$FAIL</div>
    </div>

    <div class="card">
        <div>Lynis Hardening</div>
        <div class="value">${LYNIS_INDEX}</div>
    </div>

    <div class="card">
        <div>Lynis Warnings</div>
        <div class="value warning">${LYNIS_WARNINGS}</div>
    </div>

    <div class="card">
        <div>Lynis Suggestions</div>
        <div class="value">${LYNIS_SUGGESTIONS}</div>
    </div>

</div>

<h2>Écarts de conformité</h2>

<table>
<thead>
<tr>
    <th>Contrôle</th>
    <th>Résultat</th>
</tr>
</thead>
<tbody>
EOF

if [ -f "$CUSTOM_FILE" ]; then

    FAIL_LINES="$(grep '^\[FAIL\]' "$CUSTOM_FILE" || true)"

    if [ -n "$FAIL_LINES" ]; then
        while IFS= read -r line; do

            ESCAPED="$(printf '%s' "$line" | html_escape)"

            cat >> "$OUTPUT" <<EOF
<tr>
    <td>$ESCAPED</td>
    <td class="danger">FAIL</td>
</tr>
EOF

        done <<< "$FAIL_LINES"

    else
        cat >> "$OUTPUT" <<EOF
<tr>
    <td>Aucun écart détecté</td>
    <td class="success">PASS</td>
</tr>
EOF
    fi
fi

cat >> "$OUTPUT" <<EOF
</tbody>
</table>

<h2>Résultats détaillés</h2>
EOF

add_report() {

    local title="$1"
    local file="$2"

    echo "<details>" >> "$OUTPUT"
    echo "<summary>$title</summary>" >> "$OUTPUT"
    echo "<pre>" >> "$OUTPUT"

    if [ -f "$file" ]; then
        html_escape < "$file" >> "$OUTPUT"
    else
        echo "Rapport indisponible" >> "$OUTPUT"
    fi

    echo "</pre>" >> "$OUTPUT"
    echo "</details>" >> "$OUTPUT"
}

add_report "Audit personnalisé — 50 contrôles" "$CUSTOM_FILE"
add_report "Lynis" "$LYNIS_FILE"
add_report "Trivy" "$TRIVY_FILE"
add_report "testssl.sh" "$TESTSSL_FILE"

cat >> "$OUTPUT" <<EOF

</main>

<footer>
    Generated by Debian 13 / Nginx Compliance Audit
</footer>

</body>
</html>
EOF

echo "[OK] Rapport HTML généré : $OUTPUT"
