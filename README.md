# key4hep-sim

## Setup

Clone this repository with submodules:

```bash
git clone --recurse-submodules <insert the git URL>
```

Build the generator software:

```bash
source /cvmfs/sw.hsf.org/key4hep/setup.sh -r 2026-04-08
make -C generators/bhwide -j4
export PATH="`pwd`/generators/bhwide/bin:$PATH"
```

Remember to `make clean` and rebuild the generator software when switching to a new Key4HEP release.

## Running

Make sure to *not* source `/cvmfs/sw.hsf.org/key4hep/setup.sh` before launching the MC production jobs with `run_sim.sh`, as otherwise the jobs will simply fail because they see that the Key4HEP environment has already been set up. This is to avoid potential inconsistencies between user environment and intended production environment.