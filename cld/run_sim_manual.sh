#!/bin/bash
#SBATCH -p main
#SBATCH --mem-per-cpu=6G
#SBATCH --cpus-per-task=1
#SBATCH -o logs/slurm-%x-%j-%N.out
set -e
set -x

env
df -h

export NEV=100
export NUM=$1 #random seed
export SAMPLE=$2 #main card

#Change these as needed
export KEY4HEP_VERSION=2026-04-08
export OUTDIR=/local/${USER}/cld_edm4hep/v1.3.0_key4hep_${KEY4HEP_VERSION}_CLD_c75ed96d/
export SIMDIR=/home/${USER}/key4hep-sim/cld/CLDConfig
export WORKDIR=/scratch/local/${USER}/${SAMPLE}_${SLURM_JOB_ID}
export FULLOUTDIR=${OUTDIR}/${SAMPLE}

mkdir -p $FULLOUTDIR

mkdir -p $WORKDIR
cd $WORKDIR

cp $SIMDIR/pythia/${SAMPLE}.cmd card.cmd
cp -R $SIMDIR ./

echo "Random:seed=${NUM}" >> card.cmd
cat card.cmd

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

singularity exec -B /home/${USER} -B /cvmfs -B /scratch -B /local --env PYTHONPATH=`pwd`/CLDConfig/CLDConfig /home/software/singularity/alma9.simg bash sim.sh

ls *.root

#Copy the outputs
cp CLDConfig/CLDConfig/out_RECO_REC.edm4hep.root $FULLOUTDIR/root/reco_${SAMPLE}_${NUM}.root

rm -Rf $WORKDIR
