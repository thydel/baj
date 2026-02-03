# Try to make a text version of a repo

- Seems like Gemini can only access github repo via google index
- Try to find a tool to make a MD from a dir
- Wrong option, use a truly dedicated tool

# Try [repomix][]

[repomix]:
    https://github.com/yamadashy/repomix
    "github.com"

## Install

```bash
sudo apt remove nodejs
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo npm install -g npm@11.8.0
sudo sed /globalignorefile/s/^/#/ /usr/local/lib/node_modules/npm/npmrc
npm install -g repomix
```

```console
thy@tdews1-256g:~$ npm -v
11.8.0
thy@tdews1-256g:~$ node -v
v20.20.0
thy@tdews1-256g:~$ repomix -v
1.11.1
```

## Use

```bash
repomix --style plain --ignore "*~,keep,doc,MISC.md" -o tmp/baj-repomix.txt
```

# Try [git2md][]

[git2md]:
    https://github.com/Xpos587/git2md
    "github.com"

## Install

```bash
mkdir -p tmp/venv/git2md
python -m venv tmp/venv/git2md
source tmp/venv/git2md/bin/activate
pip install git2md
type -t deactivate | grep -q function && deactivate
```

## Use

```bash
source tmp/venv/git2md/bin/activate
git2md . --ignore "*~" tmp keep doc MISC.md -o tmp/baj-git2md.md
type -t deactivate | grep -q function && deactivate
```

## Check

```bash
markdown tmp/baj-git2md.md > tmp/baj-git2md.html
```

# Try [proj2md][]

[proj2md]:
    https://github.com/thibaud-perrin/proj2md
    "github.com"

## Install 

```bash
mkdir -p tmp/venv/proj2md
python -m venv tmp/venv/proj2md
source tmp/venv/proj2md/bin/activate
pip install proj2md
type -t deactivate | grep -q function && deactivate
```

## Use

```bash
source tmp/venv/git2md/bin/activate
proj2md -i . -x "*~",tmp,keep,doc,MISC.md -o tmp/baj-proj2md.md
type -t deactivate | grep -q function && deactivate
```

[Local Variables:]::
[indent-tabs-mode: nil]::
[End:]::
