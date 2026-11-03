# Fieldmap IntendedFor

dcm2niix sometimes leaves the BIDS `IntendedFor` field out of fmap JSON files. The steps below fill that field from a YAML config that matches your filenames. The short commands are also in the README under [Edit fieldmap files](../README.md#edit-fmap-files).

An example config is [code/config/EPIPHANI_query_config.yaml](../code/config/EPIPHANI_query_config.yaml).

## Back up the JSON files

```sh
mkdir bidsbackup_json
rsync -zarv  --include "*/" --include="*.json" --exclude="*"  data/local/bids  bidsbackup_json
```

## Run the script

In some cases, dcm2niix conversion fails to add the BIDS ``IntendedFor`` field in fmap JSON files, which causes errors in the fmriprep_apply step. Edit those fieldmaps (or run the script below) using a YAML configuration that matches your dataset naming.

This script automatically fills the ``"IntendedFor"`` field in BIDS fieldmap JSON files. It reads a YAML configuration file that describes your dataset's naming patterns, then links each fieldmap to correct fMRI or DWI files.

This helps make your dataset ready for tools like fMRIPrep, QSIPrep, and other BIDS-app pipelines.

```sh
## First load a python module
module load python/3.11.5

## Create a directory for virtual environments if it doesn't exist
mkdir ~/.virtualenvs
cd ~/.virtualenvs
virtualenv --system-site-packages ~/.virtualenvs/myenv

## Activate the virtual environment
source ~/.virtualenvs/myenv/bin/activate 

python3 -m pip install pybids==0.15.6

cd $SCRATCH/SCanD_project

python3 ./code/fmap_intended_for.py ./data/local/bids --participant-label ./data/local/bids/participants.tsv --config ./code/config/EPIPHANI_query_config.yaml
```
## What the script does
1. Searches your BIDS dataset for fieldmaps (/fmap)
2. Searches for fMRI and/or DWI data (/func, /dwi)
3. Uses patterns defined in your YAML config to determine which fieldmap file should be used for functional or diffusion scans
4. Writes a correct "IntendedFor" entry into each fieldmap JSON
```bash
fmap/sub-001_ses-01_acq-rest_run-01_epi.json
    → IntendedFor: ["func/sub-001_ses-01_task-rest_run-01_bold.nii.gz",
                    "func/sub-001_ses-01_task-rest_run-02_bold.nii.gz"]

```
## Example of BIDS structure
```lua
sub-001/
  ses-01/
    fmap/
      sub-001_ses-01_acq-rest_dir-AP_run-01_epi.json
      sub-001_ses-01_acq-rest_dir-AP_run-02_epi.json
    func/
      sub-001_ses-01_task-rest_run-01_bold.nii.gz
      sub-001_ses-01_task-rest_run-02_bold.nii.gz
      sub-001_ses-01_task-rest_run-03_bold.nii.gz
    dwi/
      sub-001_ses-01_dwi.nii.gz
```
## YAML configuration file
You customize how your dataset is structured by editing the YAML file. An example of the config file can be found [code/config/EPIPHANI_query_config.yaml](../code/config/EPIPHANI_query_config.yaml)

### Query blocks

Query blocks tell the script which files to search for in the dataset. Each key-value pair corresponds to a **BIDS entity** — the script builds a filename filter from these values and returns all matching files across subjects and sessions.

**Rules:**
- Use a **single string** when all relevant files share one value for that entity (e.g. `task: rest`)
- Use a **list** when files may carry different values for that entity (e.g. `task: [rest, nback, gng]`)
- Set a field to `null` to omit it from the filter (i.e. match any value for that entity)
- Do **not** rename the block keys (`bold_query`, `dwi_query`, `fmap_fmri_query`, `fmap_dwi_query`) — only change the values

---

**BOLD query**

```yaml
bold_query:
  datatype: func
  suffix: bold
  task: rest          # single task — change to a list if you have multiple: [rest, nback, gng]
  extension: nii.gz
```

This matches BOLD files like:
```lua
sub-XXX_ses-01_task-rest_run-XX_bold.nii.gz
```

For a multi-task dataset, use:
```yaml
bold_query:
  datatype: func
  suffix: bold
  task: [rest, nback, gng]
  extension: nii.gz
```

This would match all three task variants:
```lua
sub-XXX_ses-01_task-rest_run-XX_bold.nii.gz
sub-XXX_ses-01_task-nback_run-XX_bold.nii.gz
sub-XXX_ses-01_task-gng_run-XX_bold.nii.gz
```

---

**DWI query**

```yaml
dwi_query:
  datatype: dwi
  suffix: dwi
  extension: nii.gz
```

This matches DWI files like:
```lua
sub-XXX_ses-01_dwi.nii.gz
```

For a dataset with multiple DWI acquisitions (e.g. multi-shell labelled with `acq-`), add the `acquisition` entity:
```yaml
dwi_query:
  datatype: dwi
  suffix: dwi
  acquisition: [multishell, singleshell]
  extension: nii.gz
```

This would match:
```lua
sub-XXX_ses-01_acq-multishell_run-01_dwi.nii.gz
sub-XXX_ses-01_acq-singleshell_run-01_dwi.nii.gz
```

> **Note:** Most datasets have a single unlabelled DWI acquisition — in that case, the default config above (no `acquisition` field) is correct. Add `acquisition` only if your DWI filenames include an `acq-` entity.

---

**Fieldmap query (fMRI)**

```yaml
fmap_fmri_query:
  datatype: fmap
  suffix: [epi, phasediff, phase1, fieldmap]   # list covers all common fieldmap types
  acquisition: rest                             # matches the acq-rest label in the filename; set to null if absent
  extension: json
```

This matches fieldmap JSON sidecar files like:
```lua
sub-XXX_ses-01_acq-rest_dir-AP_run-XX_epi.json
sub-XXX_ses-01_acq-rest_dir-PA_run-XX_epi.json
```

> **Note:** The `acquisition` field here corresponds to the `acq-<label>` entity in the fieldmap filename — it is **not** related to the task label. If your fieldmap filenames do not include an `acq-` entity, set `acquisition: null`.

---

**Fieldmap query (DWI)**

```yaml
fmap_dwi_query:
  datatype: fmap
  suffix: [epi, phasediff, phase1, fieldmap]   # list covers all common fieldmap types
  acquisition: dwi                              # matches the acq-dwi label in the filename; set to null if absent
  extension: json
```

This matches fieldmap JSON sidecar files like:
```lua
sub-XXX_ses-01_acq-dwi_dir-AP_epi.json
sub-XXX_ses-01_acq-dwi_dir-PA_epi.json
```

For a single-shell dataset with no `acq-` label in the fieldmap filename, use:
```yaml
fmap_dwi_query:
  datatype: fmap
  suffix: [epi, phasediff, phase1, fieldmap]
  acquisition: null
  extension: json
```

This would match:
```lua
sub-XXX_ses-01_dir-AP_epi.json
sub-XXX_ses-01_dir-PA_epi.json
```

> **Note:** The `acquisition` field here corresponds to the `acq-<label>` entity in the fieldmap filename — it is **not** the DWI acquisition label. If your fieldmap filenames share an `acq-` label with your fMRI fieldmaps (e.g. both use `acq-rest`), you must use a distinct label (e.g. `acq-dwi`) on the DWI fieldmaps so the two queries return separate file sets. If no `acq-` entity is present in the DWI fieldmap filenames, set `acquisition: null`.

### Assign fieldmaps to BOLD

> **Important:** You must include an entry for **every session** in `fmap_to_bold` and/or `fmap_to_dwi`. The script only assigns fieldmaps to sessions that are explicitly listed — any session omitted from the config will be skipped and its fieldmaps will not be assigned to any functional or diffusion data.

The `fmap_to_bold` block tells the script which fieldmap(s) should be assigned to which BOLD run(s), on a per-session basis.

**How it works:**
- Each entry under a session lists a **fieldmap key** (`fmap`) and one or more **BOLD keys** (`bold_keys`).
- The `fmap` value is a **substring of the fieldmap filename** — the script matches any fieldmap file whose name contains that string.
- The `bold_keys` values are **substrings of the BOLD filenames** — each matched BOLD file will have its path added to that fieldmap's `IntendedFor` field.

**Example:** Given this dataset structure:
```lua
Fieldmap: fmap/sub-XXX_ses-01_acq-rest_dir-AP_run-01_epi.json
          fmap/sub-XXX_ses-01_acq-rest_dir-AP_run-02_epi.json
          fmap/sub-XXX_ses-01_acq-rest_dir-PA_run-01_epi.json
          fmap/sub-XXX_ses-01_acq-rest_dir-PA_run-02_epi.json
BOLD:     func/sub-XXX_ses-01_task-rest_run-01_bold.nii.gz
          func/sub-XXX_ses-01_task-rest_run-02_bold.nii.gz
          func/sub-XXX_ses-01_task-rest_run-03_bold.nii.gz
```

The following config assigns the AP and PA run-01 fieldmaps to BOLD runs 01 & 02, and the AP and PA run-02 fieldmaps to BOLD run 03 — for both sessions:

```yaml
fmap_to_bold:
  ses-01:
    - fmap: "acq-rest_dir-AP_run-01"
      bold_keys: ["task-rest_run-01", "task-rest_run-02"]

    - fmap: "acq-rest_dir-AP_run-02"
      bold_keys: ["task-rest_run-03"]

    - fmap: "acq-rest_dir-PA_run-01"
      bold_keys: ["task-rest_run-01", "task-rest_run-02"]

    - fmap: "acq-rest_dir-PA_run-02"
      bold_keys: ["task-rest_run-03"]

  ses-02:
    - fmap: "acq-rest_dir-AP_run-01"
      bold_keys: ["task-rest_run-01", "task-rest_run-02"]

    - fmap: "acq-rest_dir-AP_run-02"
      bold_keys: ["task-rest_run-03"]

    - fmap: "acq-rest_dir-PA_run-01"
      bold_keys: ["task-rest_run-01", "task-rest_run-02"]

    - fmap: "acq-rest_dir-PA_run-02"
      bold_keys: ["task-rest_run-03"]
```

**Reading the mapping:**

| `fmap` key | Matches fieldmap file(s) containing... | Assigned to BOLD runs... |
|---|---|---|
| `acq-rest_dir-AP_run-01` | `..._acq-rest_dir-AP_run-01_epi.json` | run-01, run-02 |
| `acq-rest_dir-AP_run-02` | `..._acq-rest_dir-AP_run-02_epi.json` | run-03 |
| `acq-rest_dir-PA_run-01` | `..._acq-rest_dir-PA_run-01_epi.json` | run-01, run-02 |
| `acq-rest_dir-PA_run-02` | `..._acq-rest_dir-PA_run-02_epi.json` | run-03 |

> **Tip:** If your study only has one session, include only `ses-01` under `fmap_to_bold`. If all sessions share the same mapping, duplicate the block for each session.

### Assign fieldmaps to DWI

> **Important:** You must include an entry for **every session** in `fmap_to_dwi`. The script only assigns fieldmaps to sessions that are explicitly listed — any session omitted from the config will be skipped and its fieldmaps will not be assigned to any diffusion data.

The `fmap_to_dwi` block tells the script which fieldmap(s) should be assigned to which DWI run(s), on a per-session basis. It works the same way as `fmap_to_bold`, but targets diffusion-weighted imaging files instead of BOLD.

**How it works:**
- Each entry under a session lists a **fieldmap key** (`fmap`) and one or more **DWI keys** (`dwi_keys`).
- The `fmap` value is a **substring of the fieldmap filename** — the script matches any fieldmap file whose name contains that string.
- The `dwi_keys` values are **substrings of the DWI filenames** — each matched DWI file will have its path added to that fieldmap's `IntendedFor` field.
- Use a **string** (not a list) for `dwi_keys` when there is only one DWI file per session; use a **list** when there are multiple.

**Example:** Given this dataset structure:
```lua
Fieldmap: fmap/sub-XXX_ses-01_acq-dwi_dir-AP_run-01_epi.json
          fmap/sub-XXX_ses-01_acq-dwi_dir-AP_run-02_epi.json
DWI:      dwi/sub-XXX_ses-01_acq-multishell_run-01_dwi.nii.gz
          dwi/sub-XXX_ses-01_acq-multishell_run-02_dwi.nii.gz
```

The following config assigns both the AP and PA fieldmaps to both DWI runs — for both sessions:

```yaml
fmap_to_dwi:
  ses-01:
    - fmap: "acq-dwi_dir-AP_run-01"
      dwi_keys: ["acq-multishell_run-01"]

    - fmap: "acq-dwi_dir-AP_run-01"
      dwi_keys: ["acq-multishell_run-02"]

  ses-02:
    - fmap: "acq-dwi_dir-AP_run-01"
      dwi_keys: ["acq-multishell_run-01"]

    - fmap: "acq-dwi_dir-AP_run-02"
      dwi_keys: ["acq-multishell_run-02"]
```

**Reading the mapping:**

| `fmap` key | Matches fieldmap file(s) containing... | Assigned to DWI runs... |
|---|---|---|
| `acq-dwi_dir-AP` | `..._acq-dwi_dir-AP_epi.json` | run-01, run-02 |
| `acq-dwi_dir-PA` | `..._acq-dwi_dir-PA_epi.json` | run-01, run-02 |

**Simpler example:** If each session has a single DWI acquisition with no `run-` or `acq-` label:

```lua
Fieldmap: fmap/sub-XXX_ses-01_acq-dwi_dir-AP_epi.json
DWI:      dwi/sub-XXX_ses-01_dwi.nii.gz
```

```yaml
fmap_to_dwi:
  ses-01:
    - fmap: "acq-dwi_dir-AP"
      dwi_keys: "dwi"
  ses-02:
    - fmap: "acq-dwi_dir-AP"
      dwi_keys: "dwi"
```

> **Tip:** If your study only has one session, include only `ses-01` under `fmap_to_dwi`. If all sessions share the same mapping, duplicate the block for each session.

## Output
The script updates each fieldmap JSON like:
```json
{
  "PhaseEncodingDirection": "j-",
  "IntendedFor": [
    "/ses-01/func/sub-001_ses-01_task-rest_run-01_bold.nii.gz",
    "/ses-01/func/sub-001_ses-01_task-rest_run-02_bold.nii.gz"
  ]
}
```
## Notes

- **Only edit values, not keys**  
  Do **not** rename sections like `bold_query` or `fmap_to_bold`. Change only values, e.g., `task: rest` or `bold_keys: ["task-rest_run-01","task-rest_run-02"]`.

- **bold_keys / dwi_keys**  
  These are **filename patterns**, not arbitrary numbers.  
  Example: if a file is `sub-001_ses-01_task-rest_run-01_bold.nii.gz`, use `bold_keys: ["task-rest_run-01"]`.

- **Acquisition field**  
  - Use the label if present in filenames: `acquisition: rest`  
  - Set to `null` if not in filenames: `acquisition: null`

