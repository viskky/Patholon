#!/usr/bin/env bash
# =============================================================================
#  install.sh — Setup script for Patholon-nf
#  Run once before executing the pipeline for the first time.
# =============================================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No colour

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${BOLD}══════════════════════════════════════════${NC}"; \
            echo -e "${BOLD}  $*${NC}"; \
            echo -e "${BOLD}══════════════════════════════════════════${NC}"; }

# ─── 1. Check OS ──────────────────────────────────────────────────────────────
section "Checking environment"
OS=$(uname -s)
if [[ "$OS" != "Linux" ]]; then
    error "This pipeline is designed for Linux. Detected: $OS"
fi
info "OS: $OS ✓"

# ─── 2. Check Java ────────────────────────────────────────────────────────────
section "Checking Java"
# Function to install Java 17 based on the system's package manager
install_java17() {
    info "Attempting to install Java 17..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y openjdk-17-jdk
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y java-17-openjdk-devel
    elif command -v yum &>/dev/null; then
        sudo yum install -y java-17-openjdk-devel
    else
        error "Package manager not recognized. Please install Java 17 manually."
    fi
}

# Check if Java is installed at all
if ! command -v java &>/dev/null; then
    warn "Java not found."
    install_java17
fi

# Extract major version safely (handles both "17.0.x" and old "1.8.x" formats)
JAVA_VER=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}' | awk -F '.' '{if ($1=="1") print $2; else print $1}')

# If Java version is less than 17, try to upgrade it
if [[ -z "$JAVA_VER" || "$JAVA_VER" -lt 17 ]]; then
    warn "Java 17+ required. Found version: ${JAVA_VER:-unknown}"
    install_java17

    # Re-check after installation attempt
    JAVA_VER=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}' | awk -F '.' '{if ($1=="1") print $2; else print $1}')
    if [[ "$JAVA_VER" -lt 17 ]]; then
        error "Failed to upgrade to Java 17. Please check your sudo permissions."
    fi
fi

info "Java version: $(java -version 2>&1 | head -1) ✓"

# ─── 3. Install / Check Nextflow ──────────────────────────────────────────────
section "Checking Nextflow"

if command -v nextflow &>/dev/null; then
    NF_VER=$(nextflow -version 2>&1 | grep -oP 'version \K[\d.]+' | head -1)
    info "Nextflow found: v${NF_VER} ✓"
else
    info "Nextflow not found. Installing..."

    # Pin Nextflow version
    export NXF_VER=25.10.4

    curl -fsSL https://get.nextflow.io | bash
    chmod +x nextflow

    mkdir -p "$HOME/.local/bin"
    mv nextflow "$HOME/.local/bin/"

    export PATH="$HOME/.local/bin:$PATH"

    info "Nextflow v${NXF_VER} installed to ~/.local/bin/nextflow"
    warn "Add ~/.local/bin to your PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ─── 4. Check / Install Conda ─────────────────────────────────────────────────
section "Checking Conda / Mamba"
if command -v mamba &>/dev/null; then
    info "Mamba found: $(mamba --version | head -1) ✓"
    CONDA_CMD="mamba"
elif command -v conda &>/dev/null; then
    warn "Mamba not found — using conda (slower). Consider installing Mamba:"
    warn "  conda install -n base -c conda-forge mamba"
    CONDA_CMD="conda"


# ─── 5. Check existing Anaconda3 installation ───────────────────────────────
elif [[ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]]; then

    info "Existing Anaconda3 installation found at:"
    info "  $HOME/anaconda3"

    # Load Conda into the current shell
    source "$HOME/anaconda3/etc/profile.d/conda.sh"

    # Make Anaconda available in PATH
    export PATH="$HOME/anaconda3/bin:$PATH"

    CONDA_CMD="conda"

    info "Existing Anaconda3 installation loaded ✓"
    info "Conda version: $(conda --version)"

# ─── 6. Install Anaconda3 ────────────────────────────────────────────────────
else

    info "Neither Conda nor Mamba found."
    info "Installing Anaconda3..."

    ANACONDA_INSTALLER="$HOME/Anaconda3-latest-Linux-x86_64.sh"
    ANACONDA_DIR="$HOME/anaconda3"

    # Download Anaconda3 installer only if it does not already exist
    if [[ ! -f "$ANACONDA_INSTALLER" ]]; then

        info "Downloading Anaconda3 installer..."

        wget -O "$ANACONDA_INSTALLER" https://repo.anaconda.com/archive/Anaconda3-2026.07-1-Linux-x86_64.sh

    else

        info "Anaconda3 installer already exists:"
        info "  $ANACONDA_INSTALLER"

    fi

    # Verify installer exists and is not empty
    if [[ ! -s "$ANACONDA_INSTALLER" ]]; then
        error "Anaconda3 installer download failed or file is empty."
    fi

    # Install Anaconda3
    info "Installing Anaconda3 to $ANACONDA_DIR..."

    bash "$ANACONDA_INSTALLER" \
        -b \
        -p "$ANACONDA_DIR"

    # Load Conda for the current shell
    source "$ANACONDA_DIR/etc/profile.d/conda.sh"

    # Make Conda available in PATH
    export PATH="$ANACONDA_DIR/bin:$PATH"

    # Initialize Conda for future Bash sessions
    "$ANACONDA_DIR/bin/conda" init bash >/dev/null 2>&1 || true

    CONDA_CMD="conda"

    info "Anaconda3 installed successfully ✓"
    info "Conda version: $(conda --version)"

fi

conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# ─── 7. Create Conda Environment ─────────────────────────────────────────────
section "Creating conda environment: Patholon-nf"

# Check whether Patholon-nf already exists
if "$CONDA_CMD" env list | awk '{print $1}' | grep -qx "Patholon-nf"; then

    warn "Conda environment 'Patholon-nf' already exists."

    read -rp "  Re-create it? [y/N]: " ANSWER

    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then

        info "Removing existing Patholon-nf environment..."

        "$CONDA_CMD" env remove \
            -n Patholon-nf \
            -y

    else

        info "Skipping environment creation."

    fi
fi


# Create environment if it does not exist
if ! "$CONDA_CMD" env list | awk '{print $1}' | grep -qx "Patholon-nf"; then

    info "Creating Patholon-nf environment..."
    info "Using conda-forge and bioconda channels..."

    "$CONDA_CMD" env create \
        -f environment.yml \
        -y

    info "Conda environment created ✓"

else

    info "Conda environment 'Patholon-nf' is ready ✓"

fi


# ─── 8. Make bin/ scripts executable ─────────────────────────────────────────
section "Setting script permissions"
chmod +x bin/*.py 2>/dev/null || true
info "bin/ scripts are executable ✓"


# ─── 9. Update KronaTools taxonomy database ──────────────────────────────────
section "Updating KronaTools taxonomy database"
conda run -n Patholon-nf ktUpdateTaxonomy.sh 2>&1 || \
    warn "Could not update Krona taxonomy (may need internet access). Run manually:\n  conda run -n Patholon-nf ktUpdateTaxonomy.sh"

# ─── 10. ABRicate database check ───────────────────────────────────────────────
section "Checking ABRicate databases"
conda run -n Patholon-nf abricate --list || true

# ─── 11. Print next steps ──────────────────────────────────────────────────────
section "Installation Complete!"
echo ""
info "Next steps:"
echo ""
echo "  1. Download a Kraken2 database:"
echo "       https://benlangmead.github.io/aws-indexes/k2"
echo "     Example (standard-8 = 8 GB compressed):"
echo "       mkdir -p databases/kraken2 && cd databases/kraken2"
echo "       wget https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08gb_20231009.tar.gz"
echo "       tar -xzf k2_standard_08gb_20231009.tar.gz -C databases/kraken2"
echo "	     rm -fr k2_standard_08gb_20231009.tar.gz"
echo ""
echo "  2. Download a phage HMM database (e.g. INTERPRO):"
echo "       https://www.ebi.ac.uk/interpro/entry/pfam/#table"
echo "       decompress and concatenate all HMM files and store in a folder"
echo ""
echo "  3. (Optional) Download a BLASTP protein database:"
echo "       mkdir -p databases/blast"
echo "       # Swiss-Prot (for smaller space, ~250 MB): [Default]"
echo "       wget https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz"
echo "       gunzip uniprot_sprot.fasta.gz"
echo "       conda run -n Patholon-nf makeblastdb -in uniprot_sprot.fasta -dbtype prot -out databases/blast/swissprot -parse_seqids"
echo ""
echo "  4. Activate the environment and run the pipeline:"
echo "       conda activate Patholon-nf"
echo ""
echo "       # FastQC QC (default), Flye assembler: Mandatory to provide HMMfile"
echo "       nextflow run main.nf \\"
echo "           --input reads.fastq.gz \\"
echo "           --kraken2_db databases/kraken2 \\"
echo "           --hmm_db path_to_HMM_file.hmm \\"
echo "           --blastp_db databases/blast/swissprot \\"   
echo "           --outdir results/"
echo ""
echo "       # NanoPlot QC, FLYE assembler: Mandatory to provide HMMfile"                
echo "       nextflow run main.nf \\"
echo "           --input reads.fastq.gz \\"
echo "           --qc_tool nanoplot \\"                        
echo "           --assembler flye \\"
echo "           --abricate_db ncbi \\"
echo "           --kraken2_db databases/kraken2 \\"
echo "           --hmm_db path_to_HMM_file.hmm \\"
echo "           --blastp_db databases/blast/swissprot \\"
echo "           --outdir results/"
echo ""
echo "  4. For help:"
echo "       nextflow run Patholon.nf --help"
echo ""
