#!/bin/bash
#SBATCH -p main
#SBATCH --mem-per-cpu=6G
#SBATCH --cpus-per-task=1
#SBATCH -o logs/slurm-%x-%j-%N.out
set -e
set -x

env
df -h

export NEV=${NEV:-100}
export SAMPLE=$1 #main card
export NUM=$2 #random seed

#Change these as needed
export KEY4HEP_VERSION=${KEY4HEP_VERSION:-2026-04-08}
export OUTDIR=${OUTDIR:-/local/${USER}/cld_edm4hep/v1.3.0_key4hep_${KEY4HEP_VERSION}/}
export CONFIG_DIR=${CONFIG_DIR:-/home/${USER}/key4hep-sim/cld/CLDConfig}
export SIMDIR=${SIMDIR:-${CONFIG_DIR}}
export BHWIDE_PATH="${BHWIDE_PATH:-$(command -v bhwide || printf '%s' "/home/${USER}/key4hep-sim/generators/bhwide/bin/bhwide")}"
export WORKDIR=${WORKDIR:-/scratch/local/${USER}/${SAMPLE}_${SLURM_JOB_ID}}
export FULLOUTDIR=${OUTDIR}/${SAMPLE}

mkdir -p "${FULLOUTDIR}"

mkdir -p "${WORKDIR}"

# Ensure cleanup on exit, even if the job fails
cleanup() {
    if [ ! -z "$WORKDIR" ] && [ "$WORKDIR" != "/scratch/local/$USER" ] && [ "$WORKDIR" != "/scratch/local/$USER/" ]; then
        echo "Cleaning up scratch directory $WORKDIR"
        rm -Rf $WORKDIR
    fi
}
trap cleanup EXIT

cd "${WORKDIR}"

PYTHIA_CARD=card.cmd
cp "${CONFIG_DIR}/pythia/${SAMPLE}.cmd" "${PYTHIA_CARD}"
cp -R "${CONFIG_DIR}" ./

#generate LHE events if requested so
GEN_SCRIPT=gen.sh
if [[ ${SAMPLE} == bhwide* ]]; then
    LHE_EVENTS=$(pwd)/events.lhe
    cat >> "${PYTHIA_CARD}" <<EOF
Beams:LHEF = ${LHE_EVENTS}
Main:numberOfEvents = ${NEV}
EOF
    cat > "${GEN_SCRIPT}" <<EOF
#!/bin/bash
set -e
if ! source /cvmfs/sw.hsf.org/key4hep/setup.sh -r ${KEY4HEP_VERSION}; then
    echo "Key4HEP setup failed; the script is going to abort."
    exit 1
fi
cp "${BHWIDE_PATH}" .
./$(basename "${BHWIDE_PATH}") --events ${NEV} --seed ${NUM} --lhe ${LHE_EVENTS}
EOF
    bash "${GEN_SCRIPT}"
elif [[ ${SAMPLE} == mg5* ]]; then
    LHE_EVENTS=$(pwd)/events.lhe.gz
    cat >> "${PYTHIA_CARD}" <<EOF
Beams:LHEF = ${LHE_EVENTS}
Main:numberOfEvents = ${NEV}
EOF
    cat > "${GEN_SCRIPT}" <<EOF
#!/bin/bash
set -e
if ! source /cvmfs/sw.hsf.org/key4hep/setup.sh -r ${KEY4HEP_VERSION}; then
    echo "Key4HEP setup failed; the script is going to abort."
    exit 1
fi
envsubst < ${SIMDIR}/mg5/${SAMPLE}.template > ${SAMPLE}.mg5
mg5_aMC ${SAMPLE}.mg5
ln -s ${SAMPLE}/Events/${SAMPLE}_seed${NUM}/unweighted_events.lhe.gz ${LHE_EVENTS}
EOF
    bash "${GEN_SCRIPT}"
fi

#add seed to pythia card
echo "Random:seed=${NUM}" >> "${PYTHIA_CARD}"
cat "${PYTHIA_CARD}"

#prepare the gen-sim-reco script
echo "
#!/bin/bash
set -e
if ! source /cvmfs/sw.hsf.org/key4hep/setup.sh -r ${KEY4HEP_VERSION}; then
    echo "Key4HEP setup failed; the script is going to abort."
    exit 1
fi
env
ls `pwd`/CLDConfig/CLDConfig
k4run CLDConfig/pythia.py -n ${NEV} --Dumper.Filename out.hepmc --Pythia8.PythiaInterface.pythiacard ${PYTHIA_CARD}
ddsim -I out.hepmc -N -1 -O out_SIM.root --compactFile \$K4GEO/FCCee/CLD/compact/CLD_o2_v07/CLD_o2_v07.xml --steeringFile CLDConfig/CLDConfig/cld_steer.py

cd CLDConfig/CLDConfig
k4run CLDReconstruction.py --inputFiles ../../out_SIM.root --outputBasename out_RECO --num-events -1
" > sim.sh

cat sim.sh

#execute the gen-sim-reco step
export PYTHONPATH=$(pwd)/CLDConfig/CLDConfig:$PYTHONPATH
if [[ ${RUN_SIM_IN_SINGULARITY:-0} == 1 ]]; then
    singularity exec -B "/home/${USER}" -B /cvmfs -B /scratch -B /local --env "PYTHONPATH=$(pwd)/CLDConfig/CLDConfig" /home/software/singularity/alma9.simg bash sim.sh
else
    bash sim.sh
fi

ls *.root

#Copy the outputs
cp CLDConfig/CLDConfig/out_RECO_REC.edm4hep.root "${FULLOUTDIR}/root/reco_${SAMPLE}_${NUM}.root"
