# paired_files_handler

Currently hardcoded in paths for the dirs to check. Is made with option of having more than two directories to batch process.

## My usage for reference

Setup to put in path:

```bash
git clone git@github.com:andreasnonslid/paired_files_handler.git
chmod +x ./paired_files_handler/app
sudo ln -s "$(realpath ./paired_files_handler/app)" /usr/local/bin/pair_handler
```

Use directly and cleanly:
```bash
pair_handler list
```
