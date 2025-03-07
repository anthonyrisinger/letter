# letter.sh: AI-Powered Cover Letter Generator

`letter.sh` generates cover letters. With the assistance of a local Large Language Model (LLM) API endpoint, it analyzes job postings against your resume and creates uniquely-personalized, highly-relevant cover letters highlighting your most applicable qualifications.

## Quick Start

```bash
# Install dependencies (brew for macOS, apt install for Ubuntu/Debian)
brew install curl jq coreutils pandoc

# Setup resume context (try Google docs .md download)
cp ~/resume.md letter/resume.md

# Generate cover letter as stdout (job from stdin)
./letter.sh < t/discord.txt

# Generate cover letter as PDF (job from clipboard)
./letter.sh cover.pdf
```

## Features

- **Automated Analysis**: Extracts key requirements from job postings and matches them with your qualifications
- **Personalized Content**: Creates tailored cover letters that highlight your most relevant experience
- **Document Management**: Maintains organized context directories for each job application
- **Multiple Output Formats**: Generates plain text or PDF outputs with optional document merging
- **Privacy-Focused**: Uses local LLM processing - your data stays on your machine

## Requirements

- **LLM Server**: Local LLM server running (default: localhost:11434)
- **Base Dependencies**: curl, jq, sed, tee, tr
- **PDF Output**: pandoc (optional, for PDF generation)
- **PDF Merging**: pdfcpu (optional, for combining documents)
- **LLM Model**: deepseek-r1:8b, deepseek-r1:32b, or qwq:32b (best)

## Installation

1. Clone or download this script to your local machine
2. Make the script executable: `chmod +x letter.sh`
3. Install required dependencies:
   ```bash
   # For macOS
   brew install curl jq gnu-sed coreutils pandoc

   # For Ubuntu/Debian
   sudo apt install curl jq sed coreutils pandoc

   # PDF merging (all platforms)
   go install github.com/pdfcpu/pdfcpu/cmd/pdfcpu@latest
   ```
4. Set up a local LLM server:
   ```bash
   # Using Ollama (https://ollama.ai)
   ollama pull deepseek-r1:8b
   ollama serve
   ```
5. Create a `letter` directory in the same location as the script
6. Add your resume as `resume.md` in the `letter` directory

## Usage

### Basic Usage

1. Copy the job posting to your clipboard
2. Run the script to output the cover letter to the terminal:
   ```bash
   ./letter.sh
   ```

### Generate PDF Output

Generate a PDF cover letter:
```bash
./letter.sh cover.pdf
```

### Merge with Other Documents

Create a combined PDF with your cover letter and resume:
```bash
./letter.sh merge.pdf resume.pdf
```

Combine multiple documents into a single PDF:
```bash
./letter.sh cover.pdf resume.pdf portfolio.pdf merge.pdf
```

## Example

Unmodified output using `t/discord.txt` and my own resume:

```
$ LETTER_MODEL=qwq ./letter.sh < t/discord.txt | fold -s
stdin job posting... ok
resolving CONTEXT_ID to 42b19ae1
resolving CONTEXT_TS to 20250307T211921Z
resolving CONTEXT_AT to letter/42b19ae1/20250307T211921Z
genai job details... 53 at letter/42b19ae1/20250307T211921Z/job.txt
genai app details... 95 at letter/42b19ae1/20250307T211921Z/app.txt
genai cov details... ok at letter/42b19ae1/20250307T211921Z/cov.txt
---
# Dear Hiring Manager at Discord,

My 19 years of hands-on experience in designing scalable systems, optimizing
distributed infrastructure, and leading global engineering teams directly align
with your need for a Staff Software Engineer capable of driving petabyte-scale
media creation. I’ve delivered measurable performance gains—like reducing
latency by 50% through AWS Global Accelerator and custom libc preloading—and
architected Kubernetes-based environments managing over 12 clusters, ensuring
high-impact technical outcomes at scale. My cross-functional leadership across
cybersecurity, VR gaming, and enterprise systems positions me to thrive in
Discord’s collaborative environment while addressing complex media delivery
challenges like yours.

I bring deep expertise in cloud infrastructure (AWS/GCP), low-level system
optimization (Linux kernel tuning), and CDN integration (Cloudflare) that
directly map to your requirements for optimizing HLS/DASH streaming workflows
and reducing operational costs. My recent work on spatial partitioning research
and real-time VR server lifecycle management parallels the high-performance
demands of gaming communication platforms, while my Rust adoption and Python
proficiency ensure I can contribute immediately to media transcoding pipelines
or codec optimizations. By integrating emerging technologies—such as GPU
scheduling for ML-driven video processing—I aim to accelerate your team’s path
toward next-generation media solutions.

The opportunity to create at Discord excites me because of its unique role in
shaping how millions interact through gaming and beyond. I’m eager to
collaborate on refining media ingest/delivery performance, mentor engineers on
cutting-edge infrastructure practices, and help scale systems that already move
100PB+ of user-generated content daily. Let’s build solutions that push the
boundaries of what real-time communication platforms can achieve.

Sincerely,

### C Anthony Risinger
```

Everything it produced is accurate enough to ship. Although the phrasing "leading global engineering teams" is mildly misleading because I was never a _people_ manager, since I was a technical lead in both title and spirit on multiple occasions across multiple time zones—management proper but on the technical track—it's still 100% accurate.

## How It Works

The script follows a sophisticated workflow:

1. **Job Analysis**: Extracts structured information from the job posting
2. **Resume Analysis**: Extracts your qualifications from your resume
3. **Matching Process**: Compares job requirements against your qualifications
4. **Cover Letter Generation**: Creates a personalized cover letter highlighting relevant alignment
5. **Output Formatting**: Generates the cover letter in requested format

## Directory Structure

```
letter/
├── resume.md                  # Your resume
└── [hash]/[timestamp]/        # Unique context directory for each job
    ├── ctx.txt                # Original job posting
    ├── job.{log,txt,md,json}  # Extracted job requirements
    ├── app.{log,txt,md,json}  # Extracted applicant qualifications
    └── cov.{log,txt,md,pdf}   # Generated cover letter
```

## Customization

The script offers several customization options through environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| LETTER_DIR | Base directory for files | "letter" |
| LETTER_LOG | Log file location | "/dev/null" |
| LETTER_HOST | LLM server address | "localhost:11434" |
| LETTER_MODEL | LLM model to use | "deepseek-r1:8B" |

For higher quality (but slower) results, use the 32B model:
```bash
export LETTER_MODEL="qwq:32b"
```

## Advanced Tips

- **Custom Templates**: Modify the `prompt:write` function to change the cover letter format
- **Resume Optimization**: Structure your resume with clear technology lists and quantifiable achievements
- **Multiple Resumes**: Use different resume files for different job types by specifying the resume path
- **Support docs**: Add supplementary `*.txt` files alongside `resume.md` to include ad hoc context
- **Skip Extraction**: Copy previously-generated `app.txt` files alongside your `resume.md` to skip re-extracting resume details.
- **Logging**: Enable verbose logs with `export LETTER_LOG="/dev/stderr"`

## Limitations and Considerations

- **LLM Quality**: The quality of output depends on the LLM model used (32B recommended for professional use)
- **Resume Format**: Best results require a well-structured resume with clear experience descriptions
- **Job Posting Detail**: More detailed job postings yield better customized cover letters
- **Processing Time**: The 32B model provides better results but requires more processing time and resources

## Troubleshooting

- **Empty Output**: Ensure your resume is properly formatted and the job description has sufficient detail
- **LLM Connection Error**: Verify the LLM server is running at the configured address
- **PDF Generation Failure**: Check that pandoc and pdfcpu are properly installed

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

This tool helps you create high-quality, tailored cover letters that highlight your most relevant qualifications while saving you time in the job application process.
