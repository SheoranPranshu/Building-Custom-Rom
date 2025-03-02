# Open folder you made for your rom like here EvolutionX
```
cd EvolutionX
```
# Initialize local repository
```
repo init -u https://github.com/Evolution-X/manifest -b vic --git-lfs
```
U can use --depth 1 at end of repo to save data and space like instead of using above command use this one
```
repo init -u https://github.com/Evolution-X/manifest -b vic --git-lfs --depth 1
```


# Sync up
```
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
```

# Where to find these above things

Just search for rom name manifest on google like here I had to search EvolutionX Manifest on google and you will get specific commands on their github in manifest or android or build depending on the rom
