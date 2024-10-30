
singularity exec --cleanenv \
  -B ${PROJECT_DIR}/data/local/bids:/bids \
  -B ${PROJECT_DIR}/data/local/derivatives/ciftify:/derived \
  ${PROJECT_DIR}/containers/fmriprep_ciftity-v1.3.2-2.3.3.simg \
  cifti_vis_recon_all index --ciftify-work-dir /derived
