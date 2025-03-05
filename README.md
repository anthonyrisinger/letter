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
- **LLM Model**: DeepSeek-R1 (8B or 32B version)

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

### Input: Job Posting (excerpt)
```
Software Engineer - Backend
XYZ Tech

We're looking for a skilled backend engineer with 5+ years of experience in
distributed systems. Proficiency in Golang and Kubernetes required. Experience
with cloud infrastructure and CI/CD pipelines preferred.

Our team is responsible for ...

The ideal candidate has a strong background in system design, cares deeply about
code quality, and has experience mentoring junior engineers.
```

### Output: Generated Cover Letter
```markdown
# Dear Hiring Manager at XYZ Tech,

I'm excited to apply for the Backend Software Engineer position. With over 7 years
developing distributed systems using Golang, I've designed and implemented scalable
microservices architecture at ABC Systems that handles 15M+ daily requests. My
experience deploying and maintaining Kubernetes clusters in production environments
aligns perfectly with your technical requirements.

At my current role ...

I'm particularly drawn to XYZ Tech's mission of creating technology that makes a
meaningful impact, and I'm excited about the opportunity to contribute to your
team's success. Thank you for your time and consideration.

### Jane Smith
```

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
export LETTER_MODEL="deepseek-r1:32B"
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
