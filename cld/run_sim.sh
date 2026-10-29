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
export KEY4HEP_VERSION=2026-04-08
export OUTDIR=${OUTDIR:-/local/${USER}/cld_edm4hep/v1.3.0_key4hep_${KEY4HEP_VERSION}/}
export CONFIG_DIR=${CONFIG_DIR:-/home/${USER}/key4hep-sim/cld/CLDConfig}
export WORKDIR=${WORKDIR:-/scratch/local/${USER}/${SAMPLE}_${SLURM_JOB_ID}}
export FULLOUTDIR=${OUTDIR}/${SAMPLE}

mkdir -p $FULLOUTDIR

mkdir -p $WORKDIR

# Ensure cleanup on exit, even if the job fails
cleanup() {
    if [ ! -z "$WORKDIR" ] && [ "$WORKDIR" != "/scratch/local/$USER" ] && [ "$WORKDIR" != "/scratch/local/$USER/" ]; then
        echo "Cleaning up scratch directory $WORKDIR"
        rm -Rf $WORKDIR
    fi
}
trap cleanup EXIT

cd $WORKDIR

cp $CONFIG_DIR/pythia/${SAMPLE}.cmd card.cmd
cp -R $CONFIG_DIR ./

#add seed to pythia card
echo "Random:seed=${NUM}" >> card.cmd
cat card.cmd

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
k4run CLDConfig/pythia.py -n $NEV --Dumper.Filename out.hepmc --Pythia8.PythiaInterface.pythiacard card.cmd
ddsim -I out.hepmc -N -1 -O out_SIM.root --compactFile \$K4GEO/FCCee/CLD/compact/CLD_o2_v07/CLD_o2_v07.xml --steeringFile CLDConfig/CLDConfig/cld_steer.py

cd CLDConfig/CLDConfig
k4run CLDReconstruction.py --inputFiles ../../out_SIM.root --outputBasename out_RECO --num-events -1
" > sim.sh

cat sim.sh

#execute the gen-sim-reco step
export PYTHONPATH=$(pwd)/CLDConfig/CLDConfig:$PYTHONPATH
bash sim.sh

ls *.root

#Copy the outputs
cp CLDConfig/CLDConfig/out_RECO_REC.edm4hep.root $FULLOUTDIR/root/reco_${SAMPLE}_${NUM}.root
