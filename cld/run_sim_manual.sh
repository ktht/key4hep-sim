#!/bin/bash
#SBATCH -p main
#SBATCH --mem-per-cpu=6G
#SBATCH --cpus-per-task=1
#SBATCH -o logs/slurm-%x-%j-%N.out
set -e
if [[ $# -ne 2 ]]; then
    echo "Usage: run_sim_manual.sh SAMPLE RANDOM_SEED" >&2
    exit 2
fi

export NEV=${NEV:-100}
export KEY4HEP_VERSION=2026-04-08
export OUTDIR=${OUTDIR:-/local/${USER}/cld_edm4hep/v1.3.0_key4hep_${KEY4HEP_VERSION}/}
export CONFIG_DIR=${CONFIG_DIR:-${SIMDIR}}
export SIMDIR=${SIMDIR:-/home/${USER}/key4hep-sim/cld/CLDConfig}
export RUN_SIM_IN_SINGULARITY=1

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec bash "${SCRIPT_DIR}/run_sim.sh" "$1" "$2"
