import itertools
import os
from pathlib import Path
import subprocess as sp
import sys


FS_HOME = os.environ["FREESURFER_HOME"]
FSAVERAGE_DENSITY = {
    "fsaverage5": "10k",
    "fsaverage6": "41k",
    "fsaverage": "164k",
}


def invalid_fs():
    assert FS_HOME, "FreeSurfer not installed"
    try:
        proc = sp.run(("mri_convert", "-h"), stdout=sp.DEVNULL, stderr=sp.STDOUT)
    except OSError:
        print("FreeSurfer installation not found.")
        sys.exit(1)
    return proc.returncode


def convert2gii(filename, hemi, den, suffix):
    outfile = f"tpl-fsaverage_hemi-{hemi}_den-{den}_{suffix}.shape.gii"
    cmd = ["mri_convert", str(filename), outfile]
    print(f"Running {' '.join(cmd)}")
    proc = sp.run(cmd, stdout=sp.PIPE)
    return proc

if __name__ == "__main__":
    if invalid_fs():
        print("Error running FreeSurfer's ``mri_convert``.")
        sys.exit(1)
    FS_TEMPLATES_PATH = Path(FS_HOME) / "subjects"
    for template in ("fsaverage", "fsaverage5", "fsaverage6"):
        den = FSAVERAGE_DENSITY[template]
        template_curv = (FS_TEMPLATES_PATH / template).glob("surf/*h.curv")
        template_sulc = (FS_TEMPLATES_PATH / template).glob("surf/*h.sulc")
        for f in itertools.chain(template_curv, template_sulc):
            hemi = "L" if f.name.startswith('l') else "R"
            suffix = f.suffix.lstrip('.')
            convert2gii(f, hemi, den, suffix)
