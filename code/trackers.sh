BASEDIR=$PWD
module load apptainer/1.3.5

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/fmriprepfit/23.2.3/output/
    ls -al derivatives/fmriprepfit/23.2.3/output

    ln -s "$BASEDIR/data/local/derivatives/fmriprep/23.2.3/"* derivatives/fmriprepfit/23.2.3/output/ || true

   
      nipoppy track \
        --pipeline fmriprepfit \
        --pipeline-version 23.2.3 \
       
  '


singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/freesurferlong/7.4.1/output/
    ls -al derivatives/freesurferlong/7.4.1/output/
    ln -s "$BASEDIR/data/local/derivatives/freesurfer/7.4.1/"* derivatives/freesurferlong/7.4.1/output/ || true

   
      nipoppy track \
        --pipeline freesurferlong \
        --pipeline-version 7.4.1 \
      
  '

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/magetbraininit/0.1.0/output/
    ls -al derivatives/magetbraininit/0.1.0/output/
    ln -s "$BASEDIR/data/local/derivatives/MAGeTbrain/magetbrain_data/"* derivatives/magetbraininit/0.1.0/output/ || true

    nipoppy track  --pipeline magetbraininit   --pipeline-version 0.1.0 
  '

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/mriqc/24.0.0/output/
    ls -al derivatives/mriqc/24.0.0/output/
    ln -s "$BASEDIR/data/local/derivatives/mriqc/24.0.0/"* derivatives/mriqc/24.0.0/output/ || true

  
      nipoppy track \
        --pipeline mriqc \
        --pipeline-version 24.0.0 \
        
  '

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail
    
    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/qsiprep/0.22.0/output/
    ls -al derivatives/qsiprep/0.22.0/output/

    ln -s "$BASEDIR/data/local/derivatives/qsiprep/0.22.0/qsiprep/"* derivatives/qsiprep/0.22.0/output/ || true

   
      nipoppy track \
        --pipeline qsiprep \
        --pipeline-version 0.22.0
        --debug        
  '

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/smriprep/23.2.3/output/
    ls -al derivatives/smriprep/23.2.3/output/
    ln -s "$BASEDIR/data/local/derivatives/smriprep/23.2.3/smriprep/"* derivatives/smriprep/23.2.3/output/ || true

    
      nipoppy track \
        --pipeline smriprep \
        --pipeline-version 23.2.3 \
  '

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/qsireconfsl/0.22.0/output/
    ls -al derivatives/qsireconfsl/0.22.0/output/

    ln -s "$BASEDIR/data/local/qsirecon-FSL/" derivatives/qsireconfsl/0.22.0/output/ || true

   
      nipoppy track \
        --pipeline qsireconfsl \
        --pipeline-version 0.22.0 \
  '



singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/fmriprepapply/23.2.3/output/
    ls -al derivatives/fmriprepapply/23.2.3/output/

    ln -s "$BASEDIR/data/local/derivatives/fmriprep/23.2.3/"* derivatives/fmriprepapply/23.2.3/output/ || true

      nipoppy track \
        --pipeline fmriprepapply \
        --pipeline-version 23.2.3 \
  '


singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail
    
    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/amiconoddi/0.22.0/output/
    ls -al derivatives/amiconoddi/0.22.0/output/

    ln -s "$BASEDIR/data/local/derivatives/qsiprep/0.22.0/amico_noddi/"* derivatives/amiconoddi/0.22.0/output/ || true

   
      nipoppy track \
        --pipeline amiconoddi \
        --pipeline-version 0.22.0 \
        
  '



singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SELECTED_SUBJECT" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/ciftify/1.3.2/output/
    ls -al derivatives/ciftify/1.3.2/output/

    ln -s "$BASEDIR/data/local/derivatives/ciftify/"* derivatives/ciftify/1.3.2/output/ || true


   
      nipoppy track \
        --pipeline ciftify \
        --pipeline-version 1.3.2 \
        
  '


singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS_BATCH="$SUBJECTS_BATCH" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/freesurferparcellate/7.4.1/output/
    ls -al derivatives/freesurferparcellate/7.4.1/output/

    ln -s "$BASEDIR/data/local/derivatives/freesurfer/7.4.1/"* derivatives/freesurferparcellate/7.4.1/output/ || true

      nipoppy track \
        --pipeline freesurferparcellate \
        --pipeline-version 7.4.1 \
        
  '

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS_BATCH="$SUBJECTS_BATCH" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail
    
    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/magetbrainregister/0.1.0/output/
    ls -al derivatives/magetbrainregister/0.1.0/output/

    ln -s "$BASEDIR/data/local/derivatives/MAGeTbrain/magetbrain_data/"* derivatives/magetbrainregister/0.1.0/output/ || true

    nipoppy track  --pipeline magetbrainregister  --pipeline-version 0.1.0
  '

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/tractographymulti/0.22.0/output/
    ls -al derivatives/tractographymulti/0.22.0/output/

    ln -s "$BASEDIR/data/local/derivatives/qsiprep/0.22.0/qsirecon-MRtrix3_act-HSVS/" derivatives/tractographymulti/0.22.0/output/ || true

      nipoppy track \
        --pipeline tractographymulti \
        --pipeline-version 0.22.0 \
       
  '
singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/tractographysingle/0.22.0/output/
    ls -al derivatives/tractographysingle/0.22.0/output/

    ln -s "$BASEDIR/data/local/derivatives/qsiprep/0.22.0/qsirecon-MRtrix3_fork-SS3T_act-HSVS/" derivatives/tractographysingle/0.22.0/output/ || true

      nipoppy track \
        --pipeline tractographysingle \
        --pipeline-version 0.22.0 \
     
  '

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/xcpnogsr/0.7.3/output/
    ls -al derivatives/xcpnogsr/0.7.3/output/

    ln -s "$BASEDIR/data/local/derivatives/xcp_noGSR/"* derivatives/xcpnogsr/0.7.3/output/ || true

   
      nipoppy track \
        --pipeline xcpnogsr \
        --pipeline-version 0.7.3  \
       
  '

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/xcpd/0.7.3/output/
    ls -al derivatives/xcpd/0.7.3/output/

    ln -s "$BASEDIR/data/local/derivatives/xcp_d/0.7.3/"* derivatives/xcpd/0.7.3/output/ || true

      nipoppy track \
        --pipeline xcpd \
        --pipeline-version 0.7.3  \
  '


singularity exec \
  	--env BASEDIR="$BASEDIR" \
    --bind $BASEDIR:$BASEDIR \
  	--env SUBJECTS="$SUBJECTS" \
  	${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    	set -euo pipefail

    	cd "$BASEDIR/Neurobagel"
    
    	mkdir -p derivatives/qsirecondtifit/0.22.0/output/
    	ls -al derivatives/qsirecondtifit/0.22.0/output/

    	ln -s "$BASEDIR/data/local/dtifit/" derivatives/qsirecondtifit/0.22.0/output/ || true
        ls -al derivatives/qsirecondtifit/0.22.0/output/
    	ln -s "$BASEDIR/data/local/enigmaDTI/" derivatives/qsirecondtifit/0.22.0/output/ || true

    	
      	nipoppy track \
        	--pipeline qsirecondtifit \
        	--pipeline-version 0.22.0 \
        	
  	'

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/magetbrainvote/0.1.0/output/
    ls -al derivatives/magetbrainvote/0.1.0/output/

    ln -s "$BASEDIR/data/local/derivatives/MAGeTbrain/magetbrain_data/output/"* derivatives/magetbrainvote/0.1.0/output/ || true

      nipoppy track \
        --pipeline magetbrainvote \
        --pipeline-version 0.1.0 \
      
  '


singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/enigmadti/0.1.1/output/
    ls -al derivatives/enigmadti/0.1.1/output/

    ln -s "$BASEDIR/data/local/enigmaDTI/" derivatives/enigmadti/0.1.1/output/ || true

    nipoppy track  --pipeline enigmadti  --pipeline-version 0.1.1 
  '


singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/extractnoddi/0.1.1/output/
    ls -al derivatives/extractnoddi/0.1.1/output/

    ln -s "$BASEDIR/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/" derivatives/extractnoddi/0.1.1/output/ || true

    nipoppy track  --pipeline extractnoddi  --pipeline-version 0.1.1 
  '
