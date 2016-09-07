# dotfiles
Yum yum, dotfiles! For *NIX-OSes only.

### Git-free install

To install these dotfiles without Git:

```bash
cd; curl -#L https://github.com/x86dev/dotfiles/tarball/master | tar -xzv --strip-components 1 --exclude={README.md}
```

### Using Git and the bootstrap script

You can clone the repository wherever you want. (I like to keep it in `~/Projects/dotfiles`, with `~/dotfiles` as a symlink.) The bootstrapper script will pull in the latest version and copy the files to your home folder.

```bash
git clone --recursive https://github.com/x86dev/dotfiles.git && cd dotfiles && source bootstrap.sh
```

To update, `cd` into your local `dotfiles` repository and then:

```bash
source bootstrap.sh
```
