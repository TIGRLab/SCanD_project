# SCanD First-level GLM Analysis Pipeline for fMRI

This repository contains tools for running General Linear Model (GLM) analyses on functional MRI data from the Schizophrenia Canadian Neuroimaging Database (SCanD). It's designed to be forked/cloned for each SCanD dataset.

## 📂 Repository Structure

```
glm/
├── bin/                  # Core pipeline scripts
├── config/               # Configuration files
├── examples/models/      # Example model specifications
│   ├── OPT/
│   └── RTMSWM/
├── notebooks/            # Jupyter notebooks for analysis
├── templates/            # Surface visualization templates
└── [Other files]         # Dockerfile, requirements, etc.
```

## 🚀 Getting Started

Follow these three essential steps to run the pipeline successfully:

### Step 1: Create Task Event Files ⏱️

**Create `task-events.tsv` files** for each functional run in your dataset.

#### What are task event files?
These tab-separated files document what happened during the fMRI scan:

| Column | Description |
|--------|-------------|
| `onset` | Time when event starts (seconds) |
| `duration` | How long event lasts (seconds) |
| `trial_type` | Label describing the event |
| + Other columns | Response time, accuracy, block, etc. |

<details>
<summary>📋 Example task-events.tsv content</summary>

| onset  | duration | trial_type     | correct_response | participant_response | response_time | block |
|--------|----------|----------------|------------------|----------------------|----------------|--------|
| 7.000  | 60.000   | onebackblock   | n/a              | n/a                  | n/a            | 1      |
| 7.000  | 0.000    | oneback        | 0                | 0                    | 0.000          | 1      |
| 10.009 | 0.000    | oneback        | 0                | 1                    | 0.702          | 1      |
| 13.018 | 0.000    | oneback        | 1                | 1                    | 1.186          | 1      |
| ...    | ...      | ...            | ...              | ...                  | ...            | ...    |
</details>

#### Where to save them
Save in the `func/` directory with BIDS naming:
```
sub-<label>/ses-<label>/func/sub-<label>_ses-<label>_task-<taskname>_run-<index>_events.tsv
```

> **Reference:** [BIDS Specification for Task Events](https://bids-specification.readthedocs.io/en/stable/modality-specific-files/task-events.html)

### Step 2: Ensure fMRIPrep Outputs Are Available 🧠

After running fMRIPrep, verify you have these required files:

- **Preprocessed BOLD data**: `*_space-fsLR_den-91k_bold.dtseries.nii`
- **Confounds**: `*_desc-confounds_timeseries.tsv`

These should be in the derivatives directory:
```
/data/local/derivatives/fmriprep/sub-<label>/ses-<label>/func/
```

### Step 3: Create BIDS Stats Model JSON File 📊

This is the **most critical step** for analysis configuration.

#### What is a BIDS Stats Model?
A JSON file that defines:
- Which task, session, and space to analyze
- The statistical model to use
- Contrasts to compute

#### Where to save it
```
/SCanD_project/code/glm/examples/models/<STUDY_NAME>/model-<number>_smdl.json
```

#### Template JSON

```json
{
  "Name": "YourStudyModelName",
  "BIDSModelVersion": "1.0.0",
  "Description": "Describe your model here.",
  "Input": {
    "task": ["REPLACE_WITH_YOUR_TASK"],
    "session": ["REPLACE_WITH_SESSION"],
    "space": "fsLR",
    "dense": "91k"
  },
  "Nodes": [
    {
      "Level": "Run",
      "Name": "run_level",
      "GroupBy": ["run", "subject"],
      "Model": {
        "X": ["REPLACE_WITH_YOUR_CONDITIONS"],
        "Type": "glm" 
      },
      "Contrasts": [
        {
          "Name": "REPLACE_WITH_CONTRAST_NAME",
          "ConditionList": ["conditionA", "conditionB"],
          "Weights": [1, -1],
          "Test": "t"
        },
        {
          "Name": "REPLACE_WITH_ANOTHER_CONTRAST_NAME",
          "ConditionList": ["conditionB"],
          "Weights": [1],
          "Test": "t"
        }
      ]
    }
  ]
}
```

#### What to customize
| Field | Replace with |
|-------|-------------|
| `"task"` | Your task label (e.g., "nbk") |
| `"session"` | Your session number(s) (e.g., ["01", "02"]) |
| `"X"` | Your condition names from task-events.tsv |
| `"Contrasts"` | Statistical comparisons for your study |

> **Reference:** [BIDS Stats-Models Documentation](https://bids-standard.github.io/stats-models/motivation.html)

## 📈 Pipeline Outputs

The GLM pipeline produces these files:

| Category | Files | Description |
|----------|-------|-------------|
| **Model Metadata** | `dataset_description.json`<br>`statmap.json` | Information about modeling software and parameters |
| **Design Matrix** | `design.tsv`<br>`design.svg` | The model design in tabular and visual formats |
| **Model Fit** | `stat-mean_square_error_statmap.dscalar.nii`<br>`stat-r_square_statmap.dscalar.nii` | Model performance metrics |
| **Contrast Results** | `contrast-[name]_stat-effect_size_statmap.dscalar.nii`<br>`contrast-[name]_stat-t_statmap.nii.gz`<br>`contrast-[name]_stat-p_statmap.nii.gz`<br>`contrast-[name]_stat-z_statmap.nii.gz` | Statistical maps for each contrast |
| **Visualizations** | `contrast-[name]_stat-effect_size_statmap.png`<br>`contrast-[name]_design.svg` | Figures showing results and contrast design |

## 📝 Technical Notes

- The pipeline is designed to run on SciNet Cedar cluster with BIDS datasets
- The first 4 seconds of fMRI data are automatically dropped to minimize early signal instability
- Surface-based analysis uses the fsLR space at 91k density

---

> **Need help?** For more information about BIDS formatting or GLM analysis, consult the [BIDS documentation](https://bids-specification.readthedocs.io/) and [Nilearn documentation](https://nilearn.github.io/stable/glm/index.html#glm) or open an issue in this repository.