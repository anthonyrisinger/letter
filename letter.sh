#!/usr/bin/env bash
#
# letter.sh - Automated Cover Letter Generator
#
# DESCRIPTION:
#   Generates tailored cover letters by analyzing job postings against
#   your resume. Uses a local LLM to extract structured information from
#   both sources and create personalized cover letters that highlight
#   relevant qualifications.
#
# REQUIREMENTS:
#   - Local LLM server running (default: localhost:11434)
#   - Base dependencies: curl, jq, sed, tee, tr
#   - PDF output: pandoc
#   - PDF merging: pdfcpu
#
# USAGE:
#   1. Copy your resume to the ./letter directory (as resume.md)
#   2. Copy job posting to clipboard
#
#   3. Run with one of:
#      ./letter.sh                        # Output to terminal
#      ./letter.sh cover.pdf              # Create PDF
#      ./letter.sh merge.pdf resume.pdf   # Merge with other documents
#      ./letter.sh cover.pdf resume.pdf [...] merge.pdf
#
# DIRECTORY STRUCTURE:
#   letter/
#   ├── resume.md                  # Your resume
#   └── [hash]/[timestamp]/        # Unique context directory for each job
#       ├── ctx.txt                # Original job posting
#       ├── job.{log,txt,md,json}  # Extracted job requirements
#       ├── app.{log,txt,md,json}  # Extracted applicant qualifications
#       └── cov.{log,txt,md,pdf}   # Generated cover letter
#
# WORKFLOW:
#   1. Extract structured data from job posting
#   2. Extract structured data from resume
#   3. Compare requirements against qualifications
#   4. Generate tailored cover letter
#   5. Format and output as requested
#
# NOTES:
#   - Creates unique context ID (hash) for each job posting
#   - Timestamp ensures multiple iterations don't overwrite each other
#   - All interactions with LLM are logged for debugging/improvement

set -euo pipefail

: ${LETTER_DIR:="letter"}
: ${LETTER_LOG:="/dev/null"}
: ${LETTER_CTX:="$LETTER_DIR"}
: ${LETTER_TMP:="$LETTER_DIR/tmp"}
: ${LETTER_HOST:="localhost:11434"}
: ${LETTER_MODEL:="deepseek-r1:8B"}
# Min 24GB GPU (RTX 3090) num_ctx=8192
# Higher quality but much slower model
# : ${LETTER_MODEL:="deepseek-r1:32B"}
# Highest quality and faster than above
# : ${LETTER_MODEL:="qwq:32B"}
: ${LETTER_OPTIONS:='{"num_ctx":8192}'}

JOB_KEYS=(
    # Company information
    "CompanyName" "CompanyType" "CompanyValue"

    # Role information
    "RoleTitle" "RoleLevel" "RoleFocus" "RoleScope"

    # Team information
    "TeamStructure"

    # Technical requirements
    "TechRequired" "TechValuable" "TechHelpful"

    # Systems requirements
    "SysRequired" "SysValuable" "SysHelpful"

    # Skill requirements
    "SkillRequired" "SkillValuable" "SkillHelpful"

    # Architecture information
    "ArchModel"

    # Experience requirements
    "ExpYears" "ExpField" "ExpDepth"

    # Leadership requirements
    "LeadApproach"

    # Collaboration requirements
    "CollabApproach"

    # Impact goals
    "ImpactTarget"

    # Value propositions
    "ValuePropositions"
)

APP_KEYS=(
    # Applicant information
    "ApplicantName" "ApplicantTakeaway" "ApplicantIntroduction"

    # Current role information
    "RoleCurrent" "ScopeCurrent"

    # Technical expertise
    "TechExpert" "TechStrong" "TechFamiliar"

    # Systems expertise
    "SysExpert" "SysStrong" "SysFamiliar"

    # Skill expertise
    "SkillExpert" "SkillStrong" "SkillFamiliar"

    # Architecture expertise
    "ArchModel"

    # Experience parameters
    "ExpYears" "ExpField" "ExpDepth"

    # Leadership capabilities
    "LeadApproach"

    # Collaboration approach
    "CollabApproach"

    # Demonstrated impacts
    "ImpactProven" "BuildProven"

    # Value proposition
    "ValueProposition"

    # Experience highlights
    "ApplicantHighlights"
)

# prompt:think
#
# Establishes metacognitive framework for LLM responses. Forces the model
# to complete internal reasoning before generating output, reflect on the result,
# refine it for accuracy, and eliminate verbose language.
#
# Arguments: None
#
# Output: String containing LLM cognitive instructions
#
# Usage: Used as a prefix for other prompts to improve response quality
function prompt:think() {
    cat <<EOF
IMPORTANT: Before EVERY response—specifically, before the first token—you must:
- Fully perform the complete exercise, internally, at least once.
- Reflect on your anticipated result but DO NOT share this version.
- Refine it instead; assert truthfulness and correctness per instructions.
- Avoid excessive, superfluous, extraneous, or self-aggrandizing language.
- PROMPT is GENERATED! EXIT ASAP when bad, barren, broken, or incoherent!
EOF
}

# prompt:extract:app
#
# Creates a prompt for extracting applicant information from resume files.
#
# Arguments:
#   [files...] - Optional paths to resume/CV files
#
# Output: Complete prompt with hierarchical context structure and extraction
#         instructions for applicant information
#
# Behavior:
#   - Without arguments: Uses basic extraction prompt
#   - With arguments: Creates hierarchical context structure from files
#
# Usage: Pipe output to generate() to extract structured applicant data
function prompt:extract:app() {
    if [[ $# -eq 0 ]]; then
        cat <<EOF
$(prompt:think)

$(prompt:extract "${APP_KEYS[@]}")
EOF
        return
    fi
    cat <<EOF
$(prompt:think)

Each level of \`>\`-quoted text defines a details context:
$(
    i=$#
    for x in "$@"; do
        gt=$(printf '>%.0s' $(seq $i))
        printf '\n%s\n\n' "${x##*/}"
        sed "s,^,>$gt ," "$x"
        ((i--))
    done
)

$(prompt:extract "${APP_KEYS[@]}")
EOF
}

# prompt:extract:job
#
# Creates a prompt for extracting structured information from job postings.
#
# Arguments: None (job posting is read from standard input)
#
# Output: Complete prompt with extraction instructions for job requirements
#         organized according to JOB_KEYS
#
# Usage: Pipe job posting to extract:job to produce structured job data
function prompt:extract:job() {
    cat <<EOF
$(prompt:think)

$(prompt:extract "${JOB_KEYS[@]}")
EOF
}

# prompt:extract
#
# Core extraction framework that converts unstructured text into structured data.
#
# Arguments:
#   $@ - List of keys to extract from input text
#
# Output: Prompt instructing LLM to analyze input text and extract values
#         for specified keys as JSON
#
# Behavior: Creates JSON template from arguments, guiding LLM extraction
#           while enforcing fact-based responses with no extrapolation
#
# Usage: Called by prompt:extract:app and prompt:extract:job
function prompt:extract() {
    cat <<EOF
SINGLE-level \`>\`-quoted text defines the extraction context:

$(sed -r 's,^,> ,')

IMPORTANT: Guided Analysis and Details Extraction

- Scope responses to constraint context if it exists.
- Task is pulling key details from extraction context.
- Map extraction context to JSON LIST-of-STRING values.
- Fill JSON key-values with context-derived observables.
- Leave empty any keys where insufficient confidence exists.
- For technical elements, focus on specific named technologies.
- For experience parameters, extract both quantitative and qualitative aspects.
- For impact records, prioritize measurable outcomes and concrete achievements.
- Maintain factual accuracy without extrapolation beyond what is directly supported.
- Seek concision, humility, confidence, and rigorously proper attribution.

PROMPT: Update with your observations and respond with this EXACT STRICT VALID JSON format:

\`\`\`json
$(
    printf "%s\n" "$@" \
    | jq -R '[., inputs] | map({(.):[]}) | add'
)
\`\`\`

CRITICAL PROMPT: STRICT VALID JSON ONLY!
EOF
}

# prompt:write
#
# Generates instructions for cover letter creation by comparing job requirements
# with applicant qualifications. Creates guidelines for authentic, concise content
# that highlights relevant experience without fabrication.
#
# Arguments:
#   $@ - Paths to context files (job.txt and app.txt)
#
# Output: String containing detailed cover letter generation instructions with
#         placeholder template and strict formatting guidelines
#
# Usage: Pipe output to generate() function to create final cover letter
function prompt:write() {
    cat <<EOF
$(prompt:think)

IMPORTANT: Objectively analyze the extracted job details (\`job.txt\`) against the applicant's resume (\`app.txt\`).

Guidelines for structuring the cover letter:

- Accuracy First: Represent qualifications truthfully, in a favorable yet authentic light.
- Intent and Fit: Clearly highlight why the applicant is a strong match and why they want to work there.
- Conciseness and Clarity: Keep it high-impact and to the point—eliminate unnecessary words.
- No Fabrication: If an exact match is missing, emphasize relevant strengths without exaggeration.
- Balance Technical and Soft Skills:
  - Ensure both hard technical qualifications and interpersonal strengths are covered.
  - Do not focus only on technical experience—mention collaboration, leadership, or problem-solving skills where relevant.
  - Use real-world impact examples.
- Language:
  - No excessive self-praise.
  - Use simple, direct wording.
  - Avoid vague, nondescript qualifiers.
  - Let the experience speak for itself.
- Resume Anchoring: If the applicant has directly relevant experience, reference it explicitly.
- Fallback Strategy: If the match isn't exact, highlight the closest transferable skills.

Each level of \`>\`-quoted text defines a details context:
$(
    i=$#
    for x in "$@"; do
        gt=$(printf '>%.0s' $(seq $i))
        printf '\n%s\n\n' "${x##*/}"
        sed "s,^,$gt ," "$x"
        ((i--))
    done
)

PROMPT: Ensure the closing statement is engaging and forward-looking:

- Avoid generic phrases—instead, show initiative and interest.
- Express enthusiasm about specific aspects of the role.
- Keep it concise but impactful, fluid and natural.

Final output must be fully resolved with NO placeholders:

\`\`\`
Dear Hiring Manager at {{${JOB_KEYS[0]/%Name/ Name}}},

{{compact, minimalistic, high-impact, first-person POV truth statements}}

Sincerely,

{{${APP_KEYS[0]/%Name/ Name}}}
\`\`\`
EOF
}

# generate
#
# Sends prompts to LLM API and processes responses.
#
# Arguments:
#   $1 - Context identifier (e.g., "job", "app", "cov")
#
# Input: Prompt text from stdin
#
# Output: Processed LLM response
#
# Side effects:
#   - Saves prompt to $CONTEXT_AT/$1.md
#   - Logs raw response to $LETTER_LOG
#   - Logs processed response to $CONTEXT_AT/$1.log
#
# Usage: prompt:extract | generate job
function generate() {
    tee -a "$CONTEXT_AT/$1.md" \
    | jq -Rs --arg model "$LETTER_MODEL" --argjson options "$LETTER_OPTIONS" '{prompt: ., model: $model, options: $options}' \
    | curl --no-buffer --silent "$LETTER_HOST/api/generate" -d@- \
    | jq --unbuffered --join-output '.response, if .done then "\n" else empty end' \
    | tee -a "$LETTER_LOG" \
    | tee -a "$CONTEXT_AT/$1.log"
}

# extract:job
#
# Extracts structured job requirements from job posting text.
#
# Arguments: None (job posting read from stdin)
#
# Output: Structured key-value text of job requirements
#
# Process: Generates extraction prompt → Sends to LLM → Processes response
#
# Usage: cat job_posting.txt | extract:job > job.txt
function extract:job() {
    prompt:extract:job "$@" \
    | generate job \
    | extract job
}

# extract:app
#
# Extracts structured applicant information from resume files.
#
# Arguments:
#   [files...] - Optional paths to resume/CV files
#
# Output: Structured key-value text of applicant qualifications
#
# Process: Generates extraction prompt → Sends to LLM → Processes response
#
# Usage: extract:app resume.md > app.txt
function extract:app() {
    prompt:extract:app "$@" \
    | generate app \
    | extract app
}

# extract
#
# Processes JSON response from LLM into readable key-value format.
#
# Arguments:
#   $1 - Identifier for output files (typically "job" or "app")
#
# Input: JSON data from LLM extraction
#
# Output: Formatted key-value text with arrays joined by semicolons
#
# Side effects: Saves raw JSON to $CONTEXT_AT/$1.json
#
# Usage: Called by extract:job and extract:app functions
function extract() {
    sed -urn '/^[{]/,/^[}]/{s/ +\/\/.*//;/^ *\/\//d;s,\\#,#,;s/[+],$//;p;}' \
    | jq 'with_entries(.value |= ([.. | strings | ltrimstr(" ") | rtrimstr(".") | select(length>0)]) | select(.value | length > 0))' \
    | tee -a "$CONTEXT_AT/$1.json" \
    | jq --unbuffered -r 'to_entries[] | "\(.key): \(.value | join("; "))"' \
    | filter:words \
    | sed -ur '/([A-Z][a-z]+):/s,, \1:,'
}

# write:cov
#
# Generates final cover letter by combining job and applicant data.
#
# Arguments:
#   $@ - Paths to context files (typically job.txt and app.txt)
#
# Output: Markdown-formatted cover letter with proper headings
#
# Process:
#   - Creates prompt comparing job requirements with applicant qualifications
#   - Processes LLM response to remove artifacts and formatting markers
#   - Converts to properly formatted markdown
#
# Usage: write:cov job.txt app.txt > coverletter.md
function write:cov() {
    prompt:write "$@" \
    | generate cov \
    | filter:words \
    | tr -us ' \n' \
    | sed -urn \
            -e 's,^ | $,,g' \
            -e 's,\*\*,,g' \
            -e '/<think>/,/<\/think>/d' \
            -e '/^Dear/,/^[-`]{3}/{/^[-`]{3}/d;p;}' \
    | sed -ur \
            -e '1{s/[-, ]* (Co|Corp|Inc|LLC)[.]?,/,/;}' \
            -e '1{s/(Dear [^,]+),/# \1,/;}' \
            -e 's,$,\n,' \
            -e '$s,\n$,,' \
            -e '$s,^,### ,'
}

# filter:words
#
# Standardizes text format and improves language quality.
#
# Input: Raw text from stdin
#
# Output: Processed text with:
#   - Whitespace normalized
#   - Technical terms standardized (e.g., "GoLang" → "Golang")
#   - Presumptuous terms replaced with better alternatives
#   - Line breaks added
#
# Usage: Used internally to refine LLM outputs
function filter:words() {
    sed -ur \
            -e 's/[Gg]oLang/Golang/g' \
            -e 's/honed/refined/g' \
            -e 's/innovat/progress/g' \
            -e 's/master/learn/g' \
            -e 's/obsess/dedicat/g'
}

# check:deps
#
# Verifies required dependencies are installed.
#
# Arguments:
#   $@ - Command line arguments (determines required dependencies)
#
# Behavior:
#   - Always checks for: curl, jq, sed, tee, tr
#   - With 1+ argument: Adds pandoc requirement
#   - With 2+ arguments: Adds pdfcpu requirement
#
# Exit codes:
#   0 - All dependencies found
#   1 - Missing dependencies
#
# Usage: Called by main() to validate environment
function check:deps() {
    local required_deps=(curl jq sed tee tr)
    case "$#" in
        0) : ;;
        1) required_deps+=(pandoc) ;;
        *) required_deps+=(pandoc pdfcpu) ;;
    esac

    local missing_deps=()
    for cmd in "${required_deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        echo "error: missing required deps: ${missing_deps[*]}" >&2
        echo "please install missing deps and try again." >&2
        exit 1
    fi
}

# main
#
# Primary orchestration function for cover letter generation.
#
# Arguments:
#   $1 - Optional output PDF filename
#   $2...$n - Optional additional PDF files to merge
#
# Input: Job posting from clipboard (interactive) or stdin (pipe)
#
# Output:
#   - Without args: Prints cover letter to stdout
#   - With args: Creates PDFs and optional merged documents
#
# Process:
#   1. Validates environment and inputs
#   2. Creates unique context directory with timestamp and hash ID
#   3. Extracts job requirements and applicant qualifications
#   4. Generates tailored cover letter
#   5. Produces requested output files
#
# Usage: ./letter.sh
#        ./letter.sh cover.pdf
#        ./letter.sh merge.pdf resume.pdf
#        ./letter.sh cover.pdf resume.pdf [...] merge.pdf
function main() {
    check:deps "$@"
    mkdir -p "$LETTER_TMP"

    local output=${1-}
    local extras=( "${@:2}" )
    local inputs=( $(
        shopt -s nullglob
        for x in "$LETTER_CTX"/*.{md,txt}; do
            [[ ${x##*/} == "app.txt" ]] \
            && cp "$x" "$LETTER_TMP" \
            || echo "$x"
        done
    ) )

    if [[ -t 0 ]]; then
        echo -n "paste job posting... " >&2
        if command -v pbpaste &> /dev/null; then
            pbpaste
        elif command -v xclip &> /dev/null; then
            xclip -selection clipboard -o
        else
            cat
        fi > "$LETTER_TMP/ctx.txt"
        echo "ok" >&2
    else
        echo -n "stdin job posting... " >&2
        cat > "$LETTER_TMP/ctx.txt"
        echo "ok" >&2
    fi
    if [[ ! -s "$LETTER_TMP/ctx.txt" ]]; then
        echo "error: empty context: $LETTER_TMP/ctx.txt" >&2
        exit 1
    fi

    CONTEXT_ID=$(sha256sum "$LETTER_TMP/ctx.txt" | head -c8)
    echo "resolving CONTEXT_ID to $CONTEXT_ID" >&2
    CONTEXT_TS=$(TZ=UTC date +%Y%m%dT%H%M%SZ)
    echo "resolving CONTEXT_TS to $CONTEXT_TS" >&2
    CONTEXT_AT="$LETTER_DIR/$CONTEXT_ID/$CONTEXT_TS"
    echo "resolving CONTEXT_AT to $CONTEXT_AT" >&2

    mkdir -p "$CONTEXT_AT"
    mv "$LETTER_TMP"/*.txt "$CONTEXT_AT"

    echo -n "genai job details... " >&2
    extract:job > "$CONTEXT_AT/job.txt" < "$CONTEXT_AT/ctx.txt"
    tr ',;' '\n\n' < "$CONTEXT_AT/job.txt" | wc -l | tr -d '[:space:]' >&2
    echo " at $CONTEXT_AT/job.txt" >&2
    if [[ ! -s "$CONTEXT_AT/job.txt" ]]; then
        echo "error: empty context: $CONTEXT_AT/job.txt" >&2
        exit 1
    fi

    echo -n "genai app details... " >&2
    local cached=" ($LETTER_CTX/app.txt)"
    if [[ ! -s "$CONTEXT_AT/app.txt" ]]; then
        cached=
        extract:app > "$CONTEXT_AT/app.txt" < "${inputs[0]}" "${inputs[@]:1}"
    fi
    tr ',;' '\n\n' < "$CONTEXT_AT/app.txt" | wc -l | tr -d '[:space:]' >&2
    echo " at $CONTEXT_AT/app.txt$cached" >&2
    if [[ ! -s "$CONTEXT_AT/app.txt" ]]; then
        echo "error: empty context: $CONTEXT_AT/app.txt" >&2
        exit 1
    fi

    echo -n "genai cov details... " >&2
    write:cov "$CONTEXT_AT"/{job,app}.txt > "$CONTEXT_AT/cov.txt"
    echo "ok at $CONTEXT_AT/cov.txt" >&2

    if [[ -n "$output" ]]; then
        echo -n "merge cov letters... " >&2
        pandoc --variable=pagestyle:empty -f markdown -o \
            "$CONTEXT_AT/cov.pdf" \
            "$CONTEXT_AT/cov.txt"
        cp -a "$CONTEXT_AT/cov.pdf" "$output"
        if [[ ${#extras[@]} -eq 0 ]]; then
            echo "ok at $output" >&2
        elif [[ ${#extras[@]} -eq 1 ]]; then
            pdfcpu merge -q "$output" "${extras[@]}"
            echo "ok at $output" >&2
        elif [[ ${#extras[@]} -gt 1 ]]; then
            echo "ok at $output" >&2
            echo -n "merge all letters... " >&2
            pdfcpu merge -q \
                "${extras[@]: -1}" \
                "$CONTEXT_AT/cov.pdf" \
                "${extras[@]: 0: ${#extras[@]}-1}"
            echo "ok at ${extras[@]: -1}" >&2
        fi
    fi

    echo --- >&2
    cat "$CONTEXT_AT/cov.txt"
}

main "$@"
