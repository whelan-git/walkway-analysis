# 2021-11-15. Leonardo Molina.
# 2023-04-03. Leonardo Molina.

# Extract and save file size from files in the project folder.

from pathlib import Path

import glob
import os

videoType = ".mp4"
dataLocation = r"W:/Walkway/raw data/mp4"
log = r"W:/Walkway/output/log-size-mp4.csv"

pattern = str(dataLocation + "/**/*%s") % videoType
files = list(glob.glob(pattern, recursive=True))
files = [file for file in files if file[-6:-4] != 'TF']
nFiles = len(files)

with open(log, 'w') as f:
    f.write("uid,nBytes\n")

    for i, file in enumerate(files):
        print("%04i:%04i" % (i, nFiles))
        path = Path(file)
        uid = path.stem[-20:]
        nBytes = os.stat(file).st_size
        f.write("%s,%i\n" % (uid, nBytes))